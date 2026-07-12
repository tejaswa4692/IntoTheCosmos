extends Node3D

@onready var resolution: OptionButton = $Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/resolution
@onready var display: OptionButton = $Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer2/display
@onready var render_scale: OptionButton = $Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer5/renderscale
@onready var settings: Control = $Settings2
@onready var player = $Boney


func _ready() -> void:
	$LoadingScreen.show()
	settings_ready()
	load_current_settings()
	$LoadingScreen/Load.play("Load")
	if !MusicAutoload.music_player.playing:
		MusicAutoload.play(preload("res://Assets/Music/Ambient Space Synth Music (For Videos) - Adrift by Hayden Folker.mp3"))

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if Input.is_action_just_pressed("R"):
			reset_player()
		if Input.is_action_just_pressed("ui_cancel"):
			settings.visible = !settings.visible
			if !settings.visible:
				player.settings_open = false
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			if settings.visible:
				player.settings_open = true

func reset_player() -> void:
	player.global_transform = $PlayerLoc.global_transform
	$Rocket.global_transform = $RocketLoc.global_transform


func _on_load_animation_finished(_anim_name: StringName) -> void:
	$LoadingScreen.queue_free()


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
	# Checkboxes
	$Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/Glow2.button_pressed = GraphicsSettings.glow
	$Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/SSAOButton.button_pressed = GraphicsSettings.ssao
	$Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer6/Keybinds.button_pressed = GraphicsSettings.showkeybinds


func settings_ready() -> void:
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
	settings.hide()


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
	GraphicsSettings.glow = $Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer3/Glow2.button_pressed
	GraphicsSettings.ssao = $Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer4/SSAOButton.button_pressed
	GraphicsSettings.showkeybinds = $Settings2/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer6/Keybinds.button_pressed
	GraphicsSettings.apply()


func _on_back_pressed() -> void:
	settings.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://Objects/hi.tscn")
