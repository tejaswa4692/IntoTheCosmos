extends Node3D

var rocket_docking: bool = false
var rocket_docked: bool = false
var docking_in_progress: bool = false

var rocket: RigidBody3D = null

@export var dock_speed: float = 1.0
@export var dock_distance_threshold: float = 0.02

#FIX THE R BUG WHERE ITS STILL FROZEN WHEN R IS PRESSED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dock") and rocket_docking and rocket != null:
		if rocket_docked:
			# Undock
			rocket.freeze = false
			rocket_docked = false
		elif docking_in_progress:
			# Cancel mid-dock
			docking_in_progress = false
			rocket.freeze = false
		else:
			# Begin docking
			rocket.freeze = true
			docking_in_progress = true


func _physics_process(delta: float) -> void:
	if docking_in_progress and rocket != null:
		# Smoothly move to docking port
		rocket.global_position = rocket.global_position.lerp(
			$DockingPort.global_position,
			dock_speed * delta
		)

		# Smoothly rotate to docking port
		rocket.global_basis = rocket.global_basis.slerp(
			$DockingPort.global_basis,
			dock_speed * delta
		)

		# Finish docking
		if rocket.global_position.distance_to($DockingPort.global_position) <= dock_distance_threshold:
			rocket.global_transform = $DockingPort.global_transform
			docking_in_progress = false
			rocket_docked = true


func _on_docking_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("rocket"):
		rocket_docking = true
		rocket = body
		process_mode = Node.PROCESS_MODE_INHERIT

func _on_docking_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("rocket"):
		# Don't cancel if we're actively docking/docked - the rocket
		# leaving the trigger area is expected as it moves to the port
		if docking_in_progress or rocket_docked:
			return
		rocket_docking = false
		rocket = null
		process_mode = Node.PROCESS_MODE_DISABLED
