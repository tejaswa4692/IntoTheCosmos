extends Node3D
class_name GravitySource

@export var gravity_strength: float = 9.8
@export var mass: float = 5000.0
@export var use_inverse_square: bool = true
@export var min_influence_threshold: float = 0.5 
var has_observatory: bool = false

@export_group("Planet Appearance")
@export var planet_seed: int = -1  
@export var randomize_appearance: bool = true
var rock_mesh = preload("res://Assets/Debries/rock.obj") as Mesh

const FIXED_NOISE_SCALE: float = 2.50
const FIXED_PERSISTENCE: float = 0.95
const FIXED_ICE_CAPS: float = 0.0
const FIXED_ROUGHNESS: float = 1.0
const FIXED_ATMOSPHERE_STRENGTH: float = 0.0

enum NoiseType { PERLIN, CELLULAR, MARBLE, CLOUD}
const PLANET_SHADER: Shader = preload("res://Assets/Planet-Icosphere/PlanetShader.gdshader")

@onready var camera: Camera3D = get_viewport().get_camera_3d()
var soi_radius: float = 0.0
var planet_material: ShaderMaterial



func _ready() -> void:
	_recalculate_soi()
	GravityManager.register(self)

	var timer := get_node_or_null("LODUpdateTimer")
	if timer == null:
		push_error("GravitySource on '%s': LODUpdateTimer not found! Children: %s" % [name, get_children()])
	else:
		if not timer.timeout.is_connected(_on_lod_timer_timeout):
			timer.timeout.connect(_on_lod_timer_timeout)

	if randomize_appearance:
		_generate_planet_material()
		_apply_material_to_lods()

func _exit_tree() -> void:
	GravityManager.unregister(self) 

func _debug_draw_soi() -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = soi_radius
	sphere.height = soi_radius * 2.0

	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.776, 0.4, 0.498, 0.353)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	mesh_instance.mesh = sphere
	add_child(mesh_instance)

func _recalculate_soi() -> void:
	if use_inverse_square and min_influence_threshold > 0.0:
		soi_radius = sqrt(gravity_strength * mass / min_influence_threshold)
	else:
		soi_radius = 0.0

func _on_lod_timer_timeout() -> void:
	camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := global_position.distance_to(camera.global_position)
	var radius: float = $StaticBody3D/CollisionShape3D.shape.radius * scale.x
	if distance < 30 + radius:
		$"Planet-LOD/LOD-Nearest".show()
		$"Planet-LOD/LOD-Mid".hide()
		$"Planet-LOD/LOD-Farthest".hide()
	elif distance < 1000 + radius:
		$"Planet-LOD/LOD-Nearest".hide()
		$"Planet-LOD/LOD-Mid".show()
		$"Planet-LOD/LOD-Farthest".hide()
	else:
		$"Planet-LOD/LOD-Nearest".hide()
		$"Planet-LOD/LOD-Mid".hide()
		$"Planet-LOD/LOD-Farthest".show()

func randomize_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	if planet_seed == -1:
		rng.randomize()
		planet_seed = rng.seed  
	else:
		rng.seed = planet_seed
	$PlanetRockScatterer.rock_count = randi_range(3000, 10000)

func _generate_planet_material() -> void:
	var rng := RandomNumberGenerator.new()
	if planet_seed == -1:
		rng.randomize()
		planet_seed = rng.seed  
	else:
		rng.seed = planet_seed
	planet_material = ShaderMaterial.new()
	planet_material.shader = PLANET_SHADER
	var chosen_type := rng.randi_range(0, 3)
	planet_material.set_shader_parameter("noise_type", chosen_type)
	planet_material.set_shader_parameter("seed", rng.randf_range(0.0, 1000.0))
	planet_material.set_shader_parameter("octaves", rng.randi_range(3, 6))
	planet_material.set_shader_parameter("noise_scale", FIXED_NOISE_SCALE)
	planet_material.set_shader_parameter("persistence", FIXED_PERSISTENCE)
	planet_material.set_shader_parameter("ice_caps", FIXED_ICE_CAPS)
	planet_material.set_shader_parameter("roughness_val", FIXED_ROUGHNESS)
	planet_material.set_shader_parameter("atmosphere_strength", FIXED_ATMOSPHERE_STRENGTH)
	
	var base_hue := rng.randf()
	var color_deep := Color.from_hsv(base_hue, rng.randf_range(0.5, 0.9), rng.randf_range(0.1, 0.3))
	var color_low := Color.from_hsv(fmod(base_hue + 0.02, 1.0), rng.randf_range(0.4, 0.8), rng.randf_range(0.3, 0.5))
	var color_mid := Color.from_hsv(fmod(base_hue + 0.05, 1.0), rng.randf_range(0.3, 0.6), rng.randf_range(0.5, 0.7))
	var color_high := Color.from_hsv(fmod(base_hue + 0.1, 1.0), rng.randf_range(0.1, 0.4), rng.randf_range(0.7, 0.95))
	
	gravity_strength = randf_range(5, 10)
	
	planet_material.set_shader_parameter("color_deep", color_deep)
	planet_material.set_shader_parameter("color_low", color_low)
	planet_material.set_shader_parameter("color_mid", color_mid)
	planet_material.set_shader_parameter("color_high", color_high)
	planet_material.set_shader_parameter("rim_power", rng.randf_range(1.5, 4.0))

	var scatterer := get_node_or_null("PlanetRockScatterer")
	if scatterer:
		scatterer.set_base_color(color_low)
		if scatterer.has_method("regenerate") and not scatterer.is_generating():
			scatterer.regenerate()

func _apply_material_to_lods() -> void:
	var lod_root := get_node_or_null("Planet-LOD")
	if lod_root == null:
		push_warning("GravitySource: 'Planet-LOD' node not found, skipping material apply.")
		return

	for lod_name in ["LOD-Nearest", "LOD-Mid", "LOD-Farthest"]:
		var lod_node := lod_root.get_node_or_null(lod_name)
		if lod_node is MeshInstance3D:
			lod_node.material_override = planet_material


func change_observatory_status() -> void:
	has_observatory = true
