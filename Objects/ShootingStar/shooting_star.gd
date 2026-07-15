extends Node3D
class_name ShootingStar

@export var mesh_variants: Array[Mesh] = []
@export var streak_material: Material

@export var min_speed: float = 40.0
@export var max_speed: float = 120.0
@export var min_stretch: float = 3.0
@export var max_stretch: float = 8.0
@export var lifetime: float = 3.0

var velocity: Vector3
var time_alive: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	var dir := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	var speed := randf_range(min_speed, max_speed)
	var stretch := randf_range(min_stretch, max_stretch)

	if not mesh_variants.is_empty():
		mesh_instance.mesh = mesh_variants[randi() % mesh_variants.size()]
	if streak_material:
		mesh_instance.material_override = streak_material

	mesh_instance.scale.z = stretch
	velocity = dir * speed
	look_at(global_position + dir, Vector3.UP)

func _process(delta: float) -> void:
	global_position += velocity * delta
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()
