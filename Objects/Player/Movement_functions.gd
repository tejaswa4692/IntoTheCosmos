extends Node
@onready var player: CharacterBody3D = get_parent()

var gravity_direction: Vector3 = Vector3.DOWN
var gravity_strength: float = 0.0
var gravity_force: Vector3 = Vector3.ZERO
var run_val = 0.0
var jump_val = 0.0

func update_gravity(delta: float) -> void:
	var active_sources := GravityManager.get_active_sources(player.global_position)
	if active_sources.is_empty():
		gravity_direction = Vector3.DOWN
		gravity_strength = 0.0
		gravity_force = Vector3.ZERO
		player.up_direction = Vector3.UP
		return
	gravity_force = Vector3.ZERO
	var strongest_source = null
	var strongest_force = 0.0
	for source in active_sources:
		var to_source = source.global_position - player.global_position
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
		var target_up = -(strongest_source.global_position - player.global_position).normalized()
		player.up_direction = target_up
		var current_up = player.global_transform.basis.y
		if current_up.dot(target_up) < 0.9999:
			var axis = current_up.cross(target_up)
			if axis.length() > 0.001:
				var angle = current_up.angle_to(target_up)
				var smooth = angle * min(player.gravity_align_speed * delta, 1.0)
				player.global_rotate(axis.normalized(), smooth)

func handle_movement(delta: float, head: Node3D) -> void:
	if not player.is_on_floor():
		player.velocity += gravity_force * delta
	else:
		var floor_normal = player.get_floor_normal()
		var into_floor = player.velocity.dot(-floor_normal)
		if into_floor < 0:
			player.velocity -= -floor_normal * into_floor
	if Input.is_action_just_pressed("jump") and player.get_node("RayCast3D").is_colliding():
		player.velocity += -gravity_direction * player.jump_velocity
	if player.get_node("RayCast3D").is_colliding():
		jump_val = lerpf(jump_val, 0.0, 0.2)
	else:
		jump_val = lerpf(jump_val, 1.0, 0.2)
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("forward"):
		run_val = lerpf(run_val, 1.6, 0.1)
		input_dir.y -= 1
	if Input.is_action_pressed("back"):
		run_val = lerpf(run_val, -1.0, 0.1)
		input_dir.y += 1
	if Input.is_action_pressed("left"):
		run_val = lerpf(run_val, 0.7, 0.1)
		input_dir.x -= 1
	if Input.is_action_pressed("right"):
		run_val = lerpf(run_val, 0.7, 0.1)
		input_dir.x += 1
	input_dir = input_dir.normalized()
	if input_dir.length() > 0.01:
		var cam_forward = -head.global_transform.basis.z
		var surface_forward = (cam_forward - gravity_direction * cam_forward.dot(gravity_direction)).normalized()
		var surface_right = surface_forward.cross(-gravity_direction).normalized()
		var move_dir = (surface_forward * -input_dir.y + surface_right * input_dir.x).normalized()
		var target_velocity = move_dir * player.move_speed
		var vertical = gravity_direction * player.velocity.dot(gravity_direction)
		var horizontal = player.velocity - vertical
		var accel = 20.0 if player.is_on_floor() else 8.0
		horizontal = horizontal.move_toward(target_velocity, accel * delta)
		player.velocity = horizontal + vertical
	else:
		run_val = lerpf(run_val, 0, 0.1)
		var vertical = player.velocity.dot(gravity_direction)
		var horizontal = player.velocity - gravity_direction * vertical
		var friction = 25.0 if player.is_on_floor() else 3.0
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * delta)
		player.velocity = horizontal + gravity_direction * vertical
	player.move_and_slide()

func update_tree(animation_tree: AnimationTree) -> void:
	animation_tree["parameters/RunMix/blend_amount"] = run_val
	animation_tree["parameters/JumpVal/blend_amount"] = jump_val
