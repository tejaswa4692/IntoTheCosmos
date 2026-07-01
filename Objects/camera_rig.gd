extends Node3D

@export var mouse_sensitivity: float = 0.005
@export var min_pitch: float = -60.0
@export var max_pitch: float = 60.0
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
	elif event is InputEventKey:
		for i in CameraManager.targets.size():
			if event.is_action_pressed("cam_" + str(i + 1)):
				CameraManager.switch_to(i)

func _physics_process(_delta: float) -> void:
	var target = CameraManager.get_current()
	if not target:
		return
	global_position = target.global_position
	# only apply yaw/pitch when following a rocket or similar
	# if target is the player, the player handles its own camera via the Head node
	if target.is_in_group("rocket"):
		rotation.y = yaw
		spring_arm.rotation.x = pitch
	else:
		rotation.y = yaw
		spring_arm.rotation.x = pitch


func activate():
	camera.current = true

func deactivate():
	camera.current = false
