extends Node3D

@export var rock_meshes: Array[Mesh] = [preload("res://Assets/Debries/rock2.obj"),
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
const ROCK_RENDER_DISTANCE := 200.0

const PLANET_RADIUS := 20.0

var chunks: Dictionary = {}

class Chunk:
	var center: Vector3
	var node := Node3D.new()
	var multimeshes: Array[MultiMesh] = []
	var multimesh_instances: Array[MultiMeshInstance3D] = []
	var transforms: Array = []

func _ready() -> void:
	create_chunks()
	generate_rocks()
	build_multimeshes()

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
				#draw_debug_cube(chunk)
				add_child(chunk.node)
				chunks[Vector3i(x, y, z)] = chunk

func generate_rocks() -> void:
	var sphere: MeshInstance3D = get_parent().get_node("Planet-LOD/LOD-Nearest")

	var arrays = sphere.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	const MIN_DISTANCE := 0.8
	const CELL_SIZE := MIN_DISTANCE

	var grid := {}

	var placed := 0
	var attempts := 0
	var max_attempts := rock_count * 10

	while placed < rock_count and attempts < max_attempts:
		attempts += 1
		# Random triangle
		var tri = (randi() % (indices.size() / 3)) * 3
		var a = vertices[indices[tri]]
		var b = vertices[indices[tri + 1]]
		var c = vertices[indices[tri + 2]]
		# Uniform barycentric sampling
		var r1 = sqrt(randf())
		var r2 = randf()
		var pos = (1.0 - r1) * a + r1 * (1.0 - r2) * b + r1 * r2 * c
		var normal = pos.normalized()
		var world_pos = sphere.global_transform * pos
		var cell = Vector3i(
			floor(world_pos.x / CELL_SIZE),
			floor(world_pos.y / CELL_SIZE),
			floor(world_pos.z / CELL_SIZE)
		)
		var valid := true
		for x in range(cell.x - 1, cell.x + 2):
			for y in range(cell.y - 1, cell.y + 2):
				for z in range(cell.z - 1, cell.z + 2):
					var key = Vector3i(x, y, z)
					if !grid.has(key):
						continue
					for other in grid[key]:
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
		basis = basis.rotated(up, randf() * TAU)
		basis = basis.rotated(right, randf_range(-0.2, 0.2))
		basis = basis.rotated(forward, randf_range(-0.2, 0.2))
		var scale = randf_range(0.7, 1.4)
		basis = basis.scaled(Vector3.ONE * scale)
		var transform = Transform3D(basis, world_pos)
		
		var chunk = Vector3i(
			1 if normal.x > 0.33 else (-1 if normal.x < -0.33 else 0),
			1 if normal.y > 0.33 else (-1 if normal.y < -0.33 else 0),
			1 if normal.z > 0.33 else (-1 if normal.z < -0.33 else 0)
		)
		
		if chunk == Vector3i.ZERO:
			continue
		
		var mesh_index = randi() % rock_meshes.size()
		chunks[chunk].transforms[mesh_index].append(transform)
		placed += 1


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

	# Too far away? Hide everything.
	if distance > ROCK_RENDER_DISTANCE:
		for chunk in chunks.values():
			chunk.node.visible = false
		return

	var cam_dir = (camera.global_position - planet_pos).normalized()

	for chunk in chunks.values():
		var chunk_dir = chunk.center.normalized()
		chunk.node.visible = chunk_dir.dot(cam_dir) > 0.6

#This is only for looking at the chunks  when debugging
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
