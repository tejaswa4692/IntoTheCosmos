# satellite_manager.gd
extends Node
var satellites: Array = []

func register(satellite: Node) -> void:
	if !satellites.has(satellite):
		satellites.append(satellite)

func unregister(satellite: Node) -> void:
	satellites.erase(satellite)

func get_satellites() -> Array:
	return satellites

func set_active(satellite: Node) -> void:
	for sat in satellites:
		if is_instance_valid(sat):
			sat.has_player = (sat == satellite)
