@tool
extends Node3D
class_name GravitySource

@export var gravity_strength: float = 9.8
@export var mass: float = 200.0
@export var use_inverse_square: bool = true

@onready var camera: Camera3D = get_viewport().get_camera_3d()

func _ready() -> void:
	GravityManager.register(self)

func _exit_tree() -> void:
	GravityManager.unregister(self)

func _on_lod_timer_timeout() -> void:
	camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := global_position.distance_to(camera.global_position)
	if distance < 300 + $StaticBody3D/CollisionShape3D.shape.radius:
		$"Planet-LOD/LOD-Nearest".show()
		$"Planet-LOD/LOD-Mid".hide()
		$"Planet-LOD/LOD-Farthest".hide()
	elif distance < 2000 + $StaticBody3D/CollisionShape3D.shape.radius:
		$"Planet-LOD/LOD-Nearest".hide()
		$"Planet-LOD/LOD-Mid".show()
		$"Planet-LOD/LOD-Farthest".hide()
	else:
		$"Planet-LOD/LOD-Nearest".hide()
		$"Planet-LOD/LOD-Mid".hide()
		$"Planet-LOD/LOD-Farthest".show()
