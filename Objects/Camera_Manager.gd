# CameraManager.gd
extends Node

var targets: Array[Node3D] = []
var current_index: int = 0

func register(target: Node3D) -> void:
	targets.append(target)

func unregister(target: Node3D) -> void:
	targets.erase(target)

func get_current() -> Node3D:
	if targets.is_empty():
		return null
	return targets[current_index]

func switch_to(index: int) -> void:
	if index < targets.size():
		current_index = index

func reset() -> void:
	targets.clear()
	current_index = 0
