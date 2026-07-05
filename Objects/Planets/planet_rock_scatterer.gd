extends Node3D

@export var rock_meshes: Array[Mesh] = [
	preload("res://Assets/Debries/rock2.obj"),
	preload("res://Assets/Debries/rock3.obj"),
	preload("res://Assets/Debries/rock4.obj"),
	preload("res://Assets/Debries/rock5.obj"),
	preload("res://Assets/Debries/rock6.obj"),
	preload("res://Assets/Debries/rock7.obj"),
	preload("res://Assets/Debries/rock8.obj"),
	preload("res://Assets/Debries/rock.obj")
]
@export var rock_count := 10000
@export var chunk_divisions := 3

## Set to false if an external manager (e.g. PlanetSectorManager) wants to
## control when generation happens instead of it running automatically.
@export var auto_generate_on_ready: bool = true

const ROCK_RENDER_DISTANCE := 200.0
const PLANET_RADIUS := 20.0
const MIN_DISTANCE := 0.8
const CELL_SIZE := MIN_DISTANCE

var chunks: Dictionary = {}

var _generation_thread: Thread = null
var _is_generating := false

class Chunk:
	var center: Vector3
	var node := Node3D.new()
	var multimeshes: Array[MultiMesh] = []
	var multimesh_instances: Array[MultiMeshInstance3D] = []
	var transforms: Array = []


func _ready() -> void:
	create_chunks()
	if auto_generate_on_ready:
		get_parent().get_node("SourceMesh").show()
		start_generation()
		get_parent().get_node("SourceMesh").hide()

func _exit_tree() -> void:
	# Make sure we don't leave a dangling thread if this node is freed
	# (e.g. planet despawned by the sector manager) while generation is running.
	if _generation_thread != null:
		_generation_thread.wait_to_finish()
		_generation_thread = null


var _visibility_timer := 0.0
func _process(delta: float) -> void:
	_visibility_timer += delta
	if _visibility_timer >= 0.1:
		_visibility_timer = 0.0
		update_chunk_visibility(get_viewport().get_camera_3d())


func create_chunks():
	chunks.clear()
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				if x == 0 and y == 0 and z == 0:
					continue
				var chunk := Chunk.new()
				chunk.center = Vector3(x, y, z) * PLANET_RADIUS
				chunk.node.name = "Chunk_%d_%d_%d" % [x, y, z]
				for mesh in rock_meshes:
					var mm := MultiMesh.new()
					mm.mesh = mesh
					mm.transform_format = MultiMesh.TRANSFORM_3D
					var mmi := MultiMeshInstance3D.new()
					mmi.multimesh = mm
					chunk.node.add_child(mmi)
					chunk.multimeshes.append(mm)
					chunk.multimesh_instances.append(mmi)
					chunk.transforms.append([])
				add_child(chunk.node)
				chunks[Vector3i(x, y, z)] = chunk


## Public entry point: (re)generates rocks. Safe to call again later
## (e.g. after changing rock_count), as long as a generation isn't already
## running -- check is_generating() first if you need to guard externally.
func regenerate() -> void:
	if _is_generating:
		push_warning("PlanetRockScatterer: generation already in progress, ignoring regenerate() call")
		return
	start_generation()


func is_generating() -> bool:
	return _is_generating


func start_generation() -> void:
	if _is_generating:
		return
	_is_generating = true

	var sphere: MeshInstance3D = get_parent().get_node("SourceMesh")
	var arrays = sphere.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var sphere_transform: Transform3D = sphere.global_transform

	# MultiMesh instance transforms are interpreted relative to this node's
	# parent chain, not world space. We must convert world-space rock
	# positions into local space before storing them, or planets far from
	# world origin end up with their rocks flung out to roughly double
	# their distance from origin. This has to be read here, on the main
	# thread -- global_transform isn't safe to read from a background thread.
	var to_local_transform: Transform3D = self.global_transform.affine_inverse()

	# Everything the thread needs is captured here as plain data (vectors,
	# transforms, ints) -- no references to this Node, MultiMesh, or anything
	# else in the scene tree cross into the thread.
	_generation_thread = Thread.new()
	_generation_thread.start(
		_generate_rocks_threaded.bind(vertices, indices, sphere_transform, to_local_transform, rock_count, rock_meshes.size())
	)


