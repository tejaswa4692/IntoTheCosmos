extends Node

var satellites: Array = []


func register(satellite: Node) -> void:
	if !satellites.has(satellite):
		satellites.append(satellite)


func unregister(satellite: Node) -> void:
	satellites.erase(satellite)


func get_satellites() -> Array:
	return satellites
