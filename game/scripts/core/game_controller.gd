extends Node2D
class_name GameController

const CONTROL_SETTINGS_SCRIPT = preload("res://scripts/core/control_settings.gd")
const SMOKE_TEST_ARGUMENT := "--smoke-test"
const PLANTING_CONTEXT_MAX_DISTANCE := 128.0
const WOODCUTTING_STUMP_POSITION := Vector2(360.0, 1368.0)
const RUINED_HOUSE_POSITION := Vector2(-900.0, -720.0)

@export var catalog: GameCatalog
@export var mine_area_scene: PackedScene
@export var hotel_area_scene: PackedScene
@export var woodcutting_stump_scene: PackedScene
@export var ruined_house_scene: PackedScene

@onready var dynamic_areas: Node2D = %DynamicAreas
@onready var overworld_area: Node2D = %OverworldArea
@onready var game_world: GameWorld = %GameWorld
@onready var ground_decoration_layer: GroundDecorationLayer = %GroundDecorations
@onready var interaction_highlight: InteractionHighlight = %InteractionHighlight
@onready var ground_actor_layer: Node2D = %GroundActorLayer
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
var repaired_house_runtime: WorldAreaRuntime
var control_settings = CONTROL_SETTINGS_SCRIPT.new()
var input_state := InputState.new()
var inventory := InventoryService.new()
var sound_service := SoundService.new()
var tool_service := ToolService.new()
var wallet := WalletService.new()
var merchant_service := MerchantService.new()
var doctor_service := DoctorService.new()
var planting_system := PlantingSystem.new()
var temperature_system := TemperatureSystem.new()
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
var mobile_controls_before_woodcutting := false
var mobile_controls_before_cooking := false
var mobile_controls_before_recipe_cooking := false
var mobile_controls_before_hotel_sleep := false
var hotel_sleeping := false
var sleeping_area_label := "el hotel"
var planting_position := Vector2.ZERO
var context_position := Vector2.ZERO
var cooking_vegetable_id: StringName = &""
var cooking_recipe_id: StringName = &""
var blacksmith_spot: BlacksmithSpotActor
var woodcutting_stump: WoodcuttingStumpActor
var ruined_house: RuinedHouseActor
var _anvil_bars_completed := 0


func _ready() -> void:
	if not _validate_configuration():
		return

	temperature_system.initialize(
		catalog.temperature_minimum,
		catalog.temperature_maximum,
		catalog.temperature_cycle_duration
	)
	RenderingServer.set_default_clear_color(catalog.grass_color)
	mobile_build = OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")
	add_child(sound_service)

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
	if ruined_house_scene == null:
		_fail_initialization("La escena no tiene una plantilla de casa derruida.")
		return false

	var validation_errors := catalog.validate()
	if not validation_errors.is_empty():
		_fail_initialization("\n".join(validation_errors))
		return false
	return true


func _initialize_world() -> void:
	game_world.initialize(catalog, overworld_actor_layer, player.camera)
	overworld_collision_world.configure(
		catalog.playable_bounds(),
		game_world.collision_obstacles()
	)
	inventory.register_items(catalog.item_definitions())
	ground_decoration_layer.initialize(
		game_world,
		catalog,
		interaction_system,
		inventory
	)
	tool_service.initialize(catalog.tool_definitions(), catalog.default_tool_id)
	wallet.initialize(catalog.starting_coins)
	merchant_service.initialize(inventory, wallet, tool_service)
	doctor_service.initialize(wallet, inventory)


