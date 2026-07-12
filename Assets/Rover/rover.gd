extends VehicleBody3D

@export var engine_power: float = 30.0
@export var max_steer_angle: float = 0.6
@export var steer_speed: float = 1.5
@export var gravity_align_speed: float = 5.0

# Duplicate seated-player mesh, shown while mounted, hidden otherwise.
@onready var driver_mesh: Node3D = $Node3D
@onready var MudguardFrontRight: MeshInstance3D = $Mudguard
@onready var MudguardFrontLeft: MeshInstance3D = $MudguardLeft

@onready var front_left_wheel: VehicleWheel3D = $FrontLeftWheel

var canmove: bool = true

var has_player: bool = false:
	set(value):
		has_player = value
		if driver_mesh:
			driver_mesh.visible = value
		if not value:
			engine_force = 0.0
			steering = 0.0
			brake = 1.0

var gravity_direction: Vector3 = Vector3.DOWN
var gravity_strength: float = 0.0
var gravity_force: Vector3 = Vector3.ZERO
var _strongest_gravity_source = null


func _ready() -> void:
	gravity_scale = 0.0
	if driver_mesh:
		driver_mesh.hide()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_update_gravity(state)
	_apply_gravity_force(state)
	_align_to_gravity(state)


func _physics_process(delta: float) -> void:
	if not canmove:
		engine_force = 0.0
		brake = 1.0
		steering = 0.0
		return
	if has_player:
		_handle_driving(delta)
	else:
		engine_force = 0.0
		brake = 1.0
		steering = 0.0


# FIXED: Visual updates like mudguards MUST happen here to prevent jittering.
func _process(_delta: float) -> void:
	if front_left_wheel and MudguardFrontRight:
		handle_mudguards()


func _handle_driving(delta: float) -> void:
	brake = 0.0
	var throttle := 0.0
	if Input.is_action_pressed("forward"):
		throttle += 1.0
	if Input.is_action_pressed("back"):
		throttle -= 1.0
	engine_force = throttle * engine_power
	if Input.is_action_pressed("jump"):
		brake = 5
	var steer_input := 0.0
	if Input.is_action_pressed("left"):
		steer_input += 1.0
	if Input.is_action_pressed("right"):
		steer_input -= 1.0
	
	var steer_target = steer_input * max_steer_angle
	steering = move_toward(steering, steer_target, steer_speed * delta)


# FIXED: Uses local basis vectors so it works perfectly even when gravity changes your orientation.
func handle_mudguards() -> void:
	var wheel_steering_angle = front_left_wheel.steering
	MudguardFrontRight.transform.basis = Basis().rotated(Vector3.UP, wheel_steering_angle)
	MudguardFrontLeft.transform.basis = Basis().rotated(Vector3.UP, wheel_steering_angle)


func _update_gravity(state: PhysicsDirectBodyState3D) -> void:
	var active_sources := GravityManager.get_active_sources(global_position)
	if active_sources.is_empty():
		gravity_direction = Vector3.DOWN
		gravity_strength = 0.0
		gravity_force = Vector3.ZERO
		_strongest_gravity_source = null
		return

	gravity_force = Vector3.ZERO
	var strongest_source = null
	var strongest_force := 0.0

	for source in active_sources:
		var to_source = source.global_position - global_position
		var distance = to_source.length()
		if distance < 0.01:
			continue
		var direction = to_source.normalized()
		var strength: float
		if source.use_inverse_square:
			strength = source.gravity_strength * source.mass / (distance * distance)
		else:
			strength = source.gravity_strength
		var force = direction * strength
		gravity_force += force
		if strength > strongest_force:
			strongest_force = strength
			strongest_source = source

	if gravity_force.length() > 0.001:
		gravity_direction = gravity_force.normalized()
		gravity_strength = gravity_force.length()

	_strongest_gravity_source = strongest_source


func _apply_gravity_force(state: PhysicsDirectBodyState3D) -> void:
	state.apply_central_force(gravity_force * mass * 2)


func _align_to_gravity(state: PhysicsDirectBodyState3D) -> void:
	if _strongest_gravity_source == null or not is_instance_valid(_strongest_gravity_source):
		return

	var target_up = -(_strongest_gravity_source.global_position - global_position).normalized()
	var current_up = state.transform.basis.y

	if current_up.dot(target_up) >= 0.9999:
		return

	var axis = current_up.cross(target_up)
	if axis.length() < 0.001:
		return

	var angle = current_up.angle_to(target_up)
	var smooth = angle * min(gravity_align_speed * state.step, 1.0)

	var new_basis = state.transform.basis.rotated(axis.normalized(), smooth)
	new_basis = new_basis.orthonormalized()
	state.transform = Transform3D(new_basis, state.transform.origin)


func can_unmount() -> bool:
	return canmove


func _on_proximity_entered(body: Node) -> void:
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(self)


func _on_proximity_exited(body: Node) -> void:
	if body.has_method("set_nearest_rocket"):
		body.set_nearest_rocket(null)
