extends Node3D

@export var chunk_size :=  200.0
@export var stars_per_chunk :=  20
@export var render_distance := 5

var chunks: Dictionary = {}
var all_transforms: Array[Transform3D] = []
var all_colors: Array[Color] = []

var rng := RandomNumberGenerator.new()

func _ready():
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.4,0.4)
	
	$MultiMeshInstance3D.multimesh = MultiMesh.new()
	$MultiMeshInstance3D.multimesh.mesh = mesh
	$MultiMeshInstance3D.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	$MultiMeshInstance3D.multimesh.use_colors = true

var current_chunk := Vector3i(999999,999999,999999)

func _process(_delta):
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var p = camera.global_position
	var player_chunk = Vector3i(
		floor(snap_zero(p.x) / chunk_size),
		floor(snap_zero(p.y) / chunk_size),
		floor(snap_zero(p.z) / chunk_size)
	)
		
	if player_chunk != current_chunk:
		current_chunk = player_chunk
		generate_chunks(current_chunk)

func snap_zero(v: float) -> float: #to avoid the flashing chunk glitch
	if abs(v) < 0.01:
		return 0.0
	return v

var hi 
func generate_chunks(center):
	var wanted := {}
	for x in range(-render_distance, render_distance + 1):
		for y in range(-render_distance, render_distance + 1):
			for z in range(-render_distance, render_distance + 1):
				var chunk = center + Vector3i(x, y, z)
				if chunk == center:
					continue
				wanted[chunk] = true
				if !chunks.has(chunk):
					chunks[chunk] = generate_chunk(chunk)
	for chunk in chunks.keys():
		if !wanted.has(chunk):
			chunks.erase(chunk)
	rebuild_multimesh()

func generate_chunk(chunk):
	rng.seed = chunk.x * 73856093 ^ chunk.y * 19349663 ^ chunk.z * 83492791
	var transforms = []
	var colors = []
	var chunk_origin = Vector3(chunk) * chunk_size
	for i in stars_per_chunk:
		var pos = chunk_origin + Vector3(
			rng.randf_range(0, chunk_size),
			rng.randf_range(0, chunk_size),
			rng.randf_range(0, chunk_size)
		)
		var t := Transform3D.IDENTITY
		t.origin = pos
		t = t.scaled_local(Vector3.ONE * rng.randf_range(0.5,3.0))
		transforms.append(t)
		var r = rng.randf()
		var color: Color

		if r < 0.01:
			color = Color(0.396, 0.658, 1.0, 1.0)     
		elif r < 0.08:
			color = Color(0.778, 0.698, 1.0, 1.0)      
		elif r < 0.70:
			color = Color(1.0, 1.0, 1.0)      
		elif r < 0.92:
			color = Color(0.972, 0.822, 0.0, 1.0)   
		elif r < 0.98:
			color = Color(1.0, 0.507, 0.394, 1.0)   
		else:
			color = Color(0.264, 0.767, 0.0, 1.0)    

		colors.append(color)
	return {
		"transforms": transforms,
		"colors": colors
	}

func rebuild_multimesh():
	all_transforms.clear()
	all_colors.clear()
	for chunk in chunks.values():
		all_transforms.append_array(chunk.transforms)
		all_colors.append_array(chunk.colors)
	upload(all_transforms, all_colors)

func upload(transforms, colors):
	var mm = $MultiMeshInstance3D.multimesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