func _initialize_interface() -> void:
	game_hud.initialize(mobile_build, catalog.player_max_stamina)
	game_hud.set_control_settings(control_settings)
	temperature_system.temperature_changed.connect(game_hud.set_temperature)
	game_hud.set_temperature(temperature_system.current_temperature())
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
	game_hud.doctor_diagnosis_requested.connect(_on_doctor_diagnosis_requested)
	game_hud.doctor_bandage_purchase_requested.connect(
		_on_doctor_bandage_purchase_requested
	)
	hunting_system.hunting_mode_changed.connect(_on_hunting_mode_changed)
	hunting_system.hunting_weapon_changed.connect(_on_hunting_weapon_changed)
	mining_system.stone_dropped.connect(_on_mining_stone_dropped)
	inventory.item_changed.connect(game_hud.set_inventory_item)
	inventory.item_changed.connect(_on_inventory_item_changed)
	ground_decoration_layer.stone_picked.connect(_on_ground_stone_picked)
	tool_service.tool_changed.connect(game_hud.set_tool)
	tool_service.tool_changed.connect(_on_tool_changed)
	wallet.balance_changed.connect(game_hud.set_wallet)
	player.vitals_changed.connect(game_hud.set_vitals)
	game_hud.set_vitals(
		player.health,
		player.maximum_health,
		player.stamina,
		player.maximum_stamina,
		player.stamina_cap,
		player.thirst,
		player.maximum_thirst
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
	game_hud.planting_context_plant_requested.connect(
		_on_planting_context_plant_requested
	)
	game_hud.water_context_drink_requested.connect(
		_on_water_context_drink_requested
	)
	game_hud.inventory_close_requested.connect(_close_inventory)
	game_hud.inventory_item_use_requested.connect(_on_inventory_item_use_requested)
	game_hud.blacksmith_coin_earned.connect(_on_blacksmith_coin_earned)
	game_hud.blacksmith_close_requested.connect(_close_blacksmith)
	game_hud.blacksmith_repair_requested.connect(_on_blacksmith_repair_requested)
	game_hud.blacksmith_repair_tool_requested.connect(_on_blacksmith_repair_tool_requested)
	game_hud.blacksmith_repair_close_requested.connect(_close_blacksmith_repair)
	game_hud.woodcutting_coin_earned.connect(_on_woodcutting_coin_earned)
	game_hud.woodcutting_close_requested.connect(_close_woodcutting)
	game_hud.kitchen_seed_extraction_requested.connect(
		_on_kitchen_seed_extraction_requested
	)
	game_hud.kitchen_cooking_requested.connect(_on_kitchen_cooking_requested)
	game_hud.cooking_vegetable_selected.connect(_on_cooking_vegetable_selected)
	game_hud.cooking_seed_extraction_finished.connect(
		_on_cooking_seed_extraction_finished
	)
	game_hud.cooking_close_requested.connect(_close_cooking)
	game_hud.recipe_cooking_selected.connect(_on_recipe_cooking_selected)
	game_hud.recipe_cooking_finished.connect(_on_recipe_cooking_finished)
	game_hud.recipe_cooking_close_requested.connect(_close_recipe_cooking)
	game_hud.volume_changed.connect(_on_volume_changed)
	game_hud.volume_preview_requested.connect(_on_volume_preview_requested)
	game_hud.options_closed.connect(_on_options_closed)
	game_hud.set_volume_values(
		sound_service.master_volume(),
		sound_service.sfx_volume()
	)

	mobile_controls.direction_changed.connect(input_state.set_virtual_direction)
	mobile_controls.sprint_changed.connect(input_state.set_virtual_sprinting)
	mobile_controls.primary_action_pressed.connect(input_state.request_interaction)
	game_hud.mobile_controls_toggled.connect(mobile_controls.set_enabled)
	mobile_controls.set_enabled(mobile_build)


func _initialize_player_and_interactions() -> void:
	input_state.configure(control_settings)
	player.initialize(catalog, overworld_collision_world, input_state)
	game_world.refresh_camera_culling()
	player.set_ambient_temperature(temperature_system.current_temperature())
	player.sound_service = sound_service
	interaction_system.prompt_changed.connect(game_hud.set_interaction_prompt)
	interaction_system.prompt_changed.connect(mobile_controls.set_primary_action)
	interaction_system.initialize(player, input_state)
	for house in game_world.houses:
		house.interaction_requested.connect(_on_house_interaction_requested)
		interaction_system.register_interactable(house)


func _initialize_areas() -> bool:
	world_area_system.initialize(player, interaction_system)
	mining_system.initialize(interaction_system, inventory, tool_service)
	mining_system.sound_service = sound_service
	game_hud.blacksmith_panel.sound_service = sound_service
	game_hud.woodcutting_panel.sound_service = sound_service
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
	if _create_repaired_house_runtime() == null:
		_fail_initialization("No se pudo componer el interior de la casa reparada.")
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
	hotel_runtime = _create_interior_runtime(catalog.hotel)
	return hotel_runtime


func _create_repaired_house_runtime() -> WorldAreaRuntime:
	if catalog.repaired_house_interior == null:
		return null
	repaired_house_runtime = _create_interior_runtime(catalog.repaired_house_interior)
	return repaired_house_runtime


func _create_interior_runtime(definition: HotelDefinition) -> WorldAreaRuntime:
	if definition == null:
		return null
	var area := hotel_area_scene.instantiate() as HotelArea
	if area == null:
		push_error("La plantilla de interior no crea un HotelArea.")
		return null

	area.name = String(definition.area_id)
	dynamic_areas.add_child(area)
	area.initialize(definition)
	var collision_world := CollisionWorld.new()
	collision_world.configure(
		definition.playable_bounds(),
		area.collision_obstacles()
	)
	var runtime := WorldAreaRuntime.new()
	if not runtime.configure(
		definition.area_id,
		definition.label,
		area,
		area.actor_layer,
		collision_world,
		definition.world_rect()
	):
		area.queue_free()
		return null
	if not world_area_system.register_runtime(runtime):
		area.queue_free()
		return null
	area.rest_spot.interaction_requested.connect(_on_hotel_rest_requested)
	interaction_system.register_interactable(area.rest_spot)
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


func _create_woodcutting_stump() -> void:
	if woodcutting_stump_scene == null:
		push_error("La escena no tiene una plantilla de tocón para cortar madera.")
		return

	var stump := woodcutting_stump_scene.instantiate() as WoodcuttingStumpActor
	if stump == null:
		push_error("La plantilla de corte no crea un WoodcuttingStumpActor.")
		return

	stump.configure(WOODCUTTING_STUMP_POSITION)
	overworld_actor_layer.add_child(stump)
	game_world.register_placement_reservation(
		stump.collision_key(),
		stump.placement_rectangle()
	)
	overworld_collision_world.register_obstacle(
		stump.collision_key(),
		stump.collision_rectangle()
	)
	stump.interaction_requested.connect(_on_woodcutting_stump_requested)
	interaction_system.register_interactable(stump)
	woodcutting_stump = stump


func _create_ruined_house() -> void:
	if ruined_house_scene == null:
		push_error("La escena no tiene una plantilla de casa derruida.")
		return

	var house := ruined_house_scene.instantiate() as RuinedHouseActor
	if house == null:
		push_error("La plantilla de casa derruida no crea un RuinedHouseActor.")
		return

	house.configure(RUINED_HOUSE_POSITION)
	overworld_actor_layer.add_child(house)
	game_world.register_placement_reservation(
		house.collision_key(),
		house.placement_rectangle()
	)
	overworld_collision_world.register_obstacle(
		house.collision_key(),
		house.collision_rectangle()
	)
	house.interaction_requested.connect(_on_ruined_house_interaction_requested)
	interaction_system.register_interactable(house)
	ruined_house = house


func _initialize_gameplay_systems() -> void:
	_create_woodcutting_stump()
	_create_ruined_house()
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
	forestry_system.sound_service = sound_service
	planting_system.initialize(
		catalog,
		game_world,
		ground_actor_layer,
		overworld_collision_world,
		inventory,
		forestry_system,
		player,
		interaction_system
	)
	planting_system.crop_harvested.connect(_on_crop_harvested)
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
	if not initialized or game_paused:
		return
	if (
		(
			npc_dialogue_system != null
			and npc_dialogue_system.is_dialogue_active()
		)
		or merchant_service.is_open()
		or doctor_service.is_open()
		or game_hud.is_planting_visible()
		or game_hud.is_inventory_visible()
		or game_hud.is_blacksmith_visible()
		or game_hud.is_blacksmith_repair_visible()
		or game_hud.is_woodcutting_visible()
		or game_hud.is_cooking_visible()
		or game_hud.is_recipe_cooking_visible()
		or hotel_sleeping
	):
		player.advance_healing(delta)
		return

	temperature_system.update(delta)
	player.set_ambient_temperature(temperature_system.current_temperature())
	player.update_player(delta)
	if (
		game_hud.is_planting_context_visible()
		and player.global_position.distance_to(context_position)
		> PLANTING_CONTEXT_MAX_DISTANCE
	):
		_hide_planting_context_menu()
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if sound_service != null:
			sound_service.save_settings()
		if control_settings != null:
			control_settings.save_settings()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and input_state != null:
		input_state.reset_virtual_controls()


func _unhandled_input(event: InputEvent) -> void:
	if not initialized or not is_instance_valid(game_hud):
		return

	if hotel_sleeping:
		get_viewport().set_input_as_handled()
		return

	if game_hud.is_blacksmith_repair_visible():
		if _is_pause_event(event):
			_close_blacksmith_repair()
			get_viewport().set_input_as_handled()
		return

	if game_hud.is_control_remap_visible():
		if _is_pause_event(event):
			game_hud.close_control_remap()
			get_viewport().set_input_as_handled()
		return

	if game_hud.is_cooking_visible():
		if _is_pause_event(event):
			_close_cooking()
			get_viewport().set_input_as_handled()
		return

	if game_hud.is_recipe_cooking_visible():
		if _is_pause_event(event):
			_close_recipe_cooking()
			get_viewport().set_input_as_handled()
		return

	if game_hud.is_woodcutting_visible():
		if _is_pause_event(event):
			_close_woodcutting()
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

	if game_hud.is_planting_context_visible():
		if _is_pause_event(event):
			_hide_planting_context_menu()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed:
			if control_settings.matches_event(&"primary_action", event):
				_hide_planting_context_menu()
				get_viewport().set_input_as_handled()
				return
			if control_settings.matches_event(&"terrain_action", event):
				_hide_planting_context_menu()

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
		elif game_hud.is_controls_visible():
			game_hud.close_controls()
		elif game_hud.is_options_visible():
			game_hud.close_options()
		elif game_paused:
			game_hud.resume_game()
		else:
			game_hud.open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if game_paused:
		return
	if _is_hunting_toggle_event(event):
		if hunting_system.can_hunt():
			hunting_system.toggle_mode()
		else:
			game_hud.show_notification("Necesitas flechas con arco o una piedra para cazar.")
		get_viewport().set_input_as_handled()
		return
	if _is_hunting_weapon_select_event(event):
		_select_hunting_weapon(event)
		get_viewport().set_input_as_handled()
		return
	if _is_hunting_weapon_wheel_event(event):
		_cycle_hunting_weapon()
		get_viewport().set_input_as_handled()
		return
	if _is_hunting_weapon_cycle_event(event):
		_cycle_hunting_weapon()
		get_viewport().set_input_as_handled()
		return
	if _is_inventory_toggle_event(event):
		_open_inventory()
		get_viewport().set_input_as_handled()
		return
	if _is_blacksmith_context_request_event(event):
		var blacksmith_pointer := player.get_global_mouse_position()
		if _can_open_blacksmith_context(blacksmith_pointer):
			_show_blacksmith_context_menu()
			get_viewport().set_input_as_handled()
			return
	if _is_kitchen_context_request_event(event):
		var kitchen_pointer := player.get_global_mouse_position()
		if _can_open_kitchen_context(kitchen_pointer):
			_show_kitchen_context_menu()
			get_viewport().set_input_as_handled()
			return
	if _is_grid_context_request_event(event):
		var pointer_position := player.get_global_mouse_position()
		var clicked_cell := game_world.cell_for_world_position(pointer_position)
		if game_world.is_water_tile(clicked_cell):
			_show_water_context_menu(pointer_position)
		elif planting_system.can_plant_at(pointer_position):
			_show_planting_context_menu(pointer_position)
		get_viewport().set_input_as_handled()
		return
	if _is_hunting_shot_event(event):
		hunting_system.shoot_at(player.get_global_mouse_position())
		get_viewport().set_input_as_handled()
		return
	if _is_tree_chop_event(event):
		if (
			interaction_system.interact_current_tree()
			or interaction_system.interact_current_stone()
		):
			get_viewport().set_input_as_handled()
		return
	if _try_equip_tool_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	input_state.handle_event(event)


func _is_pressed_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false


func _is_pause_event(event: InputEvent) -> bool:
	return (
		_is_pressed_event(event)
		and control_settings.matches_event(&"pause", event)
	)


func _is_inventory_toggle_event(event: InputEvent) -> bool:
	return (
		_is_pressed_event(event)
		and control_settings.matches_event(&"inventory", event)
	)


func _is_hunting_toggle_event(event: InputEvent) -> bool:
	return (
		not mobile_build
		and _is_pressed_event(event)
		and control_settings.matches_event(&"hunting_toggle", event)
	)


func _is_hunting_weapon_select_event(event: InputEvent) -> bool:
	return (
		hunting_system != null
		and hunting_system.is_hunting_mode()
		and _is_pressed_event(event)
		and (
			control_settings.matches_event(&"hunting_weapon_1", event)
			or control_settings.matches_event(&"hunting_weapon_2", event)
		)
	)


func _is_hunting_weapon_wheel_event(event: InputEvent) -> bool:
	return (
		hunting_system != null
		and hunting_system.is_hunting_mode()
		and _is_pressed_event(event)
		and control_settings.matches_event(&"hunting_weapon_cycle", event)
		and event is InputEventMouseButton
	)


func _is_hunting_weapon_cycle_event(event: InputEvent) -> bool:
	return (
		hunting_system != null
		and hunting_system.is_hunting_mode()
		and event is InputEventKey
		and _is_pressed_event(event)
		and control_settings.matches_event(&"hunting_weapon_cycle", event)
	)


func _cycle_hunting_weapon() -> void:
	if hunting_system.cycle_projectile():
		game_hud.show_notification(
			"Arma de caza: %s." % hunting_system.selected_projectile_label()
		)


func _select_hunting_weapon(event: InputEvent) -> void:
	var projectile_id := (
		HuntingSystem.ARROWS_ID
		if control_settings.matches_event(&"hunting_weapon_1", event)
		else HuntingSystem.STONE_ID
	)
	if hunting_system.select_projectile(projectile_id):
		game_hud.show_notification(
			"Arma de caza: %s." % hunting_system.selected_projectile_label()
		)
	else:
		game_hud.show_notification("Ese proyectil no está disponible.")


func _try_equip_tool_shortcut(event: InputEvent) -> bool:
	if not _is_pressed_event(event):
		return false

	for slot_index in range(9):
		var action_id := StringName("tool_slot_%d" % (slot_index + 1))
		if control_settings.matches_event(action_id, event):
			return tool_service.equip_tool_slot(slot_index)
	return false


func _on_pause_state_changed(paused: bool) -> void:
	game_paused = paused
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _on_dialogue_started() -> void:
	_hide_planting_context_menu()
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
	_hide_planting_context_menu()

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
	_hide_planting_context_menu()

	mobile_controls_before_doctor = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_doctor(doctor, doctor_service)
	_refresh_hunting_mode_display()


func _on_doctor_diagnosis_requested() -> void:
	if not doctor_service.is_open():
		return
	var doctor := doctor_service.active_doctor()
	if doctor == null:
		return
	game_hud.show_doctor_report(doctor, doctor_service.consult(player))


func _on_doctor_bandage_purchase_requested() -> void:
	if not doctor_service.is_open():
		return
	game_hud.show_doctor_purchase_result(doctor_service.buy_bandage())


func _on_blacksmith_requested(_target: Node, _source: Node) -> void:
	if (
		game_hud.is_blacksmith_visible()
		or game_hud.is_blacksmith_repair_visible()
		or game_hud.is_woodcutting_visible()
		or game_hud.is_cooking_visible()
		or game_hud.is_recipe_cooking_visible()
		or game_paused
		or npc_dialogue_system.is_dialogue_active()
		or merchant_service.is_open()
		or doctor_service.is_open()
		or game_hud.is_planting_visible()
		or game_hud.is_inventory_visible()
	):
		return
	_hide_planting_context_menu()
	mobile_controls_before_blacksmith = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.blacksmith_panel.set_bars_completed(_anvil_bars_completed)
	game_hud.show_blacksmith()
	_refresh_hunting_mode_display()


func _on_blacksmith_repair_requested() -> void:
	if not game_hud.is_planting_context_visible():
		return
	_hide_planting_context_menu()
	if not _is_near_blacksmith():
		game_hud.show_notification("Debes estar junto a la herrería para reparar.")
		return
	if game_hud.is_blacksmith_repair_visible() or game_hud.is_blacksmith_visible():
		return

	mobile_controls_before_blacksmith = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_blacksmith_repair(
		tool_service.repair_options(),
		wallet.balance()
	)
	_refresh_hunting_mode_display()


func _on_blacksmith_repair_tool_requested(tool_id: StringName) -> void:
	if not game_hud.is_blacksmith_repair_visible():
		return

	var tool := tool_service.tool_for(tool_id)
	var cost := tool_service.repair_cost_for(tool_id)
	if tool == null or cost <= 0:
		game_hud.refresh_blacksmith_repair(
			tool_service.repair_options(),
			wallet.balance(),
			"Esa herramienta no necesita reparación.",
			false
		)
		return
	if not wallet.can_afford(cost):
		game_hud.refresh_blacksmith_repair(
			tool_service.repair_options(),
			wallet.balance(),
			"No tienes suficientes monedas para reparar %s." % tool.label,
			false
		)
		return
	if not wallet.spend(cost):
		return
	if not tool_service.repair_tool(tool_id):
		wallet.earn(cost)
		game_hud.refresh_blacksmith_repair(
			tool_service.repair_options(),
			wallet.balance(),
			"No se pudo reparar %s." % tool.label,
			false
		)
		return

	game_hud.refresh_blacksmith_repair(
		tool_service.repair_options(),
		wallet.balance(),
		"Has reparado %s por %d monedas." % [tool.label, cost],
		true
	)


func _on_woodcutting_stump_requested(_target: Node, _source: Node) -> void:
	if (
		game_hud.is_woodcutting_visible()
		or game_hud.is_blacksmith_visible()
		or game_hud.is_blacksmith_repair_visible()
		or game_hud.is_cooking_visible()
		or game_hud.is_recipe_cooking_visible()
		or game_paused
		or npc_dialogue_system.is_dialogue_active()
		or merchant_service.is_open()
		or doctor_service.is_open()
		or game_hud.is_planting_visible()
		or game_hud.is_inventory_visible()
	):
		return
	_hide_planting_context_menu()
	mobile_controls_before_woodcutting = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_woodcutting()
	_refresh_hunting_mode_display()


func _on_house_interaction_requested(target: Node2D, _source: Node2D) -> void:
	var house := target as HouseActor
	if house == null or house.definition == null:
		return

	var entrance := _entrance_portal_for_house(house)
	if entrance != null and world_area_system.transition_to(
		entrance.target_area_id,
		entrance.target_position
	):
		return

	game_hud.show_notification("Cerrada")


func _on_ruined_house_interaction_requested(target: Node2D, _source: Node2D) -> void:
	var house := target as RuinedHouseActor
	if house == null:
		return
	if house.is_repaired():
		if (
			catalog.repaired_house_interior != null
			and world_area_system.transition_to(
				catalog.repaired_house_interior.area_id,
				catalog.repaired_house_interior.player_spawn
			)
		):
			return
		game_hud.show_notification("Cerrada")
		return
	if not wallet.spend(RuinedHouseActor.REPAIR_COST):
		game_hud.show_notification("Necesitas 750 monedas para reparar esta casa.")
		return

	house.set_repaired(true)
	game_hud.show_notification("Casa reparada por 750 monedas. Puedes entrar en ella.")


func _entrance_portal_for_house(house: HouseActor) -> AreaPortalDefinition:
	if house == null or catalog == null:
		return null
	for portal in catalog.portal_definitions():
		if (
			portal.source_area_id == GameCatalog.OVERWORLD_AREA_ID
			and house.global_position.distance_to(portal.world_position)
			<= catalog.tile_size
		):
			return portal
	return null


func _on_blacksmith_coin_earned() -> void:
	wallet.earn(1)
	game_hud.show_notification("Has ganado 1 moneda trabajando en el yunque.")
	_anvil_bars_completed += 1
	game_hud.blacksmith_panel.set_bars_completed(_anvil_bars_completed)
	_maybe_reward_pickaxe()


func _on_woodcutting_coin_earned() -> void:
	wallet.earn(1)
	game_hud.show_notification("Has ganado 1 moneda cortando madera.")


func _maybe_reward_pickaxe() -> void:
	var target_bars := game_hud.blacksmith_panel.PICKAXE_BARS
	if _anvil_bars_completed < target_bars:
		return
	if not tool_service.can_acquire_tool(&"pickaxe"):
		return
	if tool_service.acquire_tool(&"pickaxe"):
		game_hud.show_notification(
			"¡El herrero te ha forjado un Pico por completar %d barras!"
			% target_bars
		)


func _on_volume_changed(master_volume: float, sfx_volume: float) -> void:
	sound_service.set_master_volume(master_volume)
	sound_service.set_sfx_volume(sfx_volume)


func _on_volume_preview_requested() -> void:
	sound_service.play_ui_click()


func _on_options_closed() -> void:
	sound_service.save_settings()


func _close_blacksmith() -> void:
	if not game_hud.is_blacksmith_visible():
		return
	game_hud.hide_blacksmith()
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_blacksmith)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _close_blacksmith_repair() -> void:
	if not game_hud.is_blacksmith_repair_visible():
		return
	game_hud.hide_blacksmith_repair()
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_blacksmith)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _close_woodcutting() -> void:
	if not game_hud.is_woodcutting_visible():
		return
	game_hud.hide_woodcutting()
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_woodcutting)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _on_kitchen_seed_extraction_requested() -> void:
	if not game_hud.is_planting_context_visible():
		return
	_hide_planting_context_menu()
	if not _is_near_kitchen():
		game_hud.show_notification("Debes estar junto a la cocina para preparar semillas.")
		return
	if (
		game_hud.is_cooking_visible()
		or game_hud.is_recipe_cooking_visible()
		or game_hud.is_blacksmith_visible()
		or game_hud.is_blacksmith_repair_visible()
		or game_hud.is_woodcutting_visible()
	):
		return

	mobile_controls_before_cooking = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_cooking(_cooking_options())
	_refresh_hunting_mode_display()


