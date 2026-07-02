extends Node3D

var nearest_player = null
var sattelite_target = null
var displayed_satellites: Array = []

func _on_area_3d_body_entered(body):
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(self)


func _on_area_3d_body_exited(body):
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(null)
		$Control.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func get_mount_target():
	if sattelite_target == null:
		displayed_satellites.clear()
		$Control/ItemList.clear()
		for sat in SatelliteManager.satellites:
			if !is_instance_valid(sat):
				continue
			displayed_satellites.append(sat)
			var name = sat.satellite_name
			if sat.assigned_observatory != null and sat.assigned_observatory != self:
				name += " (Assigned)"
			$Control/ItemList.add_item(name)
		$Control.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return null
	return sattelite_target

func _on_item_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if index < 0 or index >= displayed_satellites.size():
		return

	var sat = displayed_satellites[index]

	# Already assigned to another observatory?
	if sat.assigned_observatory != null and sat.assigned_observatory != self:
		return

	# Release our previous assignment.
	if is_instance_valid(sattelite_target):
		sattelite_target.assigned_observatory = null

	sattelite_target = sat
	sat.assigned_observatory = self

	$Control.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
