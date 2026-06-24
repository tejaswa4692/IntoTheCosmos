extends Node3D



@export var target: Node3D                   
@export var mouse_sensitivity: float = 0.005
@export var min_pitch: float = -60.0          
@export var max_pitch: float = 60.0           

@onready var spring_arm: SpringArm3D = $SpringArm3D

var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

func _physics_process(_delta: float) -> void:
	if not target:
		return
	global_position = target.global_position
	rotation.y = yaw
	spring_arm.rotation.x = pitch
