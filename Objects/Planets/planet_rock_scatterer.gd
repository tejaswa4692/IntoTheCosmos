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

## NOTE: default changed from true to false. GravitySource now explicitly
## calls set_base_color() then regenerate() once it has computed the
## planet's color_low, so rocks always get the right tint before they
## generate. If you use this scatterer somewhere WITHOUT a GravitySource
## driving it, set this back to true (rocks will just use base_rock_color's
## default value below).
@export var auto_generate_on_ready: bool = false

## Base tint color rocks are generated around (each rock jitters slightly
## from this). Set externally via set_base_color() -- normally called by
## GravitySource with the planet's color_low.
@export var base_rock_color: Color = Color(0.55, 0.5, 0.45)

## How much each rock's hue/saturation/value can randomly drift from
## base_rock_color, so rocks don't look like uniform copies of each other.
@export var hue_jitter := 0.03
@export var saturation_jitter := 0.12
@export var value_jitter := 0.18

const ROCK_SHADER: Shader = preload("res://Assets/RockShader.gdshader")

const ROCK_RENDER_DISTANCE := 200.0
const PLANET_RADIUS := 20.0
const MIN_DISTANCE := 0.8
const CELL_SIZE := MIN_DISTANCE

var chunks: Dictionary = {}
var _rock_material: ShaderMaterial

var _generation_thread: Thread = null
var _is_generating := false

class Chunk:
	var center: Vector3
	var node := Node3D.new()
	var multimeshes: Array[MultiMesh] = []
	var multimesh_instances: Array[MultiMeshInstance3D] = []
	var transforms: Array = []
	var colors: Array = []
	var custom_datas: Array = []


func _ready() -> void:
	rock_count *= GraphicsSettings.rock_count
	_rock_material = ShaderMaterial.new()
	_rock_material.shader = ROCK_SHADER

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


## Called externally (normally by GravitySource) to set the tint rocks
## should be generated around. Call this BEFORE regenerate()/start_generation()
## so the color is baked in on first generation, not a frame late.
func set_base_color(color: Color) -> void:
	base_rock_color = color


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
					mm.use_colors = true
					mm.use_custom_data = true
					var mmi := MultiMeshInstance3D.new()
					mmi.multimesh = mm
					mmi.material_override = _rock_material
					chunk.node.add_child(mmi)
					chunk.multimeshes.append(mm)
					chunk.multimesh_instances.append(mmi)
					chunk.transforms.append([])
					chunk.colors.append([])
					chunk.custom_datas.append([])
				add_child(chunk.node)
				chunks[Vector3i(x, y, z)] = chunk


## Public entry point: (re)generates rocks. Safe to call again later
## (e.g. after changing rock_count or base_rock_color), as long as a
## generation isn't already running -- check is_generating() first if you
## need to guard externally.
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
	var to_local_transform: Transform3D = self.global_transform.affine_inverse()
	_generation_thread = Thread.new()
	_generation_thread.start(
		_generate_rocks_threaded.bind(
			vertices, indices, sphere_transform, to_local_transform,
			rock_count, rock_meshes.size(),
			base_rock_color, hue_jitter, saturation_jitter, value_jitter
		)
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
	mesh_variant_count: int,
	color_base: Color,
	h_jitter: float,
	s_jitter: float,
	v_jitter: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var grid := {}
	var placed := 0
	var attempts := 0
	var max_attempts := target_rock_count * 10
	var result: Dictionary = {}
	for cx in [-1, 0, 1]:
		for cy in [-1, 0, 1]:
			for cz in [-1, 0, 1]:
				if cx == 0 and cy == 0 and cz == 0:
					continue
				var key := Vector3i(cx, cy, cz)
				var per_mesh_transforms: Array = []
				var per_mesh_colors: Array = []
				var per_mesh_custom: Array = []
				for i in range(mesh_variant_count):
					per_mesh_transforms.append([])
					per_mesh_colors.append([])
					per_mesh_custom.append([])
				result[key] = {
					"transforms": per_mesh_transforms,
					"colors": per_mesh_colors,
					"custom": per_mesh_custom
				}

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
		transform = to_local_transform * transform

		var chunk_key = Vector3i(
			1 if normal.x > 0.33 else (-1 if normal.x < -0.33 else 0),
			1 if normal.y > 0.33 else (-1 if normal.y < -0.33 else 0),
			1 if normal.z > 0.33 else (-1 if normal.z < -0.33 else 0)
		)
		if chunk_key == Vector3i.ZERO:
			continue

		var mesh_index = rng.randi() % mesh_variant_count
		var rock_color := Color.from_hsv(
			fmod(color_base.h + rng.randf_range(-h_jitter, h_jitter) + 1.0, 1.0),
			clamp(color_base.s + rng.randf_range(-s_jitter, s_jitter), 0.0, 1.0),
			clamp(color_base.v + rng.randf_range(-v_jitter, v_jitter), 0.05, 1.0)
		)

		# Per-rock random seed, packed into a Color and read in the shader
		# as INSTANCE_CUSTOM, so the shared procedural shader looks
		# different on every single rock instance.
		var custom_seed := Color(rng.randf(), rng.randf(), rng.randf(), 1.0)

		result[chunk_key]["transforms"][mesh_index].append(transform)
		result[chunk_key]["colors"][mesh_index].append(rock_color)
		result[chunk_key]["custom"][mesh_index].append(custom_seed)
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
		chunk.transforms = result[chunk_key]["transforms"]
		chunk.colors = result[chunk_key]["colors"]
		chunk.custom_datas = result[chunk_key]["custom"]
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
			var colors = chunk.colors[mesh_index]
			var custom_datas = chunk.custom_datas[mesh_index]
			mm.instance_count = transforms.size()
			for i in range(transforms.size()):
				mm.set_instance_transform(i, transforms[i])
				mm.set_instance_color(i, colors[i])
				mm.set_instance_custom_data(i, custom_datas[i])


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
		chunk.node.visible = chunk_dir.dot(cam_dir) > 0.2


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
