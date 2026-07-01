extends Node

var targets: Array[Node3D] = []
var current_index: int = 0
var override_target: Node3D = null  # used when player mounts rocket

func register(target: Node3D) -> void:
	targets.append(target)

func unregister(target: Node3D) -> void:
	targets.erase(target)

func get_current() -> Node3D:
	if override_target != null:
		return override_target
	if targets.is_empty():
		return null
	return targets[current_index]

func set_current(target: Node3D) -> void:
	override_target = target
	if target and target.has_node("Camera3D"):
		target.get_node("Camera3D").current = true

func switch_to(index: int) -> void:
	if index < targets.size():
		current_index = index

func reset() -> void:
	targets.clear()
	current_index = 0
	override_target = null
