extends Node3D
class_name PlanetSectorManager

## Assign your player/rocket node here (drag it in the Inspector)
@export var player_path: NodePath

## Assign your Planet.tscn here (the one with GravitySource attached)
@export var planet_scene: PackedScene

## Size of one sector (cube) in world units
@export var sector_size := 4000.0

## How many sectors out (in each axis) to keep spawned around the player
@export var stream_radius_sectors := 2

## Sectors further than this (in sector units) get despawned
@export var despawn_radius_sectors := 3

## Global seed for the whole universe. Change this to get a totally different galaxy.
@export var galaxy_seed := 1337

## Chance (0-1) that any given sector actually contains a planet
@export var planet_spawn_chance := 0.15

## How much the planet's position can be randomly offset within its sector
@export var position_jitter := 1200.0

## Min/max random scale applied to spawned planets
@export var min_planet_scale := 0.5
@export var max_planet_scale := 2.5

## Base mass/gravity at scale = 1.0 (mirrors GravitySource defaults)
@export var base_mass := 5000.0
@export var base_gravity_strength := 9.8

var _spawned_sectors: Dictionary = {}   # Vector3i -> Node3D (planet instance, or null for confirmed-empty)
var _rng := RandomNumberGenerator.new()
var _check_timer := 0.0
const CHECK_INTERVAL := 0.5


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer < CHECK_INTERVAL:
		return
	_check_timer = 0.0

	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return

	var player_sector := world_to_sector(player.global_position)
	update_streaming(player_sector)


func world_to_sector(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floor(world_pos.x / sector_size),
		floor(world_pos.y / sector_size),
		floor(world_pos.z / sector_size)
	)


func sector_center(coord: Vector3i) -> Vector3:
	return Vector3(coord) * sector_size + Vector3.ONE * (sector_size * 0.5)


func update_streaming(player_sector: Vector3i) -> void:
	for x in range(-stream_radius_sectors, stream_radius_sectors + 1):
		for y in range(-stream_radius_sectors, stream_radius_sectors + 1):
			for z in range(-stream_radius_sectors, stream_radius_sectors + 1):
				var coord = player_sector + Vector3i(x, y, z)
				if !_spawned_sectors.has(coord):
					spawn_sector(coord)

	for coord in _spawned_sectors.keys():
		var offset = coord - player_sector
		var max_axis = max(abs(offset.x), max(abs(offset.y), abs(offset.z)))
		if max_axis > despawn_radius_sectors:
			despawn_sector(coord)


func _sector_seed(coord: Vector3i) -> int:
	# Deterministic seed derived from sector coordinate + galaxy seed.
	# Same coord always produces the same seed -> same planet (or same emptiness)
	# every time the player revisits it.
	var h := galaxy_seed
	h = h * 73856093 ^ coord.x * 19349663
	h = h * 83492791 ^ coord.y * 2654435761
	h = h * 15485863 ^ coord.z * 1274126177
	return abs(h)


func spawn_sector(coord: Vector3i) -> void:
	var seed_value := _sector_seed(coord)
	_rng.seed = seed_value

	if _rng.randf() > planet_spawn_chance:
		_spawned_sectors[coord] = null   # mark as "checked, empty" so we don't reroll
		return

	if planet_scene == null:
		push_warning("PlanetSectorManager: planet_scene not assigned")
		return

	var planet := planet_scene.instantiate()

	# Derive size/gravity/mass from the same deterministic RNG, all set on the
	# already-existing exported properties on GravitySource. Nothing about
	# GravitySource itself is modified.
	var scale_factor: float = _rng.randf_range(min_planet_scale, max_planet_scale)
	planet.scale = Vector3.ONE * scale_factor
	planet.mass = base_mass * pow(scale_factor, 3.0)
	planet.gravity_strength = base_gravity_strength * scale_factor

	# Setting planet_seed before add_child means GravitySource._ready() will
	# use this exact seed for its own material randomization (it already does
	# this internally whenever planet_seed != -1), so appearance is
	# deterministic per sector without needing any changes to that script.
	planet.planet_seed = seed_value

	var jitter := Vector3(
		_rng.randf_range(-position_jitter, position_jitter),
		_rng.randf_range(-position_jitter, position_jitter),
		_rng.randf_range(-position_jitter, position_jitter)
	)
	planet.position = sector_center(coord) + jitter

	add_child(planet)

	# randomize_rocks() is already a public method on GravitySource; since
	# planet_seed is already set, this deterministically reseeds rock count
	# using the same seed as the appearance material.
	if planet.has_method("randomize_rocks"):
		planet.randomize_rocks()

	_spawned_sectors[coord] = planet


func despawn_sector(coord: Vector3i) -> void:
	var planet = _spawned_sectors.get(coord)
	if planet != null and is_instance_valid(planet):
		planet.queue_free()
	_spawned_sectors.erase(coord)
