extends Node2D
class_name GameController

const SMOKE_TEST_ARGUMENT := "--smoke-test"

@export var catalog: GameCatalog
@export var mine_area_scene: PackedScene
@export var hotel_area_scene: PackedScene

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
@onready var npc_dialogue_system: NpcDialogueSystem = %NpcDialogueSystem
@onready var hunting_system: HuntingSystem = %HuntingSystem
@onready var player: PlayerActor = %Player
@onready var game_hud: GameHud = %GameHud
@onready var mobile_controls: MobileControls = %MobileControls

var overworld_collision_world := CollisionWorld.new()
var mine_runtimes: Array[MineAreaRuntime] = []
var hotel_runtime: WorldAreaRuntime
var input_state := InputState.new()
var inventory := InventoryService.new()
var tool_service := ToolService.new()
var wallet := WalletService.new()
var merchant_service := MerchantService.new()
var doctor_service := DoctorService.new()
var planting_system := PlantingSystem.new()
var save_game_service := SaveGameService.new()
var debug_elapsed := 0.0
var mobile_build := false
var initialized := false
var game_paused := false
var mobile_controls_before_dialogue := false
var mobile_controls_before_merchant := false
var mobile_controls_before_doctor := false
var mobile_controls_before_planting := false
var mobile_controls_before_inventory := false
var mobile_controls_before_blacksmith := false
var mobile_controls_before_hotel_sleep := false
var hotel_sleeping := false
var planting_position := Vector2.ZERO
var blacksmith_spot: BlacksmithSpotActor


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
	_refresh_hunting_mode_display()
	_load_saved_game()
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
	if hotel_area_scene == null:
		_fail_initialization("La escena no tiene una plantilla de hotel.")
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
	tool_service.initialize(catalog.tool_definitions(), catalog.default_tool_id)
	wallet.initialize(catalog.starting_coins)
	merchant_service.initialize(inventory, wallet, tool_service)
	doctor_service.initialize(wallet)


func _initialize_interface() -> void:
	game_hud.initialize(mobile_build, catalog.player_max_stamina)
	game_hud.pause_state_changed.connect(_on_pause_state_changed)
	game_hud.save_confirmed.connect(_on_save_confirmed)
	game_hud.save_cancelled.connect(_on_save_cancelled)
	game_hud.dialogue_choice_selected.connect(npc_dialogue_system.choose)
	game_hud.dialogue_action_selected.connect(npc_dialogue_system.perform_action)
	game_hud.dialogue_close_requested.connect(npc_dialogue_system.close_dialogue)
	npc_dialogue_system.dialogue_started.connect(_on_dialogue_started)
	npc_dialogue_system.dialogue_node_presented.connect(game_hud.show_dialogue_node)
	npc_dialogue_system.dialogue_actions_presented.connect(game_hud.show_dialogue_actions)
	npc_dialogue_system.dialogue_action_cooldowns_presented.connect(
		game_hud.set_dialogue_action_cooldowns
	)
	npc_dialogue_system.dialogue_action_performed.connect(
		game_hud.show_dialogue_action_result
	)
	npc_dialogue_system.dialogue_finished.connect(_on_dialogue_finished)
	npc_dialogue_system.merchant_requested.connect(_on_merchant_requested)
	npc_dialogue_system.doctor_requested.connect(_on_doctor_requested)
	hunting_system.hunting_mode_changed.connect(_on_hunting_mode_changed)
	inventory.item_changed.connect(game_hud.set_inventory_item)
	inventory.item_changed.connect(_on_inventory_item_changed)
	tool_service.tool_changed.connect(game_hud.set_tool)
	tool_service.tool_changed.connect(_on_tool_changed)
	wallet.balance_changed.connect(game_hud.set_wallet)
	player.vitals_changed.connect(game_hud.set_vitals)
	game_hud.set_vitals(
		player.health,
		player.maximum_health,
		player.stamina,
		player.maximum_stamina
	)
	var equipped_tool := tool_service.equipped_tool()
	if equipped_tool != null:
		game_hud.set_tool(
			equipped_tool,
			tool_service.durability_of(equipped_tool.id)
		)
	game_hud.set_wallet(wallet.balance())
	for item in catalog.item_definitions():
		game_hud.set_inventory_item(item, inventory.quantity_of(item.id))
	_refresh_inventory_tools()
	game_hud.merchant_buy_requested.connect(_on_merchant_buy_requested)
	game_hud.merchant_sell_requested.connect(_on_merchant_sell_requested)
	game_hud.merchant_close_requested.connect(_close_merchant)
	game_hud.doctor_close_requested.connect(_close_doctor)
	game_hud.planting_seed_selected.connect(_on_planting_seed_selected)
	game_hud.planting_close_requested.connect(_close_planting)
	game_hud.inventory_close_requested.connect(_close_inventory)
	game_hud.blacksmith_coin_earned.connect(_on_blacksmith_coin_earned)
	game_hud.blacksmith_close_requested.connect(_close_blacksmith)

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
	mining_system.initialize(interaction_system, inventory, tool_service)
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
	if _create_hotel_runtime() == null:
		_fail_initialization("No se pudo componer el hotel de la aldea.")
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