## Runs on a BACKGROUND THREAD. Must not touch Nodes, MultiMesh resources,
## or anything else living in the scene tree -- only plain data in, plain
## data out. Uses its own RandomNumberGenerator instance rather than the
## global randi()/randf() functions, since the global RNG isn't thread-safe.
func _generate_rocks_threaded(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	sphere_transform: Transform3D,
	to_local_transform: Transform3D,
	target_rock_count: int,
	mesh_variant_count: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var grid := {}
	var placed := 0
	var attempts := 0
	var max_attempts := target_rock_count * 10

	# result[chunk_key] = Array of (Array of Transform3D), indexed by mesh_index
	var result: Dictionary = {}
	for cx in [-1, 0, 1]:
		for cy in [-1, 0, 1]:
			for cz in [-1, 0, 1]:
				if cx == 0 and cy == 0 and cz == 0:
					continue
				var key := Vector3i(cx, cy, cz)
				var per_mesh: Array = []
				for i in range(mesh_variant_count):
					per_mesh.append([])
				result[key] = per_mesh

	while placed < target_rock_count and attempts < max_attempts:
		attempts += 1

		var tri = (rng.randi() % (indices.size() / 3)) * 3
		var a = vertices[indices[tri]]
		var b = vertices[indices[tri + 1]]
		var c = vertices[indices[tri + 2]]

		var r1 = sqrt(rng.randf())
		var r2 = rng.randf()
		var pos = (1.0 - r1) * a + r1 * (1.0 - r2) * b + r1 * r2 * c
		var normal = pos.normalized()
		var world_pos = sphere_transform * pos

		var cell = Vector3i(
			floor(world_pos.x / CELL_SIZE),
			floor(world_pos.y / CELL_SIZE),
			floor(world_pos.z / CELL_SIZE)
		)

		var valid := true
		for x in range(cell.x - 1, cell.x + 2):
			for y in range(cell.y - 1, cell.y + 2):
				for z in range(cell.z - 1, cell.z + 2):
					var neighbor_key = Vector3i(x, y, z)
					if !grid.has(neighbor_key):
						continue
					for other in grid[neighbor_key]:
						if world_pos.distance_to(other) < MIN_DISTANCE:
							valid = false
							break
					if !valid:
						break
				if !valid:
					break
			if !valid:
				break
		if !valid:
			continue

		if !grid.has(cell):
			grid[cell] = []
		grid[cell].append(world_pos)

		var up = normal
		var forward = Vector3.FORWARD
		if abs(up.dot(forward)) > 0.99:
			forward = Vector3.RIGHT
		var right = forward.cross(up).normalized()
		forward = up.cross(right).normalized()

		var basis = Basis(right, up, -forward)
		basis = basis.rotated(up, rng.randf() * TAU)
		basis = basis.rotated(right, rng.randf_range(-0.2, 0.2))
		basis = basis.rotated(forward, rng.randf_range(-0.2, 0.2))

		var scale = rng.randf_range(0.7, 1.4)
		basis = basis.scaled(Vector3.ONE * scale)

		var transform = Transform3D(basis, world_pos)

		# Convert from world space into space local to this node
		# (PlanetRockScatterer), since MultiMesh instance transforms are
		# relative to the parent chain, not world space.
		transform = to_local_transform * transform

		var chunk_key = Vector3i(
			1 if normal.x > 0.33 else (-1 if normal.x < -0.33 else 0),
			1 if normal.y > 0.33 else (-1 if normal.y < -0.33 else 0),
			1 if normal.z > 0.33 else (-1 if normal.z < -0.33 else 0)
		)
		if chunk_key == Vector3i.ZERO:
			continue

		var mesh_index = rng.randi() % mesh_variant_count
		result[chunk_key][mesh_index].append(transform)
		placed += 1

	# call_deferred marshals this call safely onto the main thread --
	# this is the ONLY thing this function does that touches anything
	# outside its own local data.
	call_deferred("_on_generation_complete", result)


## Runs back on the MAIN THREAD (via call_deferred). Safe to touch
## Nodes/MultiMesh here.
func _on_generation_complete(result: Dictionary) -> void:
	for chunk_key in result:
		if !chunks.has(chunk_key):
			continue
		var chunk: Chunk = chunks[chunk_key]
		chunk.transforms = result[chunk_key]

	build_multimeshes()

	if _generation_thread != null:
		_generation_thread.wait_to_finish()
		_generation_thread = null
	_is_generating = false


func build_multimeshes() -> void:
	for chunk in chunks.values():
		for mesh_index in range(chunk.multimeshes.size()):
			var mm = chunk.multimeshes[mesh_index]
			var transforms = chunk.transforms[mesh_index]
			mm.instance_count = transforms.size()
			for i in range(transforms.size()):
				mm.set_instance_transform(i, transforms[i])


func update_chunk_visibility(camera: Camera3D) -> void:
	var planet_pos = get_parent().global_position
	var distance = camera.global_position.distance_to(planet_pos)

	if distance > ROCK_RENDER_DISTANCE:
		for chunk in chunks.values():
			chunk.node.visible = false
		return

	var cam_dir = (camera.global_position - planet_pos).normalized()
	for chunk in chunks.values():
		var chunk_dir = chunk.center.normalized()
		chunk.node.visible = chunk_dir.dot(cam_dir) > 0.6


#This is only for looking at the chunks when debugging
func draw_debug_cube(chunk: Chunk) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 100
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color.RED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.15
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = chunk.center
	chunk.node.add_child(mesh_instance)