func _on_cooking_vegetable_selected(vegetable_id: StringName) -> void:
	if not game_hud.is_cooking_visible():
		return
	var seed_id := _cooking_seed_id_for(vegetable_id)
	var vegetable := inventory.definition_for(vegetable_id)
	var seed := inventory.definition_for(seed_id)
	if seed_id == StringName() or vegetable == null or seed == null:
		game_hud.show_notification("Ese vegetal no se puede preparar.")
		return
	if not inventory.has_item(vegetable_id):
		game_hud.show_notification("No tienes %s para cortar." % vegetable.label.to_lower())
		return
	if inventory.space_for(seed_id) < 2:
		game_hud.show_notification("Necesitas espacio para guardar las dos semillas.")
		return
	if inventory.remove_item(vegetable_id, 1) != 1:
		game_hud.show_notification("No se pudo preparar el vegetal.")
		return

	cooking_vegetable_id = vegetable_id
	game_hud.start_cooking(vegetable_id)


func _on_cooking_seed_extraction_finished(
	vegetable_id: StringName,
	success: bool
) -> void:
	if not game_hud.is_cooking_visible() or vegetable_id != cooking_vegetable_id:
		return
	if not success:
		game_hud.show_cooking_result(
			"No has obtenido semillas. El vegetal se ha gastado en el intento.",
			false
		)
		return

	var seed_id := _cooking_seed_id_for(vegetable_id)
	var seed := inventory.definition_for(seed_id)
	if seed == null:
		game_hud.show_cooking_result("No se encontró la semilla correspondiente.", false)
		return
	var added := inventory.add_item(seed, 2)
	if added == 2:
		game_hud.show_cooking_result(
			"¡Centro intacto! Has obtenido 2 semillas de %s." % seed.label.to_lower(),
			true
		)
		game_hud.show_notification("Has obtenido 2 semillas de %s." % seed.label.to_lower())
	else:
		game_hud.show_cooking_result(
			"Solo has podido guardar %d semillas por falta de espacio." % added,
			added > 0
		)