func _create_hotel_runtime() -> WorldAreaRuntime:
	if catalog.hotel == null:
		return null
	var area := hotel_area_scene.instantiate() as HotelArea
	if area == null:
		push_error("La plantilla de hotel no crea un HotelArea.")
		return null

	area.name = String(catalog.hotel.area_id)
	dynamic_areas.add_child(area)
	area.initialize(catalog.hotel)
	var collision_world := CollisionWorld.new()
	collision_world.configure(
		catalog.hotel.playable_bounds(),
		area.collision_obstacles()
	)
	var runtime := WorldAreaRuntime.new()
	if not runtime.configure(
		catalog.hotel.area_id,
		catalog.hotel.label,
		area,
		area.actor_layer,
		collision_world,
		catalog.hotel.world_rect()
	):
		area.queue_free()
		return null
	if not world_area_system.register_runtime(runtime):
		area.queue_free()
		return null
	area.rest_spot.interaction_requested.connect(_on_hotel_rest_requested)
	interaction_system.register_interactable(area.rest_spot)
	hotel_runtime = runtime
	return runtime


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


func _create_blacksmith_spot() -> void:
	for definition in catalog.house_definitions():
		if definition.id != &"blacksmith":
			continue
		var spot := BlacksmithSpotActor.new()
		spot.configure(definition.world_position + Vector2(0.0, 42.0))
		overworld_actor_layer.add_child(spot)
		spot.interaction_requested.connect(_on_blacksmith_requested)
		interaction_system.register_interactable(spot)
		blacksmith_spot = spot
		return


func _initialize_gameplay_systems() -> void:
	npc_dialogue_system.initialize(
		catalog.npc_definitions(),
		GameCatalog.OVERWORLD_AREA_ID,
		overworld_actor_layer,
		overworld_collision_world,
		interaction_system,
		game_world
	)
	forestry_system.initialize(
		catalog.forest,
		catalog,
		game_world,
		overworld_actor_layer,
		overworld_collision_world,
		interaction_system,
		inventory,
		tool_service
	)
	planting_system.initialize(
		catalog,
		game_world,
		overworld_actor_layer,
		overworld_collision_world,
		inventory,
		forestry_system,
		player
	)
	wildlife.initialize(
		catalog.animal_definitions(),
		overworld_actor_layer,
		overworld_collision_world,
		catalog.playable_bounds(),
		player.camera
	)
	hunting_system.initialize(
		wildlife,
		inventory,
		tool_service,
		catalog.item_definitions()
	)
	interaction_highlight.initialize(catalog, not mobile_build)
	_create_blacksmith_spot()


