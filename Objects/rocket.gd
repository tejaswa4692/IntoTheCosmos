extends RigidBody3D

@export var thrust_force: float = 100.0   # Force applied while thrusting
@export var pitch_torque: float = 1.0           # Nose up/down
@export var yaw_torque: float = 1.0             # Nose left/right
@export var roll_torque: float = 1.0            # Barrel roll
@export var stabilization_strength: float = 2.0 # How aggressively it cancels spin when no input
var landing_gear: bool = false
@export var impact_velocity_threshold: float = 2.0

@onready var thruster = $ThrustCone

var satellite_scene = preload("res://Objects/sattelite.tscn")
var satellite: RigidBody3D

const ACTION_PITCH_UP    = "forward"
const ACTION_PITCH_DOWN  = "back"
const ACTION_YAW_LEFT    = "left"
const ACTION_YAW_RIGHT   = "right"
const ACTION_ROLL_LEFT   = "roll_left"
const ACTION_ROLL_RIGHT  = "roll_right"
const ACTION_THRUST      = "thrust"
var canmove: bool = true

var has_player: bool = false
var current_bias: float = 0.0

@onready var RCS_Thrusters_left = [$"RCS-Left/RCS-back", $"RCS-Left/RCS-Down", $"RCS-Left/RCS-forward", $"RCS-Left/RCS-Up", $"RCS-Left/RCS-left", $"RCS-Left/RCS-right"]
@onready var RCS_Thrusters_right = [$"RCS-Right/RCS-back", $"RCS-Right/RCS-Down", $"RCS-Right/RCS-forward", $"RCS-Right/RCS-Up", $"RCS-Right/RCS-left", $"RCS-Right/RCS-right"]

@onready var throttleslider = $Control/VSlider

@export var rcs_force: float = 5.0
const ACTION_RCS_UP    = "rcs_up"
const ACTION_RCS_DOWN  = "rcs_down"
const ACTION_RCS_LEFT  = "rcs_left"
const ACTION_RCS_RIGHT = "rcs_right"
const ACTION_RCS_FORWARD = "rcs_forward"
const ACTION_RCS_BACK    = "rcs_back"

var curent_help = 0

func _ready() -> void:
	CameraManager.register(self)
	linear_damp = 0
	gravity_scale = 0
	$Control/YouDied.hide()
	set_thrust_gradient_bias(throttleslider.value)
	setup_sattelite()
	$Control/Help.hide()
	for i in RCS_Thrusters_left:
		i.hide()
	for i in RCS_Thrusters_right:
		i.hide()

func _physics_process(_delta: float) -> void:
	if canmove:
		_handle_gravity()
		if has_player:
			$Control.show()
			_handle_rotation()
			_handle_thrust()
			_handle_rcs()
			_handle_landing_gear()
			_update_thrust_visual(_delta)
		else:
			$Control.hide()
			set_thrust_gradient_bias(0)
	else:
		set_thrust_gradient_bias(0)
		$Control/YouDied.show()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if !canmove:
			if Input.is_action_just_pressed("R"):
				CameraManager.reset()
				get_tree().reload_current_scene()
			return

	if !has_player:
		return

	if event is InputEventKey:
		if Input.is_action_just_pressed("eject"):
			eject_satellite()
		if Input.is_action_just_pressed("help-open"):
			handle_help()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			throttleslider.value += throttleslider.step
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			throttleslider.value -= throttleslider.step


func _handle_rcs() -> void:
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
		apply_central_force(global_transform.basis * local_force * rcs_force)
		if !$Rcs_audio.playing:
			$Rcs_audio.play()
	else:
		$Rcs_audio.stop()

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

func setup_sattelite():
	var sattelite_instance = satellite_scene.instantiate()
	sattelite_instance.position = $Marker3D.position
	sattelite_instance.freeze = true
	add_child(sattelite_instance)
	satellite = sattelite_instance

func eject_satellite():
	if satellite == null or !satellite.freeze:
		return
	var world_transform = satellite.global_transform
	remove_child(satellite)
	get_parent().add_child(satellite)
	satellite.global_transform = world_transform
	satellite.freeze = false
	satellite.linear_velocity = linear_velocity
	satellite.angular_velocity = angular_velocity


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
		canmove = false
		has_player = false
		$Explosion.explode()
		await get_tree().create_timer(0.5).timeout
		$Explosion3.explode()
		await get_tree().create_timer(0.5).timeout
		$Explosion4.explode()
		print("Impact with ", body.name, " at ", linear_velocity.length())


func handle_help() -> void:
	if curent_help == 0:
		$Control/Help.visible = true
		$Control/Help/Help1.show()
		curent_help = 1
	elif curent_help == 1:
		$Control/Help/Help2.show()
		$Control/Help/Help1.hide()
		curent_help = 2
	elif curent_help == 2:
		$Control/Help/Help2.hide()
		$Control/Help.hide()
		curent_help = 0


func _on_proximity_entered(body: Node) -> void:
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(self)

func _on_proximity_exited(body: Node) -> void:
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(null)


func can_unmount() -> bool:
	return canmove
