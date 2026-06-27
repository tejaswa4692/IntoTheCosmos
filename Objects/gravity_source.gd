extends Node3D
class_name GravitySource

@export var gravity_strength: float = 9.8
@export var mass: float = 200.0
@export var use_inverse_square: bool = true  # true = realistic, false = constant pull

func _ready() -> void:
	GravityManager.register(self)

func _exit_tree() -> void:
	GravityManager.unregister(self)
