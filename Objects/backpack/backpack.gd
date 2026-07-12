class_name Backpack
extends Node3D
signal contents_changed
@export var capacity: int = 20
var contents: Array = []   # Array of {"item": String, "count": int}
var has_player: bool = false
@onready var ui_layer: Control = $Control
@onready var item_list: ItemList = $Control/ItemList
const ICON_PATH := "res://Assets/InventoryIcons/%s.png"
var _icon_cache: Dictionary = {}


func _ready() -> void:
	item_list.icon_mode = ItemList.ICON_MODE_TOP
	item_list.fixed_icon_size = Vector2i(250, 250)   # match whatever your hotbar uses
	item_list.item_clicked.connect(_on_item_clicked)
	item_list.empty_clicked.connect(_on_empty_clicked)
	contents_changed.connect(_refresh)
	ui_layer.hide()

func _get_icon(item_name: String) -> Texture2D:
	if not _icon_cache.has(item_name):
		_icon_cache[item_name] = load(ICON_PATH % item_name) as Texture2D
	return _icon_cache[item_name]

# ---------------- Data ----------------

func get_total_count() -> int:
	var total := 0
	for entry in contents:
		total += entry["count"]
	return total

func add_item(item_name: String, amount: int = 1) -> bool:
	if amount <= 0 or get_total_count() + amount > capacity:
		return false
	for entry in contents:
		if entry["item"] == item_name:
			entry["count"] += amount
			contents_changed.emit()
			return true
	contents.append({"item": item_name, "count": amount})
	contents_changed.emit()
	return true

func remove_item(item_name: String, amount: int = 1) -> bool:
	for i in range(contents.size()):
		if contents[i]["item"] == item_name:
			if contents[i]["count"] < amount:
				return false
			contents[i]["count"] -= amount
			if contents[i]["count"] <= 0:
				contents.remove_at(i)
			contents_changed.emit()
			return true
	return false

# ---------------- UI ----------------

func open_ui() -> void:
	ui_layer.show()
	_refresh()

func close_ui() -> void:
	ui_layer.hide()

func _refresh() -> void:
	item_list.clear()
	for entry in contents:
		var icon := _get_icon(entry["item"])
		var label := "" if entry["count"] <= 1 else "x%d" % entry["count"]
		var idx := item_list.add_item(label, icon)
		item_list.set_item_tooltip(idx, "%s (%d)" % [entry["item"], entry["count"]])

func _on_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		# Right-click an item to pull one back out into the hotbar.
		if index < 0 or index >= contents.size():
			return
		var item_name = contents[index]["item"]
		if remove_item(item_name, 1):
			InventoryGlobal.add_item(item_name, 1)
	else:
		# Left-click anywhere in the list stashes the currently selected hotbar item.
		try_stash(InventoryGlobal.get_selected_item())

func try_stash(item_name: String) -> bool:
	if item_name == "":
		return false
	if add_item(item_name, 1):
		InventoryGlobal.remove_item(item_name, 1)
		return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_nearest_backpack"):
		body.set_nearest_backpack(self)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_nearest_backpack") and body.nearest_backpack == self:
		body.set_nearest_backpack(null)



func _on_empty_clicked(_at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		try_stash(InventoryGlobal.get_selected_item())
