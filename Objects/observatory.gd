extends Node3D

var satellite_target = null
var rocket_based :  bool = false
var rocket = null

func _on_area_3d_body_entered(body):
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(self)

func _on_area_3d_body_exited(body):
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(null)
	if body.has_method("hide_satellite_ui"):
		body.hide_satellite_ui()

func get_mount_target():
	return satellite_target

func assign_satellite(sat) -> void:
	if is_instance_valid(satellite_target):
		satellite_target.assigned_observatory = null
	satellite_target = sat
	sat.assigned_observatory = self
#
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("setup_sattelite") and rocket_based:
		rocket.setup_sattelite()

func _on_rocket_rebaser_body_entered(body: Node3D) -> void:
	if body.is_in_group("rocket"):
		rocket_based = true
		rocket = body


func _on_rocket_rebaser_body_exited(body: Node3D) -> void:
	if body.is_in_group("rocket"):
		rocket_based = false
		rocket = null

func dock_satellite_on_rocket(name: String) -> void:
	if rocket != null:
		rocket.setup_sattelite(name)

func pleaserefuel() -> void:
	if rocket != null:
		rocket.fuel = 5000 #HERE TO CHANGE FUEL DONT FORGET IT LATER
		rocket.fuel_guage.value = 5000