func _process(delta: float) -> void:
	if (
		not initialized
		or game_paused
		or (
			npc_dialogue_system != null
			and npc_dialogue_system.is_dialogue_active()
		)
		or merchant_service.is_open()
		or doctor_service.is_open()
		or game_hud.is_planting_visible()
		or game_hud.is_inventory_visible()
		or game_hud.is_blacksmith_visible()
		or hotel_sleeping
	):
		return

	player.update_player(delta)
	planting_system.update(delta)
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
	if hotel_sleeping:
		get_viewport().set_input_as_handled()
		return

	if game_hud.is_blacksmith_visible():
		if _is_pause_event(event):
			_close_blacksmith()
			get_viewport().set_input_as_handled()
		return

	if doctor_service.is_open():
		if _is_pause_event(event):
			_close_doctor()
			get_viewport().set_input_as_handled()
		return

	if merchant_service.is_open():
		if _is_pause_event(event):
			_close_merchant()
			get_viewport().set_input_as_handled()
		return

	if npc_dialogue_system != null and npc_dialogue_system.is_dialogue_active():
		if _is_pause_event(event):
			npc_dialogue_system.close_dialogue()
			get_viewport().set_input_as_handled()
		return

	if game_hud.is_planting_visible():
		if _is_pause_event(event):
			_close_planting()
			get_viewport().set_input_as_handled()
		return

	if game_hud.is_inventory_visible():
		if _is_pause_event(event) or _is_inventory_toggle_event(event):
			_close_inventory()
			get_viewport().set_input_as_handled()
		return

	if _is_pause_event(event):
		if game_hud.is_save_confirmation_visible():
			game_hud.cancel_save_confirmation()
		elif game_paused:
			game_hud.resume_game()
		else:
			game_hud.open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if game_paused:
		return
	if _is_inventory_toggle_event(event):
		_open_inventory()
		get_viewport().set_input_as_handled()
		return
	if _is_planting_request_event(event):
		var pointer_position := player.get_global_mouse_position()
		if planting_system.can_plant_at(pointer_position):
			_open_planting(pointer_position)
		get_viewport().set_input_as_handled()
		return
	if _is_hunting_shot_event(event):
		hunting_system.shoot_at(player.get_global_mouse_position())
		get_viewport().set_input_as_handled()
		return
	if _try_equip_tool_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	input_state.handle_event(event)


func _is_pause_event(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (
			event.keycode == KEY_ESCAPE
			or event.physical_keycode == KEY_ESCAPE
		)
	)


func _is_inventory_toggle_event(event: InputEvent) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (
			event.keycode == KEY_R
			or event.physical_keycode == KEY_R
		)
	)


func _try_equip_tool_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	var slot_index := -1
	if event.keycode == KEY_1 or event.physical_keycode == KEY_1:
		slot_index = 0
	elif event.keycode == KEY_2 or event.physical_keycode == KEY_2:
		slot_index = 1
	elif event.keycode == KEY_3 or event.physical_keycode == KEY_3:
		slot_index = 2
	elif event.keycode == KEY_4 or event.physical_keycode == KEY_4:
		slot_index = 3
	elif event.keycode == KEY_5 or event.physical_keycode == KEY_5:
		slot_index = 4
	elif event.keycode == KEY_6 or event.physical_keycode == KEY_6:
		slot_index = 5
	elif event.keycode == KEY_7 or event.physical_keycode == KEY_7:
		slot_index = 6
	elif event.keycode == KEY_8 or event.physical_keycode == KEY_8:
		slot_index = 7
	elif event.keycode == KEY_9 or event.physical_keycode == KEY_9:
		slot_index = 8

	return slot_index >= 0 and tool_service.equip_tool_slot(slot_index)


func _on_pause_state_changed(paused: bool) -> void:
	game_paused = paused
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _on_dialogue_started() -> void:
	mobile_controls_before_dialogue = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	_refresh_hunting_mode_display()


func _on_dialogue_finished() -> void:
	game_hud.hide_dialogue()
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_dialogue)
	_refresh_hunting_mode_display()


func _on_merchant_requested(
	_npc_id: StringName,
	merchant: MerchantDefinition
) -> void:
	if merchant_service.is_open() or not merchant_service.open(merchant):
		return

	mobile_controls_before_merchant = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_merchant(merchant, merchant_service)
	_refresh_hunting_mode_display()


