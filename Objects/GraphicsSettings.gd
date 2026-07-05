extends Node

var resolution := Vector2i(1920, 1080)
var display_mode := DisplayServer.WINDOW_MODE_WINDOWED
var render_scale := 1.0
var glow := true
var ssao := true
var shadow_distance := 400.0

func _ready():
	get_tree().node_added.connect(_on_node_added)

func apply():
	# Window mode
	DisplayServer.window_set_mode(display_mode)

	# Resolution
	if display_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution)

	# Render Scale
	get_viewport().scaling_3d_scale = render_scale

	# Apply to the current WorldEnvironment
	_apply_environment(get_viewport().world_3d.environment)

func _apply_environment(env: Environment):
	if env == null:
		return

	env.glow_enabled = glow
	env.ssao_enabled = ssao

func _on_node_added(node):
	if node is WorldEnvironment:
		call_deferred("_apply_environment", node.environment)
