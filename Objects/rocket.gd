extends RigidBody3D

var canmove: bool = true
var has_player: bool = false

@onready var flight_controller = $FlightController
@onready var landing_gear_controller = $LandingGearController
@onready var satellite_dock_controller = $SatelliteDockController
@onready var damage_controller = $DamageController
@onready var help_ui_controller = $HelpUIController

func _ready() -> void:
	CameraManager.register(self)
	linear_damp = 0
	gravity_scale = 0
	$Control/YouDied.hide()
	$Control/Help.hide()
	flight_controller.setup()
	$Rocket/AnimationPlayer.play("CubeAction_004")
	landing_gear_controller.landing_gear = true
	await $Rocket/AnimationPlayer.animation_finished
	$LandingGearCollision.disabled = false

func _physics_process(_delta: float) -> void:
	if canmove:
		flight_controller.handle_gravity()
		if has_player:
			$Control.show()
			flight_controller.handle_rotation()
			flight_controller.handle_thrust()
			flight_controller.handle_rcs()
			landing_gear_controller.handle_landing_gear()
			flight_controller.update_thrust_visual(_delta)
			if GraphicsSettings.showkeybinds:
				$Help.show()
			else:
				$Help.hide()
		else:
			$Control.hide()
			$Help.hide()
			flight_controller.set_thrust_gradient_bias(0)
	else:
		flight_controller.set_thrust_gradient_bias(0)
		$Control/YouDied.show()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if Input.is_action_just_pressed("R") and !canmove:
			CameraManager.reset()
			get_tree().reload_current_scene()

	if !has_player:
		return

	if event is InputEventKey:
		if Input.is_action_just_pressed("eject"):
			satellite_dock_controller.eject_satellite()
		if Input.is_action_just_pressed("help-open"):
			help_ui_controller.handle_help()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			flight_controller.throttleslider.value += flight_controller.throttleslider.step
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			flight_controller.throttleslider.value -= flight_controller.throttleslider.step

func _on_proximity_entered(body: Node) -> void:
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(self)

func _on_proximity_exited(body: Node) -> void:
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(null)

func can_unmount() -> bool:
	return canmove