func _close_cooking() -> void:
	if not game_hud.is_cooking_visible():
		return
	game_hud.hide_cooking()
	cooking_vegetable_id = &""
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_cooking)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _on_kitchen_cooking_requested() -> void:
	if not game_hud.is_planting_context_visible():
		return
	_hide_planting_context_menu()
	if not _is_near_kitchen():
		game_hud.show_notification("Debes estar junto a la cocina para cocinar.")
		return
	if (
		game_hud.is_cooking_visible()
		or game_hud.is_recipe_cooking_visible()
		or game_hud.is_blacksmith_visible()
		or game_hud.is_blacksmith_repair_visible()
		or game_hud.is_woodcutting_visible()
	):
		return

	mobile_controls_before_recipe_cooking = mobile_controls.controls_enabled
	input_state.reset_virtual_controls()
	player.stop_movement()
	interaction_system.set_enabled(false)
	mobile_controls.set_enabled(false)
	game_hud.show_recipe_cooking(_recipe_options())
	_refresh_hunting_mode_display()


func _on_recipe_cooking_selected(recipe_id: StringName) -> void:
	if not game_hud.is_recipe_cooking_visible() or recipe_id != &"salad":
		return
	var tomato := inventory.definition_for(&"tomato")
	var carrot := inventory.definition_for(&"carrot")
	if tomato == null or carrot == null or not _salad_recipe_available():
		game_hud.show_notification("Necesitas un tomate y una zanahoria para cocinar.")
		return
	if inventory.remove_item(&"tomato", 1) != 1:
		game_hud.show_notification("No se pudo consumir el tomate.")
		return
	if inventory.remove_item(&"carrot", 1) != 1:
		inventory.add_item(tomato, 1)
		game_hud.show_notification("No se pudo consumir la zanahoria.")
		return

	cooking_recipe_id = recipe_id
	game_hud.start_recipe_cooking(recipe_id)


