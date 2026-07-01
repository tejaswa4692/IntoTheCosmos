extends RigidBody3D

@export var rcs_force: float = 1.0
@export var thrust_force: float = 10.0

@onready var thruster = $ThrustCone
@onready var throttleslider = $Control/VSlider

@export var satellite_name := "Explorer I"

const ACTION_THRUST       = "thrust"
const ACTION_RCS_UP       = "rcs_up"
const ACTION_RCS_DOWN     = "rcs_down"
const ACTION_RCS_LEFT     = "rcs_left"
const ACTION_RCS_RIGHT    = "rcs_right"
const ACTION_RCS_FORWARD  = "rcs_forward"
const ACTION_RCS_BACK     = "rcs_back"

var has_player = false

@export var pitch_torque: float = 1.0
@export var yaw_torque: float = 1.0
@export var roll_torque: float = 1.0
@export var stabilization_strength: float = 2.0

const ACTION_PITCH_UP   = "forward"
const ACTION_PITCH_DOWN = "back"
const ACTION_YAW_LEFT   = "left"
const ACTION_YAW_RIGHT  = "right"
const ACTION_ROLL_LEFT  = "roll_left"
const ACTION_ROLL_RIGHT = "roll_right"



var current_bias: float = 0.0

func _ready():
	SatelliteManager.satellites.append(self)
	CameraManager.register(self)
	linear_damp = 0
	angular_damp = 0
	gravity_scale = 0
	set_thrust_gradient_bias(0)  # <-- hide cone on start

func _input(event: InputEvent) -> void:
	if CameraManager.get_current() != self:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			throttleslider.value += throttleslider.step
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			throttleslider.value -= throttleslider.step


func _physics_process(delta: float) -> void:
	_handle_gravity()
	if CameraManager.get_current() == self:
		_handle_input(delta)
		$Control.show()
	else:
		set_thrust_gradient_bias(0)
		$Control.hide()

func _handle_gravity() -> void:
	for source in GravityManager.sources:
		var to_source: Vector3 = source.global_position - global_position
		var distance: float = to_source.length()
		if distance < 0.01:
			continue
		var direction: Vector3 = to_source.normalized()
		var strength: float
		if source.use_inverse_square:
			strength = source.gravity_strength * source.mass / (distance * distance)
		else:
			strength = source.gravity_strength
		apply_central_force(direction * strength * mass)

func _handle_input(delta: float) -> void:
	_handle_rcs()
	_handle_thrust()
	_handle_rotation()
	_update_thrust_visual(delta)

func _handle_rcs() -> void:
	var local_force := Vector3.ZERO

	if Input.is_action_pressed(ACTION_RCS_UP):
		local_force.z -= 1.0
	if Input.is_action_pressed(ACTION_RCS_DOWN):
		local_force.z += 1.0
	if Input.is_action_pressed(ACTION_RCS_LEFT):
		local_force.x -= 1.0
	if Input.is_action_pressed(ACTION_RCS_RIGHT):
		local_force.x += 1.0
	if Input.is_action_pressed(ACTION_RCS_FORWARD):
		local_force.y += 1.0
	if Input.is_action_pressed(ACTION_RCS_BACK):
		local_force.y -= 1.0

	if local_force != Vector3.ZERO:
		apply_central_force(global_transform.basis * local_force * rcs_force)

func _handle_thrust() -> void:
	if Input.is_action_pressed(ACTION_THRUST):
		var forward := global_transform.basis.y
		var force = forward * (thrust_force * throttleslider.value)
		apply_central_force(force)

func set_thrust_gradient_bias(value: float) -> void:
	var mat = thruster.mesh.surface_get_material(0) as ShaderMaterial
	mat.set_shader_parameter("gradient_bias", value)

func _update_thrust_visual(delta: float) -> void:
	var target = throttleslider.value if Input.is_action_pressed(ACTION_THRUST) else 0.0
	current_bias = lerp(current_bias, target, delta * 5.0)
	set_thrust_gradient_bias(current_bias)


func _handle_rotation() -> void:
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
	
	var local_angular_velocity: Vector3 = global_transform.basis.inverse() * angular_velocity
	if pitch == 0.0:
		local_torque.x -= local_angular_velocity.x * stabilization_strength
	if yaw == 0.0:
		local_torque.y -= local_angular_velocity.y * stabilization_strength
	if roll == 0.0:
		local_torque.z -= local_angular_velocity.z * stabilization_strength
		
	apply_torque(global_transform.basis * local_torque)


func can_unmount() -> bool:
	return true
