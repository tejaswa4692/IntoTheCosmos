extends Node
@onready var player: CharacterBody3D = get_parent()

func open_backpack(bp: Backpack) -> void:
	player.ui_open = true
	InventoryGlobal.isUIopen = true
	player.open_backpack = bp
	bp.open_ui()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_backpack() -> void:
	player.ui_open = false
	InventoryGlobal.isUIopen = false
	if player.open_backpack:
		player.open_backpack.close_ui()
	player.open_backpack = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func try_stash_selected() -> void:
	if player.open_backpack == null:
		return
	player.open_backpack.try_stash(InventoryGlobal.get_selected_item())
