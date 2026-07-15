extends Node3D
class_name GravitySource

@export var gravity_strength: float = 9.8
@export var mass: float = 5000.0
@export var use_inverse_square: bool = true
@export var min_influence_threshold: float = 0.5 
var has_observatory: bool = false

@export_group("Atmosphere")
@export var sun_node: Node3D
@export var atmosphere_height_ratio: float = 1.15 # atmosphere_radius = planet_radius * this
@export var atmosphere_intensity_multiplier: float = 0.235 
var atmosphere_material: ShaderMaterial
var atmosphere_mesh_instance: MeshInstance3D

@export_group("Planet Appearance")
@export var planet_seed: int = -1  
@export var randomize_appearance: bool = true
var rock_mesh = preload("res://Assets/Debries/rock.obj") as Mesh

@export_group("Planet Properties")
@export var temperature_min: float = -150.0
@export var temperature_max: float = 150.0
@export var cold_threshold: float = -20.0   # at/below this -> ICE
@export var hot_threshold: float = 60.0     # at/above this -> MAGMA
@export var min_air_for_water: float = 0.3  # temperate planets need at least this much air to hold water
var temperature: float = 15.0
var air_density: float = 1.0  # 0 = vacuum, 1 = earth-like
var has_water: bool = false

enum PlanetClimate { ICE, TEMPERATE, MAGMA }
var climate: PlanetClimate = PlanetClimate.TEMPERATE

var water_mesh_instance: MeshInstance3D

const FIXED_NOISE_SCALE: float = 2.50
const FIXED_PERSISTENCE: float = 0.95
const FIXED_ICE_CAPS: float = 0.0
const FIXED_ROUGHNESS: float = 1.0
const FIXED_ATMOSPHERE_STRENGTH: float = 0.0

enum NoiseType { PERLIN, CELLULAR, CLOUD, MARBLE}
const PLANET_SHADER: Shader = preload("res://Assets/Planet-Icosphere/PlanetShader.gdshader")
const ATMOSPHERE_SHADER: Shader = preload("res://Objects/Planets/atmosphere.gdshader")

@onready var camera: Camera3D = get_viewport().get_camera_3d()
var soi_radius: float = 0.0
var planet_material: ShaderMaterial
var planet_radius: float = 0.0 
var planet_color_deep: Color = Color.WHITE 



func _ready() -> void:
	_recalculate_soi()
	GravityManager.register(self)

	var timer := get_node_or_null("LODUpdateTimer")
	if timer == null:
		push_error("GravitySource on '%s': LODUpdateTimer not found! Children: %s" % [name, get_children()])
	else:
		if not timer.timeout.is_connected(_on_lod_timer_timeout):
			timer.timeout.connect(_on_lod_timer_timeout)

	var collision_shape := get_node_or_null("StaticBody3D/CollisionShape3D")
	if collision_shape and collision_shape.shape:
		planet_radius = collision_shape.shape.radius * scale.x
	else:
		push_warning("GravitySource on '%s': collision shape not found, atmosphere radius will default to 0." % name)

	atmosphere_mesh_instance = get_node_or_null("AtmosphereMesh") as MeshInstance3D
	if atmosphere_mesh_instance == null:
		push_warning("GravitySource on '%s': 'AtmosphereMesh' node not found, skipping atmosphere setup." % name)

	water_mesh_instance = get_node_or_null("WaterShader") as MeshInstance3D
	if water_mesh_instance == null:
		push_warning("GravitySource on '%s': 'WaterShader' node not found, skipping water setup." % name)
	else:
		water_mesh_instance.visible = false 

	if sun_node == null:
		sun_node = _find_active_directional_light()
		if sun_node == null:
			push_warning("GravitySource on '%s': no DirectionalLight3D found in scene, atmosphere will not track sun direction." % name)

	if randomize_appearance:
		_generate_planet_material()
		_apply_material_to_lods()
		_generate_atmosphere_material()


func _exit_tree() -> void:
	GravityManager.unregister(self) 

func _process(_delta: float) -> void:
	if atmosphere_material == null:
		return
	# planet_center is world-space and must stay current if the planet orbits/moves
	atmosphere_material.set_shader_parameter("planet_center", global_position)
	if sun_node != null:
		var dir_to_sun: Vector3 = (sun_node.global_position - global_position).normalized()
		atmosphere_material.set_shader_parameter("sun_direction", dir_to_sun)

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

func _find_active_directional_light() -> DirectionalLight3D:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _search_for_directional_light(root)

