extends Node3D
class_name PlanetScrapScatterer

@export var scrap_scene: PackedScene # assign scrap.tscn in the inspector
@export var scrap_count: int = 40
@export var min_scale: float = 0.5
@export var max_scale: float = 1.5
@export var surface_offset: float = 0.05 # small offset above the surface so scrap doesn't z-fight/clip into terrain
@export var auto_generate_on_ready: bool = true

var _rng := RandomNumberGenerator.new()
var _is_generating := false
var _planet: Node3D = null

func _ready() -> void:
	_planet = get_parent()
	if auto_generate_on_ready:
		call_deferred("regenerate")

func is_generating() -> bool:
	return _is_generating

func regenerate() -> void:
	if _is_generating:
		return
	_is_generating = true

	_clear_existing()

	if scrap_scene == null:
		push_warning("PlanetScrapScatterer on '%s': scrap_scene not assigned, skipping." % name)
		_is_generating = false
		return

	var radius := _get_planet_radius()
	if radius <= 0.0:
		push_warning("PlanetScrapScatterer on '%s': could not determine planet radius, skipping." % name)
		_is_generating = false
		return

	# Offset the seed from the planet's own seed so scrap placement doesn't
	# accidentally correlate with rock placement or surface material randomization
	var seed_source: int = _planet.planet_seed if (_planet and "planet_seed" in _planet) else randi()
	_rng.seed = seed_source + 777

	for i in range(scrap_count):
		_spawn_one(radius)

	_is_generating = false

func _get_planet_radius() -> float:
	if _planet:
		var collision_shape := _planet.get_node_or_null("StaticBody3D/CollisionShape3D")
		if collision_shape and collision_shape.shape:
			return collision_shape.shape.radius  # NOT multiplied by scale
	return 0.0

func _spawn_one(radius: float) -> void:
	var direction := _random_point_on_sphere()

	var instance := scrap_scene.instantiate()
	if not (instance is Node3D):
		push_warning("PlanetScrapScatterer: scrap_scene root is not a Node3D, cannot position it.")
		instance.queue_free()
		return

	var scrap := instance as Node3D
	add_child(scrap)

	var local_pos := direction * (radius + surface_offset)
	var basis := _align_basis_to_normal(direction)
	basis = basis.rotated(direction, _rng.randf_range(0.0, TAU)) # random yaw around the surface normal for variety

	var scale_factor := _rng.randf_range(min_scale, max_scale)
	scrap.transform = Transform3D(basis.scaled(Vector3.ONE * scale_factor), local_pos)

func _random_point_on_sphere() -> Vector3:
	# Proper uniform sphere sampling - sampling 3 uniform floats and normalizing
	# biases toward cube corners; this method (uniform z + uniform azimuth) doesn't.
	var u := _rng.randf()
	var v := _rng.randf()
	var theta := TAU * u
	var z := 2.0 * v - 1.0
	var r := sqrt(max(0.0, 1.0 - z * z))
	return Vector3(r * cos(theta), z, r * sin(theta))

func _align_basis_to_normal(normal: Vector3) -> Basis:
	# Builds an orthonormal basis whose Y axis matches the surface normal,
	# so scrap sits "upright" relative to the planet's local gravity direction
	# instead of all facing one arbitrary world direction.
	var reference := Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var right := reference.cross(normal).normalized()
	var forward := normal.cross(right).normalized()
	return Basis(right, normal, forward)

func _clear_existing() -> void:
	for child in get_children():
		child.queue_free()
