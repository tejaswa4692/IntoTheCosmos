extends Node
signal inventory_changed
signal selection_changed(item_name: String)

var canmove: bool = true
var isUIopen: bool = false
var Inventory: Array = []      # Array of {"item": String, "count": int}
var selected_index: int = 0

func _ready() -> void:
	add_item("observatory", 9)
	add_item("rover", 2)

func add_item(item_name: String, amount: int = 1) -> void:
	for slot in Inventory:
		if slot["item"] == item_name:
			slot["count"] += amount
			inventory_changed.emit()
			return
	Inventory.append({"item": item_name, "count": amount})
	inventory_changed.emit()

func remove_item(item_name: String, amount: int = 1) -> bool:
	var selected_item_name := get_selected_item()
	for i in range(Inventory.size()):
		if Inventory[i]["item"] == item_name:
			Inventory[i]["count"] -= amount
			if Inventory[i]["count"] <= 0:
				Inventory.remove_at(i)
			_reselect(selected_item_name)
			inventory_changed.emit()
			return true
	return false

func _reselect(item_name: String) -> void:
	if Inventory.is_empty():
		selected_index = 0
		selection_changed.emit("")
		return
	for i in range(Inventory.size()):
		if Inventory[i]["item"] == item_name:
			if selected_index != i:
				selected_index = i
				selection_changed.emit(get_selected_item())
			return
	# the previously-selected item is gone entirely — clamp instead
	selected_index = clampi(selected_index, 0, Inventory.size() - 1)
	selection_changed.emit(get_selected_item())

func has_item(item_name: String) -> bool:
	for slot in Inventory:
		if slot["item"] == item_name:
			return true
	return false

func get_item_count(item_name: String) -> int:
	for slot in Inventory:
		if slot["item"] == item_name:
			return slot["count"]
	return 0

func get_selected_item() -> String:
	if Inventory.is_empty() or selected_index < 0 or selected_index >= Inventory.size():
		return ""
	return Inventory[selected_index]["item"]

func select_index(index: int) -> void:
	if Inventory.is_empty():
		return
	selected_index = clampi(index, 0, Inventory.size() - 1)
	selection_changed.emit(get_selected_item())

func select_next() -> void:
	if Inventory.is_empty():
		return
	selected_index = (selected_index + 1) % Inventory.size()
	selection_changed.emit(get_selected_item())

func select_prev() -> void:
	if Inventory.is_empty():
		return
	selected_index = (selected_index - 1 + Inventory.size()) % Inventory.size()
	selection_changed.emit(get_selected_item())