func _on_recipe_cooking_finished(
	recipe_id: StringName,
	outcome: StringName
) -> void:
	if not game_hud.is_recipe_cooking_visible() or recipe_id != cooking_recipe_id:
		return
	if outcome == &"burned":
		game_hud.show_recipe_cooking_result(
			"La ensalada se ha quemado y no has obtenido comida.",
			false
		)
		return

	var result_id := &"perfect_salad" if outcome == &"perfect" else &"salad"
	var result_item := inventory.definition_for(result_id)
	if result_item == null or inventory.add_item(result_item, 1) != 1:
		game_hud.show_recipe_cooking_result(
			"La receta terminó, pero no hay espacio para guardar la comida.",
			false
		)
		return
	if outcome == &"perfect":
		game_hud.show_recipe_cooking_result(
			"¡Ensalada perfecta! Has obtenido 1 unidad.",
			true
		)
		game_hud.show_notification("Has cocinado una ensalada perfecta.")
	else:
		game_hud.show_recipe_cooking_result(
			"Has cocinado una ensalada.",
			true
		)
		game_hud.show_notification("Has cocinado una ensalada.")


func _close_recipe_cooking() -> void:
	if not game_hud.is_recipe_cooking_visible():
		return
	game_hud.hide_recipe_cooking()
	cooking_recipe_id = &""
	interaction_system.set_enabled(true)
	mobile_controls.set_enabled(mobile_controls_before_recipe_cooking)
	input_state.reset_virtual_controls()
	_refresh_hunting_mode_display()


