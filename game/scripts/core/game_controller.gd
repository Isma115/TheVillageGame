extends Node2D
class_name GameController

const SMOKE_TEST_ARGUMENT := "--smoke-test"

@export var catalog: GameCatalog
@export var mine_area_scene: PackedScene

@onready var dynamic_areas: Node2D = %DynamicAreas
@onready var overworld_area: Node2D = %OverworldArea
@onready var game_world: GameWorld = %GameWorld
@onready var interaction_highlight: InteractionHighlight = %InteractionHighlight
@onready var overworld_actor_layer: Node2D = %OverworldActorLayer
@onready var wildlife: WildlifeManager = %Wildlife
@onready var interaction_system: InteractionSystem = %InteractionSystem
@onready var world_area_system: WorldAreaSystem = %WorldAreaSystem
@onready var forestry_system: ForestrySystem = %ForestrySystem
@onready var mining_system: MiningSystem = %MiningSystem
@onready var player: PlayerActor = %Player
@onready var game_hud: GameHud = %GameHud
@onready var mobile_controls: MobileControls = %MobileControls

var overworld_collision_world := CollisionWorld.new()
var mine_runtimes: Array[MineAreaRuntime] = []
var input_state := InputState.new()
var inventory := InventoryService.new()
var debug_elapsed := 0.0
var mobile_build := false
var initialized := false


func _ready() -> void:
	if not _validate_configuration():
		return

	RenderingServer.set_default_clear_color(catalog.grass_color)
	mobile_build = OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")

	_initialize_world()
	_initialize_interface()
	_initialize_player_and_interactions()
	if not _initialize_areas():
		return
	_initialize_gameplay_systems()

	if not world_area_system.activate_initial_area(
		GameCatalog.OVERWORLD_AREA_ID,
		catalog.player_spawn
	):
		_fail_initialization("No se pudo activar la aldea.")
		return

	initialized = true
	if not mobile_build:
		_update_debug()
	if SMOKE_TEST_ARGUMENT in OS.get_cmdline_user_args():
		call_deferred("_finish_smoke_test")


func _validate_configuration() -> bool:
	if catalog == null:
		_fail_initialization("La escena no tiene un catálogo de juego.")
		return false
	if mine_area_scene == null:
		_fail_initialization("La escena no tiene una plantilla de área minera.")
		return false

	var validation_errors := catalog.validate()
	if not validation_errors.is_empty():
		_fail_initialization("\n".join(validation_errors))
		return false
	return true


func _initialize_world() -> void:
	game_world.initialize(catalog, overworld_actor_layer)
	overworld_collision_world.configure(
		catalog.playable_bounds(),
		game_world.collision_obstacles()
	)
	inventory.register_items(catalog.item_definitions())


func _initialize_interface() -> void:
	game_hud.initialize(mobile_build)
	inventory.item_changed.connect(game_hud.set_inventory_item)
	for item in catalog.item_definitions():
		game_hud.set_inventory_item(item, inventory.quantity_of(item.id))

	mobile_controls.direction_changed.connect(input_state.set_virtual_direction)
	mobile_controls.sprint_changed.connect(input_state.set_virtual_sprinting)
	mobile_controls.primary_action_pressed.connect(input_state.request_interaction)
	game_hud.mobile_controls_toggled.connect(mobile_controls.set_enabled)
	mobile_controls.set_enabled(mobile_build)


func _initialize_player_and_interactions() -> void:
	player.initialize(catalog, overworld_collision_world, input_state)
	interaction_system.prompt_changed.connect(game_hud.set_interaction_prompt)
	interaction_system.prompt_changed.connect(mobile_controls.set_primary_action)
	interaction_system.initialize(player, input_state)


func _initialize_areas() -> bool:
	world_area_system.initialize(player, interaction_system)
	mining_system.initialize(interaction_system, inventory)
	if world_area_system.register_area(
		GameCatalog.OVERWORLD_AREA_ID,
		"Aldea",
		overworld_area,
		overworld_actor_layer,
		overworld_collision_world,
		catalog.world_rect()
	) == null:
		_fail_initialization("No se pudo registrar el área exterior.")
		return false

	for mine_definition in catalog.mine_definitions():
		if _create_mine_runtime(mine_definition) == null:
			_fail_initialization(
				"No se pudo componer la mina '%s'." % mine_definition.id
			)
			return false

	if not world_area_system.register_portals(catalog.portal_definitions()):
		_fail_initialization("No se pudieron registrar todos los portales.")
		return false
	world_area_system.area_changed.connect(_on_area_changed)
	for portal in world_area_system.portal_actors(GameCatalog.OVERWORLD_AREA_ID):
		game_world.register_placement_reservation(
			portal.collision_key(),
			portal.visual_rectangle()
		)
	return true


