extends RigidBody3D

@export var thrust_force: float = 20.0     # Force applied while thrusting
@export var pitch_torque: float = 1.0           # Nose up/down
@export var yaw_torque: float = 1.0             # Nose left/right
@export var roll_torque: float = 1.0            # Barrel roll
@export var stabilization_strength: float = 0.8 # How aggressively it cancels spin when no input
var landing_gear: bool = false

const ACTION_PITCH_UP    = "forward"
const ACTION_PITCH_DOWN  = "back"
const ACTION_YAW_LEFT    = "left"
const ACTION_YAW_RIGHT   = "right"
const ACTION_ROLL_LEFT   = "roll_left"
const ACTION_ROLL_RIGHT  = "roll_right"
const ACTION_THRUST      = "thrust"


func _physics_process(_delta: float) -> void:
	_handle_rotation()
	_handle_thrust()
	_handle_landing_gear()


func _handle_rotation() -> void:
	var pitch := 0.0
	var yaw := 0.0
	var roll := 0.0

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
		$GPUParticles3D.emitting = true
		var forward := global_transform.basis.y
		apply_central_force(forward * thrust_force)
	else:
		$GPUParticles3D.emitting = false
