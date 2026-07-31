extends Node
class_name WildlifeManager

const INVALID_SPAWN_POSITION := Vector2(999999999.0, 999999999.0)

@export var animal_scene: PackedScene

@export_group("Aparición")
@export_range(0.1, 60.0, 0.1) var spawn_interval := 1.8
@export_range(64.0, 1024.0, 1.0) var corner_spawn_band := 240.0
@export_range(0.0, 256.0, 1.0) var corner_edge_inset := 48.0
@export_range(0.0, 512.0, 1.0) var camera_clearance := 96.0
@export_range(1, 64, 1) var spawn_attempts := 24
@export var random_seed := 7391

var animals: Array[AnimalActor] = []

var _definitions: Array[AnimalDefinition] = []
var _actor_layer: Node2D
var _collision_world: CollisionWorld
var _playable_bounds := Rect2()
var _camera: Camera2D
var _population_by_id: Dictionary = {}
var _random_source := RandomNumberGenerator.new()
var _spawn_elapsed := 0.0
var _initialized := false


func initialize(
	definitions: Array[AnimalDefinition],
	actor_layer: Node2D,
	collision_world: CollisionWorld,
	playable_bounds: Rect2,
	camera: Camera2D
) -> void:
	_clear_animals()
	_definitions.assign(definitions)
	_actor_layer = actor_layer
	_collision_world = collision_world
	_playable_bounds = playable_bounds
	_camera = camera
	_random_source.seed = random_seed
	_spawn_elapsed = spawn_interval
	_initialized = true

	if animal_scene == null:
		_initialized = false
		push_error("WildlifeManager necesita una escena de animal.")


func update_animals(delta: float) -> void:
	if not _initialized or delta <= 0.0:
		return

	for animal in animals:
		if is_instance_valid(animal):
			animal.update_animal(delta)

	_spawn_elapsed += delta
	if _spawn_elapsed < spawn_interval:
		return

	_spawn_elapsed = 0.0
	_try_spawn_animal()


func animal_count(animal_id: StringName = &"") -> int:
	if String(animal_id).is_empty():
		return animals.size()
	return int(_population_by_id.get(animal_id, 0))


func animal_at_world_position(world_position: Vector2) -> AnimalActor:
	var closest_animal: AnimalActor
	var closest_distance := INF
	for animal in animals:
		if (
			not is_instance_valid(animal)
			or animal.definition == null
			or not animal.contains_hunting_point(world_position)
		):
			continue
		var distance := world_position.distance_to(animal.hunting_target_position())
		if distance < closest_distance:
			closest_animal = animal
			closest_distance = distance
	return closest_animal


func hunt_animal(animal: AnimalActor) -> bool:
	if animal == null or not is_instance_valid(animal):
		return false
	var index := animals.find(animal)
	if index < 0:
		return false

	var animal_id := animal.definition.id if animal.definition != null else &""
	animals.remove_at(index)
	if not String(animal_id).is_empty():
		_population_by_id[animal_id] = maxi(0, animal_count(animal_id) - 1)
	_animal_removed(animal)
	return true


func population_limits_valid() -> bool:
	for definition in _definitions:
		if definition == null:
			continue
		if animal_count(definition.id) > definition.max_population:
			return false
	return true


func _try_spawn_animal() -> void:
	if _actor_layer == null or _collision_world == null or animal_scene == null:
		return

	var available_definitions: Array[AnimalDefinition] = []
	for definition in _definitions:
		if definition == null or definition.max_population <= 0:
			continue
		if animal_count(definition.id) < definition.max_population:
			available_definitions.append(definition)

	if available_definitions.is_empty():
		return

	for _attempt in range(spawn_attempts):
		var definition := available_definitions[
			_random_source.randi_range(0, available_definitions.size() - 1)
		]
		var spawn_position := _find_spawn_position(definition)
		if spawn_position == INVALID_SPAWN_POSITION:
			continue
		_spawn_animal(definition, spawn_position)
		return


func _spawn_animal(definition: AnimalDefinition, spawn_position: Vector2) -> void:
	var animal := animal_scene.instantiate() as AnimalActor
	if animal == null:
		push_error("La escena de animal no crea un AnimalActor.")
		return

	animal.initialize(
		definition,
		_collision_world,
		_playable_bounds,
		spawn_position
	)
	_actor_layer.add_child(animal)
	animals.append(animal)
	_population_by_id[definition.id] = animal_count(definition.id) + 1


func _find_spawn_position(definition: AnimalDefinition) -> Vector2:
	for _attempt in range(spawn_attempts):
		var candidate := _random_corner_position(definition.collision_radius)
		if _is_spawn_position_valid(candidate, definition.collision_radius):
			return candidate
	return INVALID_SPAWN_POSITION


func _random_corner_position(radius: float) -> Vector2:
	var minimum_offset := corner_edge_inset + radius
	var maximum_offset := maxf(
		minimum_offset,
		minf(corner_spawn_band, _playable_bounds.size.x * 0.35) - radius
	)
	var horizontal_offset := _random_source.randf_range(
		minimum_offset,
		maximum_offset
	)
	var vertical_offset := _random_source.randf_range(
		minimum_offset,
		maximum_offset
	)
	var left_x := _playable_bounds.position.x + horizontal_offset
	var right_x := _playable_bounds.end.x - horizontal_offset
	var top_y := _playable_bounds.position.y + vertical_offset
	var bottom_y := _playable_bounds.end.y - vertical_offset

	match _random_source.randi_range(0, 3):
		0:
			return Vector2(left_x, top_y)
		1:
			return Vector2(right_x, top_y)
		2:
			return Vector2(left_x, bottom_y)
		_:
			return Vector2(right_x, bottom_y)


func _is_spawn_position_valid(candidate: Vector2, radius: float) -> bool:
	if not _playable_bounds.grow(-radius).has_point(candidate):
		return false

	var camera_rect := _camera_world_rect()
	if (
		camera_rect.size.x > 0.0
		and camera_rect.size.y > 0.0
		and camera_rect.grow(camera_clearance + radius).has_point(candidate)
	):
		return false

	var collision_result: Dictionary = _collision_world.move_circle(
		candidate,
		Vector2.ZERO,
		radius
	)
	var resolved_position: Vector2 = collision_result["position"]
	if resolved_position.distance_to(candidate) > 0.5:
		return false

	for animal in animals:
		if not is_instance_valid(animal) or animal.definition == null:
			continue
		var minimum_distance := (
			radius
			+ animal.definition.collision_radius
			+ 24.0
		)
		if candidate.distance_squared_to(animal.position) < minimum_distance * minimum_distance:
			return false
	return true


func _camera_world_rect() -> Rect2:
	if _camera == null or not is_instance_valid(_camera):
		return Rect2()

	var viewport_size := _camera.get_viewport_rect().size
	var zoom := _camera.zoom
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()

	var world_size := Vector2(
		viewport_size.x / maxf(absf(zoom.x), 0.01),
		viewport_size.y / maxf(absf(zoom.y), 0.01)
	)
	return Rect2(
		_camera.get_screen_center_position() - world_size * 0.5,
		world_size
	)


func _clear_animals() -> void:
	for animal in animals:
		if is_instance_valid(animal):
			animal.queue_free()
	animals.clear()
	_population_by_id.clear()


func _animal_removed(animal: AnimalActor) -> void:
	if is_instance_valid(animal):
		animal.queue_free()