func _on_hotel_rest_requested(_target: Node, _source: Node) -> void:
	var interior := _active_interior_definition()
	if (
		hotel_sleeping
		or game_paused
		or interior == null
	):
		return
	hotel_sleeping = true
	sleeping_area_label = "la casa" if interior.area_id == GameCatalog.REPAIRED_HOUSE_AREA_ID else "el hotel"
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
	game_hud.show_notification(
		"Has descansado en %s. Salud y estamina restauradas." % sleeping_area_label
	)
	_refresh_hunting_mode_display()


func _show_planting_context_menu(pointer_position: Vector2) -> void:
	if game_hud.is_planting_context_visible() or game_hud.is_planting_visible():
		return
	planting_position = planting_system.tile_center_for_world_position(pointer_position)
	context_position = planting_position
	game_hud.show_planting_context_menu()


func _show_water_context_menu(pointer_position: Vector2) -> void:
	if game_hud.is_planting_context_visible() or game_hud.is_planting_visible():
		return
	var cell := game_world.cell_for_world_position(pointer_position)
	if not game_world.is_water_tile(cell):
		return
	context_position = game_world.tile_center(cell)
	game_hud.show_water_context_menu()


func _hide_planting_context_menu() -> void:
	game_hud.hide_planting_context_menu()


