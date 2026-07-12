extends Node
@onready var rocket: RigidBody3D = get_parent()
@onready var thruster = rocket.get_node("ThrustCone")
@onready var fuel_guage = rocket.get_node("Control/FuelGuage")
@onready var throttleslider = rocket.get_node("Control/VSlider")

@export var thrust_force: float = 100.0
@export var pitch_torque: float = 1.0
@export var yaw_torque: float = 1.0
@export var roll_torque: float = 1.0
@export var stabilization_strength: float = 2.0
@export var rcs_force: float = 5.0

const ACTION_PITCH_UP    = "forward"
const ACTION_PITCH_DOWN  = "back"
const ACTION_YAW_LEFT    = "left"
const ACTION_YAW_RIGHT   = "right"
const ACTION_ROLL_LEFT   = "roll_left"
const ACTION_ROLL_RIGHT  = "roll_right"
const ACTION_THRUST      = "thrust"
const ACTION_RCS_UP      = "rcs_up"
const ACTION_RCS_DOWN    = "rcs_down"
const ACTION_RCS_LEFT    = "rcs_left"
const ACTION_RCS_RIGHT   = "rcs_right"
const ACTION_RCS_FORWARD = "rcs_forward"
const ACTION_RCS_BACK    = "rcs_back"

var fuel = 5000
var current_bias: float = 0.0

@onready var RCS_Thrusters_left = [rocket.get_node("RCS-Left/RCS-back"), rocket.get_node("RCS-Left/RCS-Down"), rocket.get_node("RCS-Left/RCS-forward"), rocket.get_node("RCS-Left/RCS-Up"), rocket.get_node("RCS-Left/RCS-left"), rocket.get_node("RCS-Left/RCS-right")]
@onready var RCS_Thrusters_right = [rocket.get_node("RCS-Right/RCS-back"), rocket.get_node("RCS-Right/RCS-Down"), rocket.get_node("RCS-Right/RCS-forward"), rocket.get_node("RCS-Right/RCS-Up"), rocket.get_node("RCS-Right/RCS-left"), rocket.get_node("RCS-Right/RCS-right")]

func setup() -> void:
	fuel_guage.max_value = fuel
	fuel_guage.value = fuel
	set_thrust_gradient_bias(throttleslider.value)
	for i in RCS_Thrusters_left:
		i.hide()
	for i in RCS_Thrusters_right:
		i.hide()

func handle_rcs() -> void:
	var local_force := Vector3.ZERO
	for i in RCS_Thrusters_left:
		i.hide()
	for i in RCS_Thrusters_right:
		i.hide()

	if Input.is_action_pressed(ACTION_RCS_UP):
		RCS_Thrusters_left[2].show()
		RCS_Thrusters_right[2].show()
		local_force.z -= 1.0
	if Input.is_action_pressed(ACTION_RCS_DOWN):
		RCS_Thrusters_left[0].show()
		RCS_Thrusters_right[0].show()
		local_force.z += 1.0
	if Input.is_action_pressed(ACTION_RCS_LEFT):
		RCS_Thrusters_left[5].show()
		RCS_Thrusters_right[5].show()
		local_force.x -= 1.0
	if Input.is_action_pressed(ACTION_RCS_RIGHT):
		RCS_Thrusters_left[4].show()
		RCS_Thrusters_right[4].show()
		local_force.x += 1.0
	if Input.is_action_pressed(ACTION_RCS_FORWARD):
		RCS_Thrusters_left[1].show()
		RCS_Thrusters_right[1].show()
		local_force.y += 1.0
	if Input.is_action_pressed(ACTION_RCS_BACK):
		RCS_Thrusters_left[3].show()
		RCS_Thrusters_right[3].show()
		local_force.y -= 1.0

	if local_force != Vector3.ZERO:
		rocket.apply_central_force(rocket.global_transform.basis * local_force * rcs_force)
		if !rocket.get_node("Rcs_audio").playing:
			rocket.get_node("Rcs_audio").play()
	else:
		rocket.get_node("Rcs_audio").stop()

func set_thrust_gradient_bias(value: float) -> void:
	var mat = thruster.mesh.surface_get_material(0) as ShaderMaterial
	mat.set_shader_parameter("gradient_bias", value)

func update_thrust_visual(_delta: float) -> void:
	if fuel > 0:
		var target = throttleslider.value if Input.is_action_pressed(ACTION_THRUST) else 0.0
		current_bias = lerp(current_bias, target, _delta * 5.0)
		set_thrust_gradient_bias(current_bias)
	else:
		set_thrust_gradient_bias(0)

func handle_gravity() -> void:
	for source in GravityManager.get_active_sources(rocket.global_position):
		var to_source: Vector3 = source.global_position - rocket.global_position
		var distance: float = to_source.length()
		if distance < 0.01:
			continue
		var direction: Vector3 = to_source.normalized()
		var strength: float
		if source.use_inverse_square:
			strength = source.gravity_strength * source.mass / (distance * distance)
		else:
			strength = source.gravity_strength
		rocket.apply_central_force(direction * strength * rocket.mass)

	# debug — remove when done tuning
	if GravityManager.sources.size() > 0:
		var altitude = (rocket.global_position - GravityManager.sources[0].global_position).length()
		rocket.get_node("Control/Label").text = "Speed: " + str(int(rocket.linear_velocity.length())) + "Alt: " + str(int(altitude) - 70)

func handle_rotation() -> void:
	var pitch := 0.0
	var yaw := 0.0
	var roll := 0.0

	if !Input.is_key_pressed(KEY_SHIFT):
		if Input.is_action_pressed(ACTION_PITCH_UP):
			pitch -= 1.0
		if Input.is_action_pressed(ACTION_PITCH_DOWN):
			pitch += 1.0
		if Input.is_action_pressed(ACTION_YAW_LEFT):
			roll += 1.0
		if Input.is_action_pressed(ACTION_YAW_RIGHT):
			roll -= 1.0
		if Input.is_action_pressed(ACTION_ROLL_LEFT):
			yaw += 1.0
		if Input.is_action_pressed(ACTION_ROLL_RIGHT):
			yaw -= 1.0

	var local_torque := Vector3(
		pitch * pitch_torque,
		yaw * yaw_torque,
		roll * roll_torque
	)

	var local_angular_velocity: Vector3 = rocket.global_transform.basis.inverse() * rocket.angular_velocity
	if pitch == 0.0:
		local_torque.x -= local_angular_velocity.x * stabilization_strength
	if yaw == 0.0:
		local_torque.y -= local_angular_velocity.y * stabilization_strength
	if roll == 0.0:
		local_torque.z -= local_angular_velocity.z * stabilization_strength

	rocket.apply_torque(rocket.global_transform.basis * local_torque)

func handle_thrust() -> void:
	if linear_velocity_over_limit():
		rocket.get_node("Control/Warning").show()
	else:
		rocket.get_node("Control/Warning").hide()
		if Input.is_action_pressed(ACTION_THRUST) and fuel > 0:
			var forward := rocket.global_transform.basis.y
			rocket.apply_central_force(forward * (thrust_force * throttleslider.value))
			fuel = max(0, fuel - throttleslider.value)
			fuel_guage.value = fuel

func linear_velocity_over_limit() -> bool:
	return rocket.linear_velocity.length() > 550