func _search_for_directional_light(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		var light := node as DirectionalLight3D
		if light.visible and light.light_energy > 0.0:
			return light
	for child in node.get_children():
		var result := _search_for_directional_light(child)
		if result != null:
			return result
	return null

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

func _classify_climate() -> void:
	if temperature <= cold_threshold:
		climate = PlanetClimate.ICE
	elif temperature >= hot_threshold:
		climate = PlanetClimate.MAGMA
	else:
		climate = PlanetClimate.TEMPERATE

func _update_water() -> void:
	has_water = climate == PlanetClimate.TEMPERATE and air_density >= min_air_for_water
	if water_mesh_instance != null:
		water_mesh_instance.visible = has_water

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
	temperature = rng.randf_range(temperature_min, temperature_max)
	air_density = rng.randf_range(0.0, 1.5)
	_classify_climate()

	var base_hue := rng.randf()
	var color_deep: Color
	var color_low: Color
	var color_mid: Color
	var color_high: Color

	match climate:
		PlanetClimate.ICE:
			# pale blue/white/cyan, low saturation, high value -> reads as icy
			var ice_hue := rng.randf_range(0.5, 0.65)
			color_deep = Color.from_hsv(ice_hue, rng.randf_range(0.15, 0.35), rng.randf_range(0.55, 0.7))
			color_low = Color.from_hsv(ice_hue, rng.randf_range(0.1, 0.25), rng.randf_range(0.7, 0.85))
			color_mid = Color.from_hsv(ice_hue - 0.05, rng.randf_range(0.05, 0.15), rng.randf_range(0.85, 0.95))
			color_high = Color.from_hsv(ice_hue, 0.02, rng.randf_range(0.95, 1.0))
		PlanetClimate.MAGMA:
		
			var magma_hue := rng.randf_range(0.0, 0.06)
			color_deep = Color.from_hsv(magma_hue, rng.randf_range(0.7, 0.9), rng.randf_range(0.05, 0.15))
			color_low = Color.from_hsv(magma_hue + 0.01, rng.randf_range(0.8, 1.0), rng.randf_range(0.3, 0.5))
			color_mid = Color.from_hsv(magma_hue + 0.03, rng.randf_range(0.85, 1.0), rng.randf_range(0.5, 0.75))
			color_high = Color.from_hsv(magma_hue + 0.05, rng.randf_range(0.6, 0.9), rng.randf_range(0.8, 1.0))
		PlanetClimate.TEMPERATE:
			color_deep = Color.from_hsv(base_hue, rng.randf_range(0.5, 0.9), rng.randf_range(0.1, 0.3))
			color_low = Color.from_hsv(fmod(base_hue + 0.02, 1.0), rng.randf_range(0.4, 0.8), rng.randf_range(0.3, 0.5))
			color_mid = Color.from_hsv(fmod(base_hue + 0.05, 1.0), rng.randf_range(0.3, 0.6), rng.randf_range(0.5, 0.7))
			color_high = Color.from_hsv(fmod(base_hue + 0.1, 1.0), rng.randf_range(0.1, 0.4), rng.randf_range(0.7, 0.95))

	planet_color_deep = color_deep 

	gravity_strength = randf_range(5, 10)

	planet_material.set_shader_parameter("color_deep", color_deep)
	planet_material.set_shader_parameter("color_low", color_low)
	planet_material.set_shader_parameter("color_mid", color_mid)
	planet_material.set_shader_parameter("color_high", color_high)
	planet_material.set_shader_parameter("rim_power", rng.randf_range(1.5, 4.0))

	_update_water()

	var scatterer := get_node_or_null("PlanetRockScatterer")
	if scatterer:
		scatterer.set_base_color(color_low)
		if scatterer.has_method("regenerate") and not scatterer.is_generating():
			scatterer.regenerate()

	var scrap_scatterer := get_node_or_null("PlanetScrapScatterer")
	if scrap_scatterer:
		if scrap_scatterer.has_method("regenerate") and not scrap_scatterer.is_generating():
			scrap_scatterer.regenerate()

func _generate_atmosphere_material() -> void:
	if atmosphere_mesh_instance == null:
		return
	if planet_radius <= 0.0:
		push_warning("GravitySource on '%s': planet_radius is 0, atmosphere scattering will not render correctly." % name)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed  # ties atmosphere character to this planet's identity, like the surface material

	atmosphere_material = ShaderMaterial.new()
	atmosphere_material.shader = ATMOSPHERE_SHADER

	var atmosphere_radius := planet_radius * atmosphere_height_ratio

	atmosphere_material.set_shader_parameter("planet_center", global_position)
	atmosphere_material.set_shader_parameter("planet_radius", planet_radius)
	atmosphere_material.set_shader_parameter("atmosphere_radius", atmosphere_radius)
	atmosphere_material.set_shader_parameter("density_falloff", rng.randf_range(6.0, 10.0))
	atmosphere_material.set_shader_parameter("intensity", rng.randf_range(12.0, 24.0) * atmosphere_intensity_multiplier)
	atmosphere_material.set_shader_parameter("mie_coefficient", rng.randf_range(15.0, 25.0))
	var base_total := 5.5 + 13.0 + 22.4
	var col_sum: float = planet_color_deep.r + planet_color_deep.g + planet_color_deep.b
	if col_sum <= 0.001:
		col_sum = 1.0
	var rayleigh_coefficients := Vector3(
		planet_color_deep.r / col_sum * base_total,
		planet_color_deep.g / col_sum * base_total,
		planet_color_deep.b / col_sum * base_total
	)
	atmosphere_material.set_shader_parameter("rayleigh_coefficients", rayleigh_coefficients)
	atmosphere_material.set_shader_parameter("sun_direction", Vector3.RIGHT)

	atmosphere_mesh_instance.material_override = atmosphere_material
	if atmosphere_mesh_instance.mesh is SphereMesh:
		var sphere_mesh := (atmosphere_mesh_instance.mesh as SphereMesh).duplicate() as SphereMesh
		sphere_mesh.radius = atmosphere_radius
		sphere_mesh.height = atmosphere_radius * 2.0
		atmosphere_mesh_instance.mesh = sphere_mesh

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