func _on_planting_context_plant_requested() -> void:
	if not game_hud.is_planting_context_visible():
		return
	_hide_planting_context_menu()
	_open_planting(planting_position)


func _on_water_context_drink_requested() -> void:
	if not game_hud.is_planting_context_visible():
		return
	var cell := game_world.cell_for_world_position(context_position)
	if (
		not game_world.is_water_tile(cell)
		or player.global_position.distance_to(context_position)
		> PLANTING_CONTEXT_MAX_DISTANCE
	):
		_hide_planting_context_menu()
		return
	_hide_planting_context_menu()
	if player.drink_water():
		game_hud.show_notification("Has bebido agua del lago.")
	else:
		game_hud.show_notification("No tienes sed.")


func _on_crop_harvested(item: ItemDefinition, amount: int) -> void:
	game_hud.show_notification(
		"Has recogido %d %s." % [amount, item.label.to_lower()]
	)


func _open_planting(pointer_position: Vector2) -> void:
	if game_hud.is_planting_visible():
		return
	_hide_planting_context_menu()
	planting_position = planting_system.tile_center_for_world_position(pointer_position)
	context_position = planting_position
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
		or game_hud.is_planting_context_visible()
		or game_hud.is_blacksmith_visible()
		or game_hud.is_blacksmith_repair_visible()
		or game_hud.is_woodcutting_visible()
		or game_hud.is_cooking_visible()
		or game_hud.is_recipe_cooking_visible()
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


func _on_hunting_weapon_changed(_projectile_id: StringName) -> void:
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


func _on_ground_stone_picked() -> void:
	game_hud.show_notification("Has recogido una piedra.")


func _on_mining_stone_dropped(amount: int) -> void:
	game_hud.show_notification(
		"El mineral ha soltado %d piedra%s." % [
			amount,
			"" if amount == 1 else "s"
		]
	)


func _on_inventory_item_use_requested(item_id: StringName) -> void:
	if not game_hud.is_inventory_visible():
		return
	var item := inventory.definition_for(item_id)
	if item == null or not item.is_usable():
		game_hud.show_notification("Ese objeto no se puede usar.")
		return
	if not inventory.has_item(item_id):
		game_hud.show_notification("No tienes ese objeto.")
		return
	if not player.can_start_gradual_healing(
		item.health_recovery,
		item.health_recovery_duration
	):
		game_hud.show_notification("Tu salud ya está al máximo.")
		return

	if inventory.remove_item(item_id, 1) != 1:
		game_hud.show_notification("No se pudo usar el objeto.")
		return
	if not player.start_gradual_healing(
		item.health_recovery,
		item.health_recovery_duration
	):
		inventory.add_item(item, 1)
		game_hud.show_notification("No se pudo iniciar la curación.")
		return

	game_hud.show_notification(
		"Has usado una venda. Recuperarás hasta %d puntos de salud poco a poco."
		% roundi(item.health_recovery)
	)


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
		and not game_hud.is_blacksmith_repair_visible()
		and not game_hud.is_woodcutting_visible()
		and not game_hud.is_cooking_visible()
		and not game_hud.is_recipe_cooking_visible()
		and not hotel_sleeping
	)
	game_hud.set_hunting_mode(
		visible,
		hunting_system.selected_projectile_label()
	)


func _is_hunting_shot_event(event: InputEvent) -> bool:
	return (
		hunting_system != null
		and hunting_system.is_hunting_mode()
		and world_area_system.is_area_active(GameCatalog.OVERWORLD_AREA_ID)
		and _is_pressed_event(event)
		and control_settings.matches_event(&"primary_action", event)
		and not game_paused
	)


func _is_tree_chop_event(event: InputEvent) -> bool:
	return (
		not mobile_build
		and world_area_system.is_area_active(GameCatalog.OVERWORLD_AREA_ID)
		and _is_pressed_event(event)
		and control_settings.matches_event(&"primary_action", event)
		and not game_paused
	)


func _is_grid_context_request_event(event: InputEvent) -> bool:
	return (
		not mobile_build
		and world_area_system.is_area_active(GameCatalog.OVERWORLD_AREA_ID)
		and _is_pressed_event(event)
		and control_settings.matches_event(&"terrain_action", event)
	)


func _is_kitchen_context_request_event(event: InputEvent) -> bool:
	return (
		not mobile_build
		and _active_interior_definition() != null
		and _is_pressed_event(event)
		and control_settings.matches_event(&"terrain_action", event)
	)


func _is_blacksmith_context_request_event(event: InputEvent) -> bool:
	return (
		not mobile_build
		and world_area_system.is_area_active(GameCatalog.OVERWORLD_AREA_ID)
		and _is_pressed_event(event)
		and control_settings.matches_event(&"terrain_action", event)
	)


