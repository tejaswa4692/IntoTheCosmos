extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var interact_distance: float = 3.0
@export var gravity_align_speed: float = 5.0  
@onready var fp_camera = $Head/Camera3D
var observatory = preload("res://Objects/observatory.tscn")
@onready var raycast = $Head/HeadCast
@onready var animation_tree: AnimationTree = $AnimationTree
var run_val = 0
var walk_val = 0
var is_running: int = 1


var mounted_target = null      # Rocket or Satellite
var mount_source = null        # Rocket or Observatory

var gravity_direction: Vector3 = Vector3.DOWN
var gravity_strength: float = 0.0
var gravity_force: Vector3 = Vector3.ZERO
var is_mounted: bool = false
var nearest_rocket = null

var pitch: float = 0.0

@onready var head = $Head
@onready var camera = $Head/Camera3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not is_mounted:
		# yaw: rotate the whole body around its local up
		rotate(up_direction, -event.relative.x * mouse_sensitivity)
		# pitch: tilt head up/down, clamped
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		head.rotation.x = pitch
	
	if event is InputEventKey:
		if Input.is_action_just_pressed("interact") and not Input.is_key_pressed(KEY_SHIFT):
			if is_mounted:
				if mounted_target and !mounted_target.can_unmount():
					return
				_unmount()
			elif nearest_rocket != null:
				_mount(nearest_rocket)


func _physics_process(delta: float) -> void:
	if is_mounted:
		return
	_update_gravity(delta)
	_handle_movement(delta)
	update_tree()
	if Input.is_action_just_pressed("Place") and raycast.is_colliding():
		print("placing")
		buildobservatory()

func _update_gravity(delta: float) -> void:
	var active_sources := GravityManager.get_active_sources(global_position)
	if active_sources.is_empty():
		gravity_direction = Vector3.DOWN
		gravity_strength = 0.0
		gravity_force = Vector3.ZERO
		up_direction = Vector3.UP
		return
	gravity_force = Vector3.ZERO
	var strongest_source = null
	var strongest_force = 0.0
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
	if strongest_source:
		var target_up = -(strongest_source.global_position - global_position).normalized()
		up_direction = target_up
		var current_up = global_transform.basis.y
		if current_up.dot(target_up) < 0.9999:
			var axis = current_up.cross(target_up)
			if axis.length() > 0.001:
				var angle = current_up.angle_to(target_up)
				var smooth = angle * min(gravity_align_speed * delta, 1.0)
				global_rotate(axis.normalized(), smooth)

func update_tree() -> void:
	animation_tree["parameters/WalkMix/blend_amount"] = walk_val
	animation_tree["parameters/RunMix/blend_amount"] = run_val
	animation_tree["parameters/WalkOrRun/blend_amount"] = is_running

func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += gravity_force * delta
	else:
		var floor_normal = get_floor_normal()
		var into_floor = velocity.dot(-floor_normal)
		if into_floor < 0:
			velocity -= -floor_normal * into_floor

	# jumping — pushes away from gravity direction
	if Input.is_action_just_pressed("jump") and $RayCast3D.is_colliding():
		velocity += -gravity_direction * jump_velocity

	# WASD movement relative to camera facing, projected onto planet surface
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("forward"):
		run_val = lerpf(run_val, 1.0, 0.1)
		input_dir.y -= 1
	if Input.is_action_pressed("back"):
		input_dir.y += 1
	if Input.is_action_pressed("left"):
		input_dir.x -= 1
	if Input.is_action_pressed("right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	if input_dir.length() > 0.01:
		var cam_forward = -head.global_transform.basis.z
		var surface_forward = (cam_forward - gravity_direction * cam_forward.dot(gravity_direction)).normalized()
		var surface_right = surface_forward.cross(-gravity_direction).normalized()
		var move_dir = (surface_forward * -input_dir.y + surface_right * input_dir.x).normalized()
		var target_velocity = move_dir * move_speed

		var vertical = gravity_direction * velocity.dot(gravity_direction)
		var horizontal = velocity - vertical

		var accel = 20.0 if is_on_floor() else 8.0
		horizontal = horizontal.move_toward(target_velocity, accel * delta)

		velocity = horizontal + vertical
	else:
		run_val = lerpf(run_val, 0, 0.1)
		var vertical = velocity.dot(gravity_direction)
		var horizontal = velocity - gravity_direction * vertical
		var friction = 25.0 if is_on_floor() else 3.0
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)
		velocity = horizontal + gravity_direction * vertical

	move_and_slide()

func _mount(target) -> void:
	mount_source = target
	if target.has_method("get_mount_target"):
		target = target.get_mount_target()
	if target == null:
		return
	# clear previous mounted target if there was one
	if mounted_target != null and is_instance_valid(mounted_target):
		mounted_target.has_player = false
	is_mounted = true
	mounted_target = target
	visible = false
	$CollisionShape3D.disabled = true
	set_physics_process(false)
	fp_camera.current = false
	get_tree().get_first_node_in_group("camera_rig").activate()
	CameraManager.override_target = target
	target.has_player = true

func _unmount() -> void:
	is_mounted = false
	visible = true
	$CollisionShape3D.disabled = false
	set_physics_process(true)
	# Return the player to wherever they mounted from
	if mount_source:
		if mount_source.has_node("PlayerExitMarker"):
			global_position = mount_source.get_node("PlayerExitMarker").global_position
		else:
			global_position = mount_source.global_position + mount_source.global_transform.basis.x * 3.0
	# Release control of the mounted object
	if mounted_target:
		mounted_target.has_player = false
	mounted_target = null
	mount_source = null
	velocity = Vector3.ZERO
	pitch = 0.0
	CameraManager.override_target = null
	CameraManager.set_current(self)
	get_tree().get_first_node_in_group("camera_rig").deactivate()
	fp_camera.current = true

func set_nearest_rocket(rocket) -> void:
	nearest_rocket = rocket


func buildobservatory() -> void:
	var observatoryinstance = observatory.instantiate()
	get_tree().root.add_child(observatoryinstance)
	var point = raycast.get_collision_point()
	var normal = raycast.get_collision_normal()
	observatoryinstance.global_position = point
	observatoryinstance.global_basis = Basis.looking_at(normal)
	observatoryinstance.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90))
