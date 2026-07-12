extends CharacterBody3D

@export var move_speed: float = 2.5
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var interact_distance: float = 3.0
@export var gravity_align_speed: float = 5.0  
@onready var fp_camera = $Head/Camera3D
@onready var raycast = $HeadCast
@onready var animation_tree: AnimationTree = $AnimationTree
var run_val = 0
var jump_val = 0
var ui_open : bool

@onready var satellite_ui: Control = $SatteliteUI
@onready var satellite_item_list: ItemList = $SatteliteUI/ItemList

var displayed_satellites: Array = []
var current_observatory = null   # the observatory we're currently picking a satellite for

var mounted_target = null      # Rocket or Satellite
var mount_source = null        # Rocket or Observatory
var settings_open: bool = false
var gravity_direction: Vector3 = Vector3.DOWN
var gravity_strength: float = 0.0
var gravity_force: Vector3 = Vector3.ZERO
var is_mounted: bool = false
var nearest_rocket = null

var pitch: float = 0.0

@onready var head = $Head
@onready var camera = $Head/Camera3D

const PLACEABLE_SCENES := {
	"observatory": preload("res://Objects/observatory.tscn"),
	"rover": preload("res://Assets/Rover/rover.tscn")
}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not is_mounted:
		if !settings_open:
			# yaw: rotate the whole body around its local up
			rotate(up_direction, -event.relative.x * mouse_sensitivity)
			# pitch: tilt head up/down, clamped
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
			head.rotation.x = pitch

	# Minecraft-style hotbar scrolling. Blocked while any menu is open
	# so scrolling through the world doesn't fight with menu scrolling.
	if event is InputEventMouseButton and event.pressed and not is_mounted and !settings_open and !ui_open:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			InventoryGlobal.select_next()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			InventoryGlobal.select_prev()

	if event is InputEventKey:
		if Input.is_action_just_pressed("interact") and not Input.is_key_pressed(KEY_SHIFT):
			if is_mounted:
				if mounted_target and !mounted_target.can_unmount():
					return
				_unmount()
			elif nearest_rocket != null:
				_mount(nearest_rocket)
		if Input.is_action_just_pressed("ui_cancel") and ui_open:
			satellite_ui.visible = false
			
func _physics_process(delta: float) -> void:
	if is_mounted:
		return
	_update_gravity(delta)
	_handle_movement(delta)
	update_tree()
	if Input.is_action_just_pressed("Place") and (satellite_ui.visible == false) and !settings_open:
		try_place_selected_item()
	
	
	if GraphicsSettings.showkeybinds:  #Please fix this later tis is just embrassing 
		$Help.show()
	else:
		$Help.hide()

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
	animation_tree["parameters/RunMix/blend_amount"] = run_val
	animation_tree["parameters/JumpVal/blend_amount"] = jump_val

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
	
	
	if $RayCast3D.is_colliding():
		jump_val = lerpf(jump_val, 0.0, 0.2)
	else:
		jump_val = lerpf(jump_val, 1.0, 0.2)
	
	
	# WASD movement relative to camera facing, projected onto planet surface
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
	if target.is_in_group("observatory"):
		if !satellite_ui.visible:
			_show_satellite_ui(target)
		else:
			hide_satellite_ui()
		return  # observatories never auto-mount; UI decides what happens next
	_do_mount(target)

func _do_mount(target) -> void:
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
	if GraphicsSettings.showkeybinds:
		$Help.hide()

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
	if GraphicsSettings.showkeybinds:
		$Help.show()


func set_nearest_rocket(rocket) -> void:
	nearest_rocket = rocket

func _show_satellite_ui(selected_observatory) -> void:
	ui_open = true
	InventoryGlobal.isUIopen = true
	current_observatory = selected_observatory
	displayed_satellites.clear()
	satellite_item_list.clear()
	for sat in SatelliteManager.satellites:
		if !is_instance_valid(sat):
			continue
		displayed_satellites.append(sat)
		var label = sat.satellite_name
		if sat.assigned_observatory != null and sat.assigned_observatory != selected_observatory:
			label += " (Assigned)"
		satellite_item_list.add_item(label)
	satellite_ui.show()
	$SatteliteUI/MainMenu.show()
	satellite_item_list.hide()
	$SatteliteUI/UpgradesList.hide()
	$SatteliteUI/SatelliteText.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if selected_observatory.satellite_target != null:
		$SatteliteUI/MainMenu.set_item_text(0, "Control Satellite")
	elif selected_observatory.satellite_target == null:
		$SatteliteUI/MainMenu.set_item_text(0, "Satelite Manager")


func hide_satellite_ui() -> void:
	ui_open = false
	InventoryGlobal.isUIopen = false
	satellite_ui.hide()
	$SatteliteUI/MainMenu.hide()
	satellite_item_list.hide()
	$SatteliteUI/UpgradesList.hide()
	$SatteliteUI/SatelliteText.hide()
	current_observatory = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_item_list_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	if current_observatory == null:
		return
	if index < 0 or index >= displayed_satellites.size():
		return
	var sat = displayed_satellites[index]
	if sat.assigned_observatory != null and sat.assigned_observatory != current_observatory:
		return
	current_observatory.assign_satellite(sat)
	hide_satellite_ui()

func try_place_selected_item() -> void:
	var selected := InventoryGlobal.get_selected_item()
	if selected == "" or not PLACEABLE_SCENES.has(selected):
		return
	if not raycast.is_colliding():
		return
	var collider = raycast.get_collider()
	if not collider.is_in_group("planet"):
		return
	var planet = collider.get_parent()

	# Per-item placement rules go here. Add more `if selected == ...`
	# branches as new placeable rules are needed.
	if selected == "observatory" and planet.has_observatory:
		var instance = PLACEABLE_SCENES[selected].instantiate()
		get_tree().root.add_child(instance)
		var point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		instance.global_position = point
		instance.global_basis = Basis.looking_at(normal)
		instance.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90))

	if selected == "observatory":
		planet.change_observatory_status()

	if selected == "rover":
		var instance = PLACEABLE_SCENES[selected].instantiate()
		get_tree().root.add_child(instance)
		var point = raycast.get_collision_point()
		var normal = raycast.get_collision_normal()
		instance.global_position = point
		instance.global_basis = Basis.looking_at(normal)
		instance.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90))

	InventoryGlobal.remove_item(selected, 1)


func _on_main_menu_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	print(index)
	match index:
		0:
			if current_observatory.satellite_target != null:
				var sat = current_observatory.get_mount_target()
				hide_satellite_ui()
				_do_mount(sat)
			else:
				$SatteliteUI/MainMenu.hide()
				satellite_item_list.show()
				$SatteliteUI/UpgradesList.hide()
		1:
			$SatteliteUI/MainMenu.hide()
			satellite_item_list.hide()
			$SatteliteUI/UpgradesList.show()
		2:
			current_observatory.pleaserefuel()
			hide_satellite_ui()
		3:
			$SatteliteUI/SatelliteText.show()
		4:
			current_observatory.spawn_vehicle_rover()

func _on_done_button_pressed() -> void:
	if current_observatory != null and current_observatory.rocket != null:
		current_observatory.dock_satellite_on_rocket($SatteliteUI/SatelliteText/LineEdit.text)
		hide_satellite_ui()
	else:
		hide_satellite_ui()