func _on_doctor_requested(
	_npc_id: StringName,
	doctor: DoctorDefinition
) -> void:
	if (
		doctor_service.is_open()
		or merchant_service.is_open()
		or not doctor_service.open(doctor)
	):
		return

	mobile_controls_before_doctor = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_doctor(doctor, doctor_service.consult(player))
	_refresh_hunting_mode_display()


func _on_blacksmith_requested(_target: Node, _source: Node) -> void:
	if (
		game_hud.is_blacksmith_visible()
		or game_paused
		or npc_dialogue_system.is_dialogue_active()
		or merchant_service.is_open()
		or doctor_service.is_open()
		or game_hud.is_planting_visible()
		or game_hud.is_inventory_visible()
	):
		return
	mobile_controls_before_blacksmith = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_blacksmith()
	_refresh_hunting_mode_display()


func _on_blacksmith_coin_earned() -> void:
	wallet.earn(1)
	game_hud.show_notification("Has ganado 1 moneda trabajando en el yunque.")


func _close_blacksmith() -> void:
	if not game_hud.is_blacksmith_visible():
		return
	game_hud.hide_blacksmith()
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_blacksmith)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _on_hotel_rest_requested(_target: Node, _source: Node) -> void:
	if (
		hotel_sleeping
		or game_paused
		or not world_area_system.is_area_active(GameCatalog.HOTEL_AREA_ID)
	):
		return
	hotel_sleeping = true
	mobile_controls_before_hotel_sleep = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	_refresh_hunting_mode_display()
	_sleep_at_hotel()


func _sleep_at_hotel() -> void:
	await game_hud.play_sleep_transition(3.0)
	if not is_inside_tree():
		return
	player.rest()
	hotel_sleeping = false
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_hotel_sleep)
	input_state.reset_virtual_controls()
	game_hud.show_notification("Has descansado en el hotel. Salud y estamina restauradas.")
	_refresh_hunting_mode_display()


func _open_planting(pointer_position: Vector2) -> void:
	if game_hud.is_planting_visible():
		return
	planting_position = planting_system.tile_center_for_world_position(pointer_position)
	mobile_controls_before_planting = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_planting(
		planting_system.cell_for_world_position(pointer_position),
		planting_system.seed_options()
	)
	_refresh_hunting_mode_display()


func _on_planting_seed_selected(seed_id: StringName) -> void:
	if not game_hud.is_planting_visible():
		return
	var plots_before := planting_system.plot_count()
	var message := planting_system.plant_seed(planting_position, seed_id)
	if planting_system.plot_count() > plots_before:
		_close_planting()
	else:
		game_hud.refresh_planting(message)


func _close_planting() -> void:
	if not game_hud.is_planting_visible():
		return
	game_hud.hide_planting()
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_planting)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _open_inventory() -> void:
	if (
		game_hud.is_inventory_visible()
		or game_paused
		or npc_dialogue_system.is_dialogue_active()
		or merchant_service.is_open()
		or doctor_service.is_open()
		or game_hud.is_planting_visible()
		or game_hud.is_blacksmith_visible()
	):
		return
	mobile_controls_before_inventory = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_inventory()
	_refresh_hunting_mode_display()


func _close_inventory() -> void:
	if not game_hud.is_inventory_visible():
		return
	game_hud.hide_inventory()
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_inventory)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _on_merchant_buy_requested(offer_id: StringName) -> void:
	if not merchant_service.is_open():
		return
	game_hud.refresh_merchant(merchant_service.buy(offer_id))


func _on_merchant_sell_requested(offer_id: StringName) -> void:
	if not merchant_service.is_open():
		return
	game_hud.refresh_merchant(merchant_service.sell(offer_id))


func _close_merchant() -> void:
	if not merchant_service.is_open():
		return
	merchant_service.close()
	game_hud.hide_merchant()
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_merchant)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _close_doctor() -> void:
	if not doctor_service.is_open():
		return
	doctor_service.close()
	game_hud.hide_doctor()
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_doctor)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _on_hunting_mode_changed(_active: bool) -> void:
	_refresh_hunting_mode_display()


func _on_tool_changed(_tool: ToolDefinition, _durability: int) -> void:
	hunting_system.refresh_mode()
	_refresh_inventory_tools()
	_refresh_hunting_mode_display()


