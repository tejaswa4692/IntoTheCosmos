extends CharacterBody3D

@export var move_speed: float = 2.5
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var interact_distance: float = 3.0
@export var gravity_align_speed: float = 5.0
@onready var fp_camera = $Head/Camera3D
@onready var raycast = $HeadCast
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var satellite_ui: Control = $SatteliteUI
@onready var satellite_item_list: ItemList = $SatteliteUI/ItemList

@onready var movement_controller = $MovementManager
@onready var mount_controller = $MountController
@onready var satellite_ui_controller = $SatelliteUIController
@onready var placement_controller = $PlacementController
@onready var backpack_controller = $BackPackController
@onready var breakercast = $Head/Camera3D/ScrapBreaker

var ui_open: bool
var settings_open: bool = false
var is_mounted: bool = false
var mounted_target = null
var mount_source = null
var nearest_rocket = null
var nearest_backpack: Backpack = null
var open_backpack: Backpack = null
var pitch: float = 0.0
var scraps: int = 0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not is_mounted:
		if !settings_open and !ui_open:
			rotate(up_direction, -event.relative.x * mouse_sensitivity)
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
			head.rotation.x = pitch

	if event is InputEventMouseButton and event.pressed and not is_mounted and !settings_open and !ui_open:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			InventoryGlobal.select_next()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			InventoryGlobal.select_prev()

	if event.is_action_pressed("interact") and not event.is_echo() and not Input.is_key_pressed(KEY_SHIFT):
		if open_backpack != null:
			backpack_controller.close_backpack()
		elif is_mounted:
			if mounted_target and !mounted_target.can_unmount():
				return
			mount_controller.unmount()
		elif nearest_rocket != null:
			mount_controller.mount(nearest_rocket)
		elif nearest_backpack != null:
			backpack_controller.open_backpack(nearest_backpack)

	if Input.is_action_just_pressed("ui_cancel") and ui_open:
		satellite_ui.visible = false
		if open_backpack != null:
			backpack_controller.close_backpack()

func _physics_process(delta: float) -> void:
	if is_mounted:
		return
	movement_controller.update_gravity(delta)
	movement_controller.handle_movement(delta, head)
	movement_controller.update_tree(animation_tree)
	if Input.is_action_just_pressed("Place") and !ui_open and !settings_open:
		if not handle_scrap_breaking():
			placement_controller.try_place_selected_item()

	if GraphicsSettings.showkeybinds:
		$Help.show()
	else:
		$Help.hide()

func set_nearest_rocket(rocket) -> void:
	nearest_rocket = rocket

func set_nearest_backpack(bp: Backpack) -> void:
	nearest_backpack = bp

func handle_scrap_breaking() -> bool:
	if breakercast.is_colliding():
		var scrap_scene = breakercast.get_collider()
		if scrap_scene.is_in_group("scrap"):
			scraps += scrap_scene.scrap_quantity 
			
			scrap_scene.remove()
			$NormalBoneyUI/Scrapcounter.text = "Scraps: " + str(scraps)
			return true
	return false