func _can_open_kitchen_context(pointer_position: Vector2) -> bool:
	var interior := _active_interior_definition()
	if (
		interior == null
		or player == null
	):
		return false
	var kitchen := interior.kitchen_rect
	return (
		_is_near_kitchen()
		and kitchen.grow(catalog.tile_size * 0.35).has_point(pointer_position)
	)


func _is_near_kitchen() -> bool:
	var interior := _active_interior_definition()
	return (
		interior != null
		and player != null
		and player.global_position.distance_to(interior.kitchen_interaction_position)
		<= PLANTING_CONTEXT_MAX_DISTANCE
	)


func _show_kitchen_context_menu() -> void:
	var interior := _active_interior_definition()
	if (
		interior == null
		or game_hud.is_cooking_visible()
		or game_hud.is_planting_visible()
		or game_hud.is_blacksmith_visible()
		or game_hud.is_blacksmith_repair_visible()
		or game_hud.is_woodcutting_visible()
		or game_hud.is_recipe_cooking_visible()
	):
		return
	context_position = interior.kitchen_interaction_position
	game_hud.show_kitchen_context_menu()


func _active_interior_definition() -> HotelDefinition:
	if catalog == null or world_area_system == null:
		return null
	var active_area_id := world_area_system.active_area_id()
	if catalog.hotel != null and active_area_id == catalog.hotel.area_id:
		return catalog.hotel
	if (
		catalog.repaired_house_interior != null
		and active_area_id == catalog.repaired_house_interior.area_id
	):
		return catalog.repaired_house_interior
	return null


func _cooking_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for vegetable_data in [
		{"id": &"tomato", "seed_id": &"tomato_seed"},
		{"id": &"carrot", "seed_id": &"carrot_seed"}
	]:
		var vegetable_id := StringName(str(vegetable_data.get("id", "")))
		var seed_id := StringName(str(vegetable_data.get("seed_id", "")))
		var vegetable := inventory.definition_for(vegetable_id)
		var seed := inventory.definition_for(seed_id)
		if vegetable == null or seed == null:
			continue
		options.append({
			"id": vegetable_id,
			"label": vegetable.label,
			"quantity": inventory.quantity_of(vegetable_id),
			"seed_id": seed_id
		})
	return options


func _cooking_seed_id_for(vegetable_id: StringName) -> StringName:
	if vegetable_id == &"tomato":
		return &"tomato_seed"
	if vegetable_id == &"carrot":
		return &"carrot_seed"
	return StringName()


func _recipe_options() -> Array[Dictionary]:
	return [{
		"id": &"salad",
		"label": "Ensalada",
		"tomato": inventory.quantity_of(&"tomato"),
		"carrot": inventory.quantity_of(&"carrot"),
		"available": _salad_recipe_available()
	}]


func _salad_recipe_available() -> bool:
	return (
		inventory.has_item(&"tomato")
		and inventory.has_item(&"carrot")
		and inventory.space_for(&"salad") >= 1
		and inventory.space_for(&"perfect_salad") >= 1
	)


func _can_open_blacksmith_context(pointer_position: Vector2) -> bool:
	if (
		blacksmith_spot == null
		or not is_instance_valid(blacksmith_spot)
		or player == null
		or catalog == null
		or not blacksmith_spot.can_interact(player)
	):
		return false

	var anchor := blacksmith_spot.interaction_anchor()
	return (
		_is_near_blacksmith()
		and pointer_position.distance_to(anchor) <= catalog.tile_size * 2.0
	)


func _is_near_blacksmith() -> bool:
	return (
		blacksmith_spot != null
		and is_instance_valid(blacksmith_spot)
		and player != null
		and blacksmith_spot.can_interact(player)
		and player.global_position.distance_to(blacksmith_spot.interaction_anchor())
		<= blacksmith_spot.interaction_distance()
	)


func _show_blacksmith_context_menu() -> void:
	if (
		game_hud.is_blacksmith_visible()
		or game_hud.is_blacksmith_repair_visible()
		or game_hud.is_planting_visible()
	):
		return
	game_hud.show_blacksmith_context_menu()


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
		"temperature": temperature_system.snapshot(),
		"anvil_bars_completed": _anvil_bars_completed,
		"ruined_house_repaired": ruined_house != null and ruined_house.is_repaired(),
		"ground_stones": ground_decoration_layer.snapshot(),
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
	var saved_house_repaired := bool(snapshot.get("ruined_house_repaired", false))
	if ruined_house != null:
		ruined_house.set_repaired(saved_house_repaired)
	if (
		catalog.repaired_house_interior != null
		and area_id == catalog.repaired_house_interior.area_id
		and not saved_house_repaired
	):
		push_warning(
			"La partida guardada apunta al interior de una casa no reparada; se cargarÃ¡ la aldea."
		)
		area_id = GameCatalog.OVERWORLD_AREA_ID
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
		elif (
			catalog.repaired_house_interior != null
			and area_id == catalog.repaired_house_interior.area_id
		):
			fallback_position = catalog.repaired_house_interior.player_spawn
	var saved_player := snapshot.get("player", {}) as Dictionary
	var saved_temperature: Variant = snapshot.get("temperature", {})
	if saved_temperature is Dictionary:
		temperature_system.restore(saved_temperature as Dictionary)
		player.set_ambient_temperature(temperature_system.current_temperature())
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
	var saved_ground_stones: Variant = snapshot.get("ground_stones", null)
	if saved_ground_stones is Array:
		ground_decoration_layer.restore(saved_ground_stones as Array)
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
	_anvil_bars_completed = maxi(int(snapshot.get("anvil_bars_completed", 0)), 0)
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
		ground_decoration_layer,
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
