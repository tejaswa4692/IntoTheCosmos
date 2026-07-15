extends Node3D
class_name ShootingStarManager

@export var star_scene: PackedScene

@export_group("Spawn Timing")
@export var spawn_interval_min: float = 2.0
@export var spawn_interval_max: float = 6.0

@export_group("Spawn Volume")
@export var min_spawn_radius: float = 60.0
@export var max_spawn_radius: float = 300.0

@onready var boney: Node3D = get_node("../Boney")

var _timer: float = 0.0
var _next_spawn_time: float = 0.0

func _ready() -> void:
	_reset_timer()

func _process(delta: float) -> void:
	if star_scene == null or boney == null:
		return
	_timer += delta
	if _timer >= _next_spawn_time:
		_timer = 0.0
		_reset_timer()
		_spawn_star()

func _reset_timer() -> void:
	_next_spawn_time = randf_range(spawn_interval_min, spawn_interval_max)

func _spawn_star() -> void:
	var star: Node3D = star_scene.instantiate()

	var dir := _random_direction()
	var dist := randf_range(min_spawn_radius, max_spawn_radius)

	star.global_position = boney.global_position + dir * dist
	get_tree().current_scene.add_child(star)

func _random_direction() -> Vector3:
	return Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()
