extends RigidBody3D

@export var thrust_force: float = 100.0   # Force applied while thrusting
@export var pitch_torque: float = 1.0           # Nose up/down
@export var yaw_torque: float = 1.0             # Nose left/right
@export var roll_torque: float = 1.0            # Barrel roll
@export var stabilization_strength: float = 2.0 # How aggressively it cancels spin when no input
var landing_gear: bool = false
@export var impact_velocity_threshold: float = 2.0

@onready var thruster = $ThrustCone

const ACTION_PITCH_UP    = "forward"
const ACTION_PITCH_DOWN  = "back"
const ACTION_YAW_LEFT    = "left"
const ACTION_YAW_RIGHT   = "right"
const ACTION_ROLL_LEFT   = "roll_left"
const ACTION_ROLL_RIGHT  = "roll_right"
const ACTION_THRUST      = "thrust"
var canmove: bool = true

var current_bias: float = 0.0

@onready var throttleslider = $Control/VSlider

@export var rcs_force: float = 5.0
const ACTION_RCS_UP    = "rcs_up"
const ACTION_RCS_DOWN  = "rcs_down"
const ACTION_RCS_LEFT  = "rcs_left"
const ACTION_RCS_RIGHT = "rcs_right"
const ACTION_RCS_FORWARD = "rcs_forward"
const ACTION_RCS_BACK    = "rcs_back"


func _ready() -> void:
	linear_damp = 0
	gravity_scale = 0
	$Control/YouDied.hide()
	set_thrust_gradient_bias(throttleslider.value)

func _physics_process(_delta: float) -> void:
	if canmove: 
		_handle_gravity()
		_handle_rotation()
		_handle_thrust()
		_handle_rcs()
		_handle_landing_gear()
		_update_thrust_visual(_delta)
		#print("speed: ", linear_velocity.length(), " | altitude: ", (global_position - source.global_position).length())
		
	else:
		set_thrust_gradient_bias(0)
		$Control/YouDied.show()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if !canmove:
			if Input.is_action_just_pressed("R"):
				get_tree().reload_current_scene()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			throttleslider.value += throttleslider.step
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			throttleslider.value -= throttleslider.step

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

func set_thrust_gradient_bias(value: float):
	var mat = thruster.mesh.surface_get_material(0) as ShaderMaterial
	mat.set_shader_parameter("gradient_bias", value)

func _update_thrust_visual(_delta: float) -> void:
	var target = throttleslider.value if Input.is_action_pressed(ACTION_THRUST) else 0.0
	current_bias = lerp(current_bias, target, _delta * 5.0)
	set_thrust_gradient_bias(current_bias)


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
	
	# debug — remove when done tuning
	if GravityManager.sources.size() > 0:
		var altitude = (global_position - GravityManager.sources[0].global_position).length()
		$Control/Label.text = "Speed: " + str(int(linear_velocity.length())) + "Alt: " + str(int(altitude))



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



func _handle_landing_gear() -> void:
	if Input.is_action_just_pressed("LandingGear") and !$Rocket/AnimationPlayer.is_playing():
		if !landing_gear:
			$Rocket/AnimationPlayer.play("CubeAction_004")
			landing_gear = true
			await $Rocket/AnimationPlayer.animation_finished
			$LandingGearCollision.disabled = false
			
		else:
			$Rocket/AnimationPlayer.play_backwards("CubeAction_004")
			landing_gear = false
			await $Rocket/AnimationPlayer.animation_finished
			$LandingGearCollision.disabled = true


func _handle_thrust() -> void:
	if Input.is_action_pressed(ACTION_THRUST):
		var forward := global_transform.basis.y
		apply_central_force(forward * (thrust_force * throttleslider.value))


func collision_impact(body: Node) -> void:
	if abs(linear_velocity.y) > impact_velocity_threshold or abs(linear_velocity.x) > 5 or abs(linear_velocity.z) > 5:
		$ExplosionParticle.emitting = false
		print("Impact with ", body.name, " at ", linear_velocity.length())
		$ExplosionParticle.emitting = true
		canmove = false
		
