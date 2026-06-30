extends Node3D
class_name OrbitVisualizer

@export var orbit_resolution: int = 128
@export var orbit_color: Color = Color(0, 1, 0.6)
@export var enabled: bool = true

var orbit_mesh: MeshInstance3D
var body: RigidBody3D

func _ready() -> void:
	body = get_parent() as RigidBody3D
	orbit_mesh = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = orbit_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orbit_mesh.material_override = mat
	get_tree().root.call_deferred("add_child", orbit_mesh)
	await get_tree().process_frame
	print("orbit_mesh parent after deferred add: ", orbit_mesh.get_parent())

func _exit_tree() -> void:
	if is_instance_valid(orbit_mesh):
		orbit_mesh.queue_free()

func _physics_process(_delta: float) -> void:
	
	if enabled and body != null and is_instance_valid(body):
		_draw_orbit()
	else:
		orbit_mesh.mesh = null

func _draw_orbit() -> void:
	if GravityManager.sources.size() == 0:
		orbit_mesh.mesh = null
		return

	var source: GravitySource = null
	var closest_dist := INF
	for s in GravityManager.sources:
		var d = (body.global_position - s.global_position).length()
		if d < closest_dist:
			closest_dist = d
			source = s
	
	var mu = source.gravity_strength * source.mass
	if mu <= 0.001:
		orbit_mesh.mesh = null
		return

	var r_vec = body.global_position - source.global_position
	var v_vec = body.linear_velocity
	var r = r_vec.length()
	var v = v_vec.length()

	if r < 0.01 or v < 0.01:
		orbit_mesh.mesh = null
		return

	var energy = (v * v) / 2.0 - mu / r
	if energy >= 0:
		orbit_mesh.mesh = null
		return

	var a = -mu / (2.0 * energy)
	var e_vec = (v_vec.cross(r_vec.cross(v_vec)) / mu) - r_vec.normalized()
	var e = e_vec.length()

	if e >= 1.0 or a <= 0:
		orbit_mesh.mesh = null
		return

	var b = a * sqrt(1.0 - e * e)
	var h_vec = r_vec.cross(v_vec)
	if h_vec.length() < 0.001:
		orbit_mesh.mesh = null
		return
	h_vec = h_vec.normalized()

	var e_dir = e_vec.normalized() if e > 0.001 else r_vec.normalized()
	var p_dir = h_vec.cross(e_dir).normalized()
	var center = source.global_position + e_dir * a * e

	# build a thick ribbon instead of a thin line
	var line_width = max(a, b) * 0.01  # scales with orbit size, tweak as needed
	var arr_mesh = ArrayMesh.new()
	var verts = PackedVector3Array()
	var indices = PackedInt32Array()

	var points: Array[Vector3] = []
	for i in range(orbit_resolution + 1):
		var angle = (float(i) / orbit_resolution) * TAU
		points.append(center + e_dir * (cos(angle) * a) + p_dir * (sin(angle) * b))

	for i in range(points.size() - 1):
		var p0 = points[i]
		var p1 = points[i + 1]
		var dir = (p1 - p0).normalized()
		var side = h_vec.cross(dir).normalized() * line_width

		var idx = verts.size()
		verts.append(p0 - side)
		verts.append(p0 + side)
		verts.append(p1 - side)
		verts.append(p1 + side)

		indices.append(idx); indices.append(idx + 1); indices.append(idx + 2)
		indices.append(idx + 1); indices.append(idx + 3); indices.append(idx + 2)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	orbit_mesh.mesh = arr_mesh

	print("a: ", a, " e: ", e, " r: ", r, " v: ", v)
