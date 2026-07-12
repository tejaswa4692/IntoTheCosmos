extends Control
@onready var item_list: ItemList = $BottomInventory/ItemList
@onready var holding_sprite: Sprite3D = $"../Armature/Skeleton3D/PhysicalBoneSimulator3D/Physical Bone RightHand/HoldingSprite"
@onready var ccdik: CCDIK3D = $"../Armature/Skeleton3D/CCDIK3D"

const ICON_PATH := "res://Assets/InventoryIcons/%s.png"

var target_influence := 0.0
var _icon_cache: Dictionary = {}

func _ready() -> void:
	item_list.icon_mode = ItemList.ICON_MODE_TOP
	InventoryGlobal.inventory_changed.connect(_refresh)
	InventoryGlobal.selection_changed.connect(_on_selection_changed)
	_refresh()

func _process(delta: float) -> void:
	ccdik.influence = lerp(ccdik.influence, target_influence, delta * 8.0)

func _get_icon(item_name: String) -> Texture2D:
	if not _icon_cache.has(item_name):
		_icon_cache[item_name] = load(ICON_PATH % item_name) as Texture2D
	return _icon_cache[item_name]

func _refresh() -> void:
	item_list.clear()
	for slot in InventoryGlobal.Inventory:
		var icon := _get_icon(slot["item"])
		var label := "" if slot["count"] <= 1 else "x%d" % slot["count"]
		var idx := item_list.add_item(label, icon)
		item_list.set_item_tooltip(idx, "%s (%d)" % [slot["item"], slot["count"]])
	_highlight_selected()
	_update_holding_sprite()

func _on_selection_changed(_item_name: String) -> void:
	_highlight_selected()
	_update_holding_sprite()

func _highlight_selected() -> void:
	if InventoryGlobal.Inventory.is_empty():
		return
	item_list.select(InventoryGlobal.selected_index)
	item_list.ensure_current_is_visible()

func _update_holding_sprite() -> void:
	if InventoryGlobal.Inventory.is_empty():
		holding_sprite.texture = null
		target_influence = 0.0
		return
	var slot = InventoryGlobal.Inventory[InventoryGlobal.selected_index]
	if slot["item"] == "":
		holding_sprite.texture = null
		target_influence = 0.0
		return
	holding_sprite.texture = _get_icon(slot["item"])
	target_influence = 1.0