func _create_mine_runtime(definition: MineDefinition) -> MineAreaRuntime:
	var area := mine_area_scene.instantiate() as MineArea
	if area == null:
		push_error("La plantilla de mina no crea un MineArea.")
		return null

	area.name = String(definition.area_id)
	dynamic_areas.add_child(area)
	area.initialize(definition)
	var collision_world := CollisionWorld.new()
	collision_world.configure(
		definition.playable_bounds(),
		area.world.collision_obstacles()
	)

	var runtime := MineAreaRuntime.new()
	if not runtime.configure_mine(
		definition,
		area,
		area.world,
		area.actor_layer,
		collision_world
	):
		area.queue_free()
		return null
	if not world_area_system.register_runtime(runtime):
		area.queue_free()
		return null
	if mining_system.register_mine(
		definition,
		area.actor_layer,
		collision_world
	) == null:
		area.queue_free()
		return null

	mine_runtimes.append(runtime)
	return runtime


func _initialize_gameplay_systems() -> void:
	forestry_system.initialize(
		catalog.forest,
		catalog,
		game_world,
		overworld_actor_layer,
		overworld_collision_world,
		interaction_system,
		inventory
	)
	wildlife.initialize(
		catalog.animal_definitions(),
		overworld_actor_layer,
		overworld_collision_world,
		catalog.playable_bounds()
	)
	interaction_highlight.initialize(catalog, not mobile_build)


func _process(delta: float) -> void:
	if not initialized:
		return

	player.update_player(delta)
	if world_area_system.is_area_active(GameCatalog.OVERWORLD_AREA_ID):
		wildlife.update_animals(delta)
	interaction_system.update_interactions(delta)

	if mobile_build:
		return

	debug_elapsed += delta
	if debug_elapsed >= 0.25:
		_update_debug()
		debug_elapsed = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and input_state != null:
		input_state.reset_virtual_controls()


func _unhandled_input(event: InputEvent) -> void:
	input_state.handle_event(event)


func _on_area_changed(area_id: StringName, label: String) -> void:
	game_hud.set_location(label)
	interaction_highlight.set_enabled(
		not mobile_build and area_id == GameCatalog.OVERWORLD_AREA_ID
	)
	if initialized and not mobile_build:
		_update_debug()


func _update_debug() -> void:
	game_hud.update_debug({
		"fps": Engine.get_frames_per_second(),
		"memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"entities": (
			1
			+ game_world.house_count()
			+ wildlife.animal_count()
			+ forestry_system.tree_count()
			+ mining_system.vein_count()
			+ world_area_system.portal_count()
		),
		"objects": (
			game_world.house_count()
			+ game_world.path_tile_count()
			+ forestry_system.tree_count()
			+ mining_system.vein_count()
			+ _mine_static_obstacle_count()
			+ world_area_system.portal_count()
		),
		"area": world_area_system.active_area_id(),
		"houses": game_world.house_count(),
		"animals": wildlife.animal_count(),
		"trees": forestry_system.active_tree_count(),
		"veins": mining_system.active_vein_count(),
		"path_tiles": game_world.path_tile_count(),
		"particles": player.run_cloud_count()
	})


func _mine_static_obstacle_count() -> int:
	var total := 0
	for runtime in mine_runtimes:
		total += runtime.world.obstacle_count()
	return total


func _fail_initialization(message: String) -> void:
	initialized = false
	set_process(false)
	push_error("No se pudo iniciar Pradera:\n%s" % message)


func _finish_smoke_test() -> void:
	var verifier := GameSmokeVerifier.new()
	verifier.initialize(
		catalog,
		game_world,
		forestry_system,
		mining_system,
		world_area_system,
		interaction_system,
		player,
		overworld_actor_layer,
		overworld_collision_world,
		mine_runtimes
	)
	var smoke_errors := verifier.validate()

	if not smoke_errors.is_empty():
		push_error("PRADERA_SMOKE_TEST_FAILED\n%s" % "\n".join(smoke_errors))
		get_tree().quit(1)
		return

	print(verifier.success_message())
	var scene_tree := get_tree()
	var shutdown_timer := scene_tree.create_timer(0.05)
	shutdown_timer.timeout.connect(scene_tree.quit, CONNECT_ONE_SHOT)
	scene_tree.current_scene.queue_free()
