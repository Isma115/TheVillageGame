extends RefCounted
class_name GameSmokeVerifier

const REQUIRED_MINERAL_IDS: Array[StringName] = [
	&"coal",
	&"iron",
	&"copper",
	&"gold",
	&"silver"
]

var _catalog: GameCatalog
var _game_world: GameWorld
var _forestry_system: ForestrySystem
var _mining_system: MiningSystem
var _world_area_system: WorldAreaSystem
var _interaction_system: InteractionSystem
var _player: PlayerActor
var _overworld_actor_layer: Node2D
var _overworld_collision_world: CollisionWorld
var _mine_runtimes: Array[MineAreaRuntime] = []


func initialize(
	catalog: GameCatalog,
	game_world: GameWorld,
	forestry_system: ForestrySystem,
	mining_system: MiningSystem,
	world_area_system: WorldAreaSystem,
	interaction_system: InteractionSystem,
	player: PlayerActor,
	overworld_actor_layer: Node2D,
	overworld_collision_world: CollisionWorld,
	mine_runtimes: Array[MineAreaRuntime]
) -> void:
	_catalog = catalog
	_game_world = game_world
	_forestry_system = forestry_system
	_mining_system = mining_system
	_world_area_system = world_area_system
	_interaction_system = interaction_system
	_player = player
	_overworld_actor_layer = overworld_actor_layer
	_overworld_collision_world = overworld_collision_world
	_mine_runtimes.assign(mine_runtimes)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(_validate_content())
	errors.append_array(_validate_overworld())
	errors.append_array(_validate_mines())
	errors.append_array(_validate_transitions())
	return errors


func success_message() -> String:
	return (
		"PRADERA_SMOKE_TEST_OK areas=%d mines=%d portals=%d trees=%d veins=%d minerals=%d obstacles=%d/%d"
		% [
			_world_area_system.area_count(),
			_mining_system.mine_count(),
			_world_area_system.portal_count(),
			_forestry_system.tree_count(),
			_mining_system.vein_count(),
			_mining_system.mineral_type_count(),
			_overworld_collision_world.obstacle_count(),
			_mine_collision_obstacle_count()
		]
	)


func _validate_content() -> PackedStringArray:
	var errors := PackedStringArray()
	if _forestry_system.tree_count() != _catalog.forest.target_tree_count:
		errors.append(
			"Se generaron %d de %d árboles."
			% [
				_forestry_system.tree_count(),
				_catalog.forest.target_tree_count
			]
		)
	if _mining_system.vein_count() != _expected_deposit_count():
		errors.append(
			"Se crearon %d de %d vetas."
			% [_mining_system.vein_count(), _expected_deposit_count()]
		)
	if _mining_system.mine_count() != _catalog.mine_definitions().size():
		errors.append("El registro de minas no coincide con el catálogo.")
	for mineral_id in REQUIRED_MINERAL_IDS:
		if not _mining_system.has_mineral(mineral_id):
			errors.append("Falta el mineral obligatorio '%s'." % mineral_id)
	if _world_area_system.area_count() != _catalog.mine_definitions().size() + 1:
		errors.append("El registro de áreas no coincide con el catálogo.")
	if _world_area_system.portal_count() != _catalog.portal_definitions().size():
		errors.append("El registro de portales no coincide con el catálogo.")
	return errors


func _validate_overworld() -> PackedStringArray:
	var errors := PackedStringArray()
	var expected_interactables := (
		_forestry_system.active_tree_count()
		+ _world_area_system.portal_count(GameCatalog.OVERWORLD_AREA_ID)
	)
	var actual_interactables := _interaction_system.registered_count(
		GameCatalog.OVERWORLD_AREA_ID
	)
	if actual_interactables != expected_interactables:
		errors.append(
			"Hay %d interacciones exteriores, se esperaban %d."
			% [actual_interactables, expected_interactables]
		)

	var expected_obstacles := (
		_game_world.house_count()
		+ _forestry_system.active_tree_count()
		+ _world_area_system.portal_collision_count(GameCatalog.OVERWORLD_AREA_ID)
	)
	if _overworld_collision_world.obstacle_count() != expected_obstacles:
		errors.append(
			"Hay %d obstáculos exteriores, se esperaban %d."
			% [
				_overworld_collision_world.obstacle_count(),
				expected_obstacles
			]
		)
	return errors


func _validate_mines() -> PackedStringArray:
	var errors := PackedStringArray()
	for runtime in _mine_runtimes:
		var area_id := runtime.definition.area_id
		var expected_veins := runtime.definition.deposit_definitions().size()
		if _mining_system.vein_count(area_id) != expected_veins:
			errors.append(
				"La mina '%s' tiene %d de %d vetas."
				% [
					runtime.definition.id,
					_mining_system.vein_count(area_id),
					expected_veins
				]
			)

		var expected_interactables := (
			_mining_system.active_vein_count(area_id)
			+ _world_area_system.portal_count(area_id)
		)
		var actual_interactables := _interaction_system.registered_count(area_id)
		if actual_interactables != expected_interactables:
			errors.append(
				"El área '%s' tiene %d interacciones, se esperaban %d."
				% [area_id, actual_interactables, expected_interactables]
			)

		var expected_obstacles := (
			runtime.world.obstacle_count()
			+ _mining_system.active_vein_count(area_id)
			+ _world_area_system.portal_collision_count(area_id)
		)
		if runtime.collision_world.obstacle_count() != expected_obstacles:
			errors.append(
				"El área '%s' tiene %d obstáculos, se esperaban %d."
				% [
					area_id,
					runtime.collision_world.obstacle_count(),
					expected_obstacles
				]
			)
	return errors


func _validate_transitions() -> PackedStringArray:
	var errors := PackedStringArray()
	for runtime in _mine_runtimes:
		if not _world_area_system.transition_to(
			runtime.definition.area_id,
			runtime.definition.player_spawn
		):
			errors.append("No se pudo entrar en '%s'." % runtime.definition.label)
		elif (
			_world_area_system.active_area_id() != runtime.definition.area_id
			or _player.get_parent() != runtime.actor_layer
			or _player.collision_world != runtime.collision_world
		):
			errors.append(
				"La transición a '%s' dejó un contexto incoherente."
				% runtime.definition.label
			)

		if not _world_area_system.transition_to(
			GameCatalog.OVERWORLD_AREA_ID,
			_catalog.player_spawn
		):
			errors.append("No se pudo volver a la aldea.")
		elif (
			_world_area_system.active_area_id() != GameCatalog.OVERWORLD_AREA_ID
			or _player.get_parent() != _overworld_actor_layer
			or _player.collision_world != _overworld_collision_world
		):
			errors.append("La transición a la aldea dejó un contexto incoherente.")
	return errors


func _expected_deposit_count() -> int:
	var total := 0
	for definition in _catalog.mine_definitions():
		total += definition.deposit_definitions().size()
	return total


func _mine_collision_obstacle_count() -> int:
	var total := 0
	for runtime in _mine_runtimes:
		total += runtime.collision_world.obstacle_count()
	return total
