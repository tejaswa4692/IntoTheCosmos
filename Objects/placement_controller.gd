extends Node
@onready var player: CharacterBody3D = get_parent()

const PLACEABLE_SCENES := {
	"observatory": preload("res://Objects/observatory.tscn"),
	"rover": preload("res://Assets/Rover/rover.tscn")
}

func try_place_selected_item() -> void:
	var selected := InventoryGlobal.get_selected_item()
	if selected == "" or not PLACEABLE_SCENES.has(selected):
		return
	if not player.raycast.is_colliding():
		return
	var collider = player.raycast.get_collider()
	if not collider.is_in_group("planet"):
		return
	var planet = collider.get_parent()

	if selected == "observatory" and planet.has_observatory:
		var instance = PLACEABLE_SCENES[selected].instantiate()
		player.get_tree().root.add_child(instance)
		var point = player.raycast.get_collision_point()
		var normal = player.raycast.get_collision_normal()
		instance.global_position = point
		instance.global_basis = Basis.looking_at(normal)
		instance.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90))

	if selected == "observatory":
		planet.change_observatory_status()

	if selected == "rover":
		var instance = PLACEABLE_SCENES[selected].instantiate()
		player.get_tree().root.add_child(instance)
		var point = player.raycast.get_collision_point()
		var normal = player.raycast.get_collision_normal()
		instance.global_position = point
		instance.global_basis = Basis.looking_at(normal)
		instance.rotate_object_local(Vector3.RIGHT, deg_to_rad(-90))

	InventoryGlobal.remove_item(selected, 1)
