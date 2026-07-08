extends Node3D

@onready var resolution: OptionButton = $Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/resolution
@onready var display: OptionButton = $Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/display
@onready var render_scale: OptionButton = $Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer5/renderscale
@onready var sky_particle: OptionButton = $Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/SkyParcticle/SkyParticle
@onready var rock_count: OptionButton = $Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/RockDensity/RockDensity


func _ready() -> void:
	resolution.add_item("1280×720")
	resolution.add_item("1600×900")
	resolution.add_item("1920×1080")
	resolution.add_item("2560×1440")

	display.add_item("Windowed")
	display.add_item("Borderless")
	display.add_item("Fullscreen")

	render_scale.add_item("50%")
	render_scale.add_item("75%")
	render_scale.add_item("100%")
	render_scale.add_item("125%")
	
	sky_particle.add_item("25%")
	sky_particle.add_item("50%")
	sky_particle.add_item("75%")
	sky_particle.add_item("100%")
	
	rock_count.add_item("0%")
	rock_count.add_item("25%")
	rock_count.add_item("50%")
	rock_count.add_item("75%")
	rock_count.add_item("100%")
	$Control/Settings2.hide()


func _on_apply_pressed():
	match resolution.selected:
		0:
			GraphicsSettings.resolution = Vector2i(1280,720)
		1:
			GraphicsSettings.resolution = Vector2i(1600,900)
		2:
			GraphicsSettings.resolution = Vector2i(1920,1080)
		3:
			GraphicsSettings.resolution = Vector2i(2560,1440)
	match display.selected:
		0:
			GraphicsSettings.display_mode = DisplayServer.WINDOW_MODE_WINDOWED
		1:
			GraphicsSettings.display_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		2:
			GraphicsSettings.display_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	match render_scale.selected:
		0:
			GraphicsSettings.render_scale = 0.5
		1:
			GraphicsSettings.render_scale = 0.75
		2:
			GraphicsSettings.render_scale = 1.0
		3:
			GraphicsSettings.render_scale = 1.25
	match sky_particle.selected:
		0:
			GraphicsSettings.sky_particle = 0.25
		1:
			GraphicsSettings.sky_particle = 0.5
		2:
			GraphicsSettings.sky_particle = 0.75
		3:
			GraphicsSettings.sky_particle = 1.0
	match rock_count.selected:
		0:
			GraphicsSettings.rock_count = 0.0
		1:
			GraphicsSettings.rock_count = 0.25
		2:
			GraphicsSettings.rock_count = 0.5
		3:
			GraphicsSettings.rock_count = 0.75
		4:
			GraphicsSettings.rock_count = 1.0
	GraphicsSettings.glow = $Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/Glow2.button_pressed
	GraphicsSettings.ssao = $Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/SSAOButton.button_pressed
	GraphicsSettings.showkeybinds = $Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer6/Keybinds.button_pressed
	GraphicsSettings.apply()
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	$Camera_center.rotation_degrees.y += 5 * delta

func load_current_settings():
	# Resolution
	match GraphicsSettings.resolution:
		Vector2i(1280, 720):
			resolution.select(0)
		Vector2i(1600, 900):
			resolution.select(1)
		Vector2i(1920, 1080):
			resolution.select(2)
		Vector2i(2560, 1440):
			resolution.select(3)

	# Display Mode
	match GraphicsSettings.display_mode:
		DisplayServer.WINDOW_MODE_WINDOWED:
			display.select(0)
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			display.select(1)
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			display.select(2)

	# Render Scale
	match GraphicsSettings.render_scale:
		0.5:
			render_scale.select(0)
		0.75:
			render_scale.select(1)
		1.0:
			render_scale.select(2)
		1.25:
			render_scale.select(3)
	match GraphicsSettings.sky_particle:
		0.25:
			sky_particle.select(0)
		0.5:
			sky_particle.select(1)
		0.75:
			sky_particle.select(2)
		1.0:
			sky_particle.select(3)
	match GraphicsSettings.rock_count:
		0.0:
			rock_count.select(0)
		0.25:
			rock_count.select(1)
		0.5:
			rock_count.select(2)
		0.75:
			rock_count.select(3)
		1.0:
			rock_count.select(4)
	# Checkboxes
	$Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/Glow2.button_pressed = GraphicsSettings.glow
	$Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/SSAOButton.button_pressed = GraphicsSettings.ssao
	$Control/Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer6/Keybinds.button_pressed = GraphicsSettings.showkeybinds

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Objects/PlaygroundWorld.tscn")


func _on_settings_pressed() -> void:
	load_current_settings()
	$Control/Settings2.show()
	$Control/MainMenu.hide()


func _on_back_pressed() -> void:
	$Control/Settings2.hide()
	$Control/MainMenu.show()
