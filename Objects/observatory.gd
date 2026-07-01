extends Node3D

var nearest_player = null
var sattelite_target = null

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
		$Control/ItemList.clear()

		for sat in SatelliteManager.satellites:
			$Control/ItemList.add_item(sat.satellite_name)

		$Control.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		return null

	return sattelite_target
		

func _on_item_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	sattelite_target = SatelliteManager.satellites[index]

	$Control.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