func _refresh_inventory_tools() -> void:
	if game_hud == null or catalog == null:
		return
	var equipped_tool_id := tool_service.equipped_tool_id()
	for tool in catalog.tool_definitions():
		game_hud.set_inventory_tool(
			tool,
			tool_service.durability_of(tool.id),
			tool_service.has_tool(tool.id),
			tool.id == equipped_tool_id
		)


func _on_inventory_item_changed(_item: ItemDefinition, _quantity: int) -> void:
	hunting_system.refresh_mode()
	_refresh_hunting_mode_display()


func _refresh_hunting_mode_display() -> void:
	if game_hud == null or hunting_system == null:
		return
	var visible := (
		initialized
		and not mobile_build
		and hunting_system.is_hunting_mode()
		and world_area_system.is_area_active(GameCatalog.OVERWORLD_AREA_ID)
		and not game_paused
		and not npc_dialogue_system.is_dialogue_active()
		and not merchant_service.is_open()
		and not doctor_service.is_open()
		and not game_hud.is_planting_visible()
		and not game_hud.is_inventory_visible()
		and not game_hud.is_blacksmith_visible()
		and not hotel_sleeping
	)
	game_hud.set_hunting_mode(visible)


func _is_hunting_shot_event(event: InputEvent) -> bool:
	return (
		hunting_system != null
		and hunting_system.is_hunting_mode()
		and world_area_system.is_area_active(GameCatalog.OVERWORLD_AREA_ID)
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and not game_paused
	)


func _is_planting_request_event(event: InputEvent) -> bool:
	return (
		not mobile_build
		and world_area_system.is_area_active(GameCatalog.OVERWORLD_AREA_ID)
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	)


func _on_area_changed(area_id: StringName, label: String) -> void:
	game_hud.set_location(label)
	interaction_highlight.set_enabled(
		not mobile_build and area_id == GameCatalog.OVERWORLD_AREA_ID
	)
	_refresh_hunting_mode_display()
	if initialized and not mobile_build:
		_update_debug()


func _update_debug() -> void:
	var fps := float(Engine.get_frames_per_second())
	var cpu_process_ms := maxf(
		0.0,
		float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	)
	var frame_budget_ms := 1000.0 / fps if fps > 0.0 else 0.0
	var cpu_frame_percent := (
		cpu_process_ms / frame_budget_ms * 100.0
		if frame_budget_ms > 0.0
		else 0.0
	)
	var gpu_memory_bytes := float(
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	)
	var gpu_draw_calls := int(
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	)

	game_hud.update_debug({
		"fps": fps,
		"cpu_process_ms": cpu_process_ms,
		"cpu_frame_percent": cpu_frame_percent,
		"gpu_memory_bytes": gpu_memory_bytes,
		"gpu_draw_calls": gpu_draw_calls,
		"memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"entities": (
			1
			+ game_world.house_count()
			+ wildlife.animal_count()
			+ forestry_system.tree_count()
			+ mining_system.vein_count()
			+ world_area_system.portal_count()
			+ npc_dialogue_system.npc_count()
		),
		"objects": (
			game_world.house_count()
			+ game_world.path_tile_count()
			+ forestry_system.tree_count()
			+ planting_system.plot_count()
			+ mining_system.vein_count()
			+ _mine_static_obstacle_count()
			+ world_area_system.portal_count()
			+ npc_dialogue_system.npc_count()
		),
		"area": world_area_system.active_area_id(),
		"houses": game_world.house_count(),
		"npcs": npc_dialogue_system.npc_count(),
		"animals": wildlife.animal_count(),
		"trees": forestry_system.active_tree_count(),
		"plantings": planting_system.plot_count(),
		"veins": mining_system.active_vein_count(),
		"path_tiles": game_world.path_tile_count(),
		"particles": player.run_cloud_count()
	})


func _on_save_confirmed(exit_after_save: bool) -> void:
	var saved := save_game_service.save_game(_snapshot_game())
	if exit_after_save:
		if not saved:
			push_error("No se pudo guardar antes de salir del juego.")
		get_tree().quit()
		return
	game_hud.show_save_result(
		saved,
		"Partida guardada." if saved else "No se pudo guardar la partida."
	)


