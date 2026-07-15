extends Node
@onready var player: CharacterBody3D = get_parent()

var displayed_satellites: Array = []
var current_observatory = null

func show_satellite_ui(selected_observatory) -> void:
	player.ui_open = true
	InventoryGlobal.isUIopen = true
	current_observatory = selected_observatory
	displayed_satellites.clear()
	player.satellite_item_list.clear()
	for sat in SatelliteManager.satellites:
		if !is_instance_valid(sat):
			continue
		displayed_satellites.append(sat)
		var label = sat.satellite_name
		if sat.assigned_observatory != null and sat.assigned_observatory != selected_observatory:
			label += " (Assigned)"
		player.satellite_item_list.add_item(label)
	player.satellite_ui.show()
	player.satellite_ui.get_node("MainMenu").show()
	player.satellite_item_list.hide()
	player.satellite_ui.get_node("UpgradesList").hide()
	player.satellite_ui.get_node("SatelliteText").hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if selected_observatory.satellite_target != null:
		player.satellite_ui.get_node("MainMenu").set_item_text(0, "Control Satellite")
	elif selected_observatory.satellite_target == null:
		player.satellite_ui.get_node("MainMenu").set_item_text(0, "Satelite Manager")

func hide_satellite_ui() -> void:
	player.ui_open = false
	InventoryGlobal.isUIopen = false
	player.satellite_ui.hide()
	player.satellite_ui.get_node("MainMenu").hide()
	player.satellite_item_list.hide()
	player.satellite_ui.get_node("UpgradesList").hide()
	player.satellite_ui.get_node("SatelliteText").hide()
	current_observatory = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func on_item_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if current_observatory == null:
		return
	if index < 0 or index >= displayed_satellites.size():
		return
	var sat = displayed_satellites[index]
	if sat.assigned_observatory != null and sat.assigned_observatory != current_observatory:
		return
	current_observatory.assign_satellite(sat)
	hide_satellite_ui()


func on_done_button_pressed() -> void:
	if current_observatory != null and current_observatory.rocket != null:
		current_observatory.dock_satellite_on_rocket(player.satellite_ui.get_node("SatelliteText/LineEdit").text)
		hide_satellite_ui()
	else:
		hide_satellite_ui()


func _on_main_menu_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	print(index)
	match index:
		0:
			if current_observatory.satellite_target != null:
				var sat = current_observatory.get_mount_target()
				hide_satellite_ui()
				player.mount_controller.do_mount(sat)
			else:
				player.satellite_ui.get_node("MainMenu").hide()
				player.satellite_item_list.show()
				player.satellite_ui.get_node("UpgradesList").hide()
		1:
			player.satellite_ui.get_node("MainMenu").hide()
			player.satellite_item_list.hide()
			player.satellite_ui.get_node("UpgradesList").show()
		2:
			current_observatory.pleaserefuel()
			hide_satellite_ui()
		3:
			player.satellite_ui.get_node("SatelliteText").show()
		4:
			current_observatory.spawn_vehicle_rover()
