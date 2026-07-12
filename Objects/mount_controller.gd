extends Node
@onready var player: CharacterBody3D = get_parent()

func mount(target) -> void:
	player.mount_source = target
	if target.is_in_group("observatory"):
		if !player.satellite_ui.visible:
			player.satellite_ui_controller.show_satellite_ui(target)
		else:
			player.satellite_ui_controller.hide_satellite_ui()
		return
	do_mount(target)

func do_mount(target) -> void:
	if target == null:
		return
	if player.mounted_target != null and is_instance_valid(player.mounted_target):
		player.mounted_target.has_player = false
	player.is_mounted = true
	player.mounted_target = target
	player.visible = false
	player.get_node("CollisionShape3D").disabled = true
	player.set_physics_process(false)
	player.fp_camera.current = false
	player.get_tree().get_first_node_in_group("camera_rig").activate()
	CameraManager.override_target = target
	target.has_player = true
	if GraphicsSettings.showkeybinds:
		player.get_node("Help").hide()

func unmount() -> void:
	player.is_mounted = false
	player.visible = true
	player.get_node("CollisionShape3D").disabled = false
	player.set_physics_process(true)
	if player.mount_source:
		if player.mount_source.has_node("PlayerExitMarker"):
			player.global_position = player.mount_source.get_node("PlayerExitMarker").global_position
		else:
			player.global_position = player.mount_source.global_position + player.mount_source.global_transform.basis.x * 3.0
	if player.mounted_target:
		player.mounted_target.has_player = false
	player.mounted_target = null
	player.mount_source = null
	player.velocity = Vector3.ZERO
	player.pitch = 0.0
	CameraManager.override_target = null
	CameraManager.set_current(player)
	player.get_tree().get_first_node_in_group("camera_rig").deactivate()
	player.fp_camera.current = true
	if GraphicsSettings.showkeybinds:
		player.get_node("Help").show()