func _on_save_cancelled(exit_after_save: bool) -> void:
	if not exit_after_save:
		return
	get_tree().quit()


func _snapshot_game() -> Dictionary:
	var player_snapshot := player.snapshot()
	player_snapshot["x"] = player.global_position.x
	player_snapshot["y"] = player.global_position.y
	return {
		"area": String(world_area_system.active_area_id()),
		"player": player_snapshot,
		"inventory": inventory.snapshot(),
		"tools": tool_service.snapshot(),
		"wallet": wallet.snapshot(),
		"trees": forestry_system.snapshot(),
		"plantings": planting_system.snapshot(),
		"veins": mining_system.snapshot(),
		"dialogues": npc_dialogue_system.snapshot(),
		"affinity": npc_dialogue_system.affinity_snapshot(),
		"action_cooldowns": npc_dialogue_system.action_cooldown_snapshot()
	}


func _load_saved_game() -> void:
	if SMOKE_TEST_ARGUMENT in OS.get_cmdline_user_args():
		return

	var snapshot := save_game_service.load_game()
	if snapshot.is_empty():
		return

	var area_id := StringName(
		str(snapshot.get("area", GameCatalog.OVERWORLD_AREA_ID))
	)
	if world_area_system.area_runtime(area_id) == null:
		push_warning(
			"La partida guardada apunta al área '%s'; se cargará la aldea."
			% area_id
		)
		area_id = GameCatalog.OVERWORLD_AREA_ID

	var fallback_position := catalog.player_spawn
	if area_id != GameCatalog.OVERWORLD_AREA_ID:
		var mine := catalog.mine_for_area(area_id)
		if mine != null:
			fallback_position = mine.player_spawn
		elif catalog.hotel != null and area_id == catalog.hotel.area_id:
			fallback_position = catalog.hotel.player_spawn
	var saved_player := snapshot.get("player", {}) as Dictionary
	var player_position := Vector2(
		float(saved_player.get("x", fallback_position.x)),
		float(saved_player.get("y", fallback_position.y))
	)

	if world_area_system.active_area_id() == area_id:
		player.position = player_position
	else:
		world_area_system.transition_to(area_id, player_position)
	player.restore(saved_player)

	var saved_inventory: Variant = snapshot.get("inventory", {})
	if saved_inventory is Dictionary:
		inventory.restore(saved_inventory as Dictionary)
	var saved_wallet: Variant = snapshot.get("wallet", {})
	if saved_wallet is Dictionary:
		wallet.restore(saved_wallet as Dictionary)
	var saved_tools: Variant = snapshot.get("tools", {})
	if saved_tools is Dictionary:
		tool_service.restore(saved_tools as Dictionary)
	var saved_trees: Variant = snapshot.get("trees", [])
	if saved_trees is Array:
		forestry_system.restore(saved_trees as Array)
	var saved_plantings: Variant = snapshot.get("plantings", [])
	if saved_plantings is Array:
		planting_system.restore(saved_plantings as Array)
	var saved_veins: Variant = snapshot.get("veins", [])
	if saved_veins is Array:
		mining_system.restore(saved_veins as Array)
	var saved_dialogues: Variant = snapshot.get("dialogues", {})
	if saved_dialogues is Dictionary:
		npc_dialogue_system.restore(saved_dialogues as Dictionary)
	var saved_affinity: Variant = snapshot.get("affinity", {})
	if saved_affinity is Dictionary:
		npc_dialogue_system.restore_affinity(saved_affinity as Dictionary)
	var saved_action_cooldowns: Variant = snapshot.get("action_cooldowns", {})
	if saved_action_cooldowns is Dictionary:
		npc_dialogue_system.restore_action_cooldowns(
			saved_action_cooldowns as Dictionary
		)


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
		npc_dialogue_system,
		tool_service,
		wallet,
		merchant_service,
		doctor_service,
		planting_system,
		wildlife,
		hunting_system,
		player,
		game_hud,
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
