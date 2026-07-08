extends Node
var resolution := Vector2i(1920, 1080)
var display_mode := DisplayServer.WINDOW_MODE_WINDOWED
var render_scale := 1.0
var glow := true
var ssao := true
var shadow_distance := 400.0
var sky_particle := 1.0
var rock_count := 1.0
var showkeybinds: bool = true

const SAVE_PATH := "user://graphics_settings.cfg"
const SECTION := "graphics"

func _ready():
	load_settings()
	get_tree().node_added.connect(_on_node_added)

func apply():
	DisplayServer.window_set_mode(display_mode)
	# Resolution
	if display_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution)
	# Render Scale
	get_viewport().scaling_3d_scale = render_scale
	# Apply to the current WorldEnvironment
	_apply_environment(get_viewport().world_3d.environment)
	save_settings()

func _apply_environment(env: Environment):
	if env == null:
		return
	env.glow_enabled = glow
	env.ssao_enabled = ssao

func _on_node_added(node):
	if node is WorldEnvironment:
		call_deferred("_apply_environment", node.environment)

func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(SECTION, "resolution_x", resolution.x)
	config.set_value(SECTION, "resolution_y", resolution.y)
	config.set_value(SECTION, "display_mode", display_mode)
	config.set_value(SECTION, "render_scale", render_scale)
	config.set_value(SECTION, "glow", glow)
	config.set_value(SECTION, "ssao", ssao)
	config.set_value(SECTION, "shadow_distance", shadow_distance)
	config.set_value(SECTION, "sky_particle", sky_particle)
	config.set_value(SECTION, "rock_count", rock_count)
	config.set_value(SECTION, "showkeybinds", showkeybinds)

	var err := config.save(SAVE_PATH)
	if err != OK:
		push_error("Failed to save graphics settings: %s" % err)

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)

	if err != OK:
		# No save file yet (first launch) — keep defaults.
		return

	var res_x: int = config.get_value(SECTION, "resolution_x", resolution.x)
	var res_y: int = config.get_value(SECTION, "resolution_y", resolution.y)
	resolution = Vector2i(res_x, res_y)
	display_mode = config.get_value(SECTION, "display_mode", display_mode)
	render_scale = config.get_value(SECTION, "render_scale", render_scale)
	glow = config.get_value(SECTION, "glow", glow)
	ssao = config.get_value(SECTION, "ssao", ssao)
	shadow_distance = config.get_value(SECTION, "shadow_distance", shadow_distance)
	sky_particle = config.get_value(SECTION, "sky_particle", sky_particle)
	rock_count = config.get_value(SECTION, "rock_count", rock_count)
	showkeybinds = config.get_value(SECTION, "showkeybinds", showkeybinds)
	apply()
