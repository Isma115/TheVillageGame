extends Node
class_name ForestrySystem

signal tree_felled(tree: TreeActor, item: ItemDefinition, amount: int)

@export var tree_scene: PackedScene

var trees: Array[TreeActor] = []
var _active_tree_count := 0
var _forest: ForestDefinition
var _catalog: GameCatalog
var _world: GameWorld
var _actor_layer: Node2D
var _collision_world: CollisionWorld
var _interaction_system: InteractionSystem
var _inventory: InventoryService
var _random_source := RandomNumberGenerator.new()
var _action_cooldown := ActionCooldown.new()


func initialize(
	forest_definition: ForestDefinition,
	game_catalog: GameCatalog,
	game_world: GameWorld,
	actor_layer: Node2D,
	collision_world: CollisionWorld,
	interaction_system: InteractionSystem,
	inventory: InventoryService
) -> void:
	_clear_trees()
	_forest = forest_definition
	_catalog = game_catalog
	_world = game_world
	_actor_layer = actor_layer
	_collision_world = collision_world
	_interaction_system = interaction_system
	_inventory = inventory
	_action_cooldown.reset()

	if tree_scene == null:
		push_error("ForestrySystem necesita una escena de árbol.")
		return
	if _forest == null:
		push_error("ForestrySystem necesita una definición de bosque.")
		return

	_random_source.seed = _forest.random_seed
	_generate_forest()


func tree_count() -> int:
	return trees.size()


func active_tree_count() -> int:
	return _active_tree_count


func stump_count() -> int:
	return tree_count() - active_tree_count()


func _generate_forest() -> void:
	var generation_bounds := _catalog.playable_bounds().grow(-_forest.world_edge_inset)
	if generation_bounds.size.x <= 0.0 or generation_bounds.size.y <= 0.0:
		push_error("El área disponible para el bosque está vacía.")
		return

	var placement_buckets: Dictionary = {}
	var accepted_positions: Array[Vector2] = []
	var attempts := 0

	while (
		accepted_positions.size() < _forest.target_tree_count
		and attempts < _forest.max_generation_attempts
	):
		attempts += 1
		var candidate := Vector2(
			_random_source.randf_range(generation_bounds.position.x, generation_bounds.end.x),
			_random_source.randf_range(generation_bounds.position.y, generation_bounds.end.y)
		)
		if not _is_valid_tree_position(candidate, placement_buckets):
			continue

		var definition := _choose_tree_definition()
		if definition == null:
			break

		var scale_value := _random_source.randf_range(
			_forest.scale_range.x,
			_forest.scale_range.y
		)
		var index := accepted_positions.size()
		_spawn_tree(definition, candidate, scale_value, index)
		accepted_positions.append(candidate)
		_register_placement(candidate, placement_buckets)

	if accepted_positions.size() < _forest.target_tree_count:
		push_warning(
			"El bosque generó %d de %d árboles tras %d intentos."
			% [accepted_positions.size(), _forest.target_tree_count, attempts]
		)


func _is_valid_tree_position(candidate: Vector2, placement_buckets: Dictionary) -> bool:
	if candidate.distance_to(_catalog.plaza) < _forest.village_clear_radius:
		return false
	if candidate.distance_to(_catalog.player_spawn) < _forest.player_spawn_clearance:
		return false
	for animal in _catalog.animal_definitions():
		if candidate.distance_to(animal.world_position) < _forest.animal_spawn_clearance:
			return false
	if _world.is_position_near_path(candidate, _forest.path_clearance):
		return false
	if _world.is_position_reserved(candidate, _forest.house_clearance):
		return false
	return not _has_nearby_tree(candidate, placement_buckets)


func _has_nearby_tree(candidate: Vector2, placement_buckets: Dictionary) -> bool:
	var cell := _placement_cell(candidate)
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			var nearby: Array = placement_buckets.get(cell + Vector2i(offset_x, offset_y), [])
			for existing_position in nearby:
				if candidate.distance_to(existing_position) < _forest.minimum_spacing:
					return true
	return false


func _register_placement(candidate: Vector2, placement_buckets: Dictionary) -> void:
	var cell := _placement_cell(candidate)
	var bucket: Array = placement_buckets.get(cell, [])
	bucket.append(candidate)
	placement_buckets[cell] = bucket


func _placement_cell(candidate: Vector2) -> Vector2i:
	return Vector2i(
		floori(candidate.x / _forest.minimum_spacing),
		floori(candidate.y / _forest.minimum_spacing)
	)


func _choose_tree_definition() -> TreeDefinition:
	var definitions := _forest.tree_definitions()
	if definitions.is_empty():
		return null
	if _forest.type_weights.is_empty():
		return definitions[_random_source.randi_range(0, definitions.size() - 1)]

	var total_weight := 0.0
	for weight in _forest.type_weights:
		total_weight += maxf(weight, 0.0)
	var cursor := _random_source.randf() * total_weight
	for index in range(definitions.size()):
		cursor -= maxf(_forest.type_weights[index], 0.0)
		if cursor <= 0.0:
			return definitions[index]
	return definitions.back()


func _spawn_tree(
	definition: TreeDefinition,
	world_position: Vector2,
	scale_value: float,
	index: int
) -> void:
	var tree := tree_scene.instantiate() as TreeActor
	if tree == null:
		push_error("La escena de árbol no crea un TreeActor.")
		return

	tree.initialize(
		definition,
		world_position,
		scale_value,
		_forest.random_seed + index * 7919,
		index
	)
	_actor_layer.add_child(tree)
	tree.interaction_requested.connect(_on_tree_interaction_requested)
	_collision_world.register_obstacle(tree.collision_key(), tree.collision_rectangle())
	_interaction_system.register_interactable(tree)
	trees.append(tree)
	_active_tree_count += 1


func _on_tree_interaction_requested(target: Node2D, source: Node2D) -> void:
	var tree := target as TreeActor
	if tree == null or not tree.can_interact(source):
		return

	if not _action_cooldown.try_start(_forest.chop_cooldown):
		return

	if not tree.apply_chop(_forest.base_chop_damage):
		return

	_collision_world.unregister_obstacle(tree.collision_key())
	_interaction_system.unregister_interactable(tree)
	var amount_added := _inventory.add_item(
		tree.definition.yielded_item,
		tree.wood_yield
	)
	_active_tree_count = maxi(0, _active_tree_count - 1)
	tree.play_fall(source.global_position)
	tree_felled.emit(tree, tree.definition.yielded_item, amount_added)


func _clear_trees() -> void:
	for tree in trees:
		if not is_instance_valid(tree):
			continue
		if _collision_world != null:
			_collision_world.unregister_obstacle(tree.collision_key())
		if _interaction_system != null:
			_interaction_system.unregister_interactable(tree)
		tree.queue_free()
	trees.clear()
	_active_tree_count = 0
