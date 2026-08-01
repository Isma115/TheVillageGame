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
var _npc_dialogue_system: NpcDialogueSystem
var _tool_service: ToolService
var _wallet: WalletService
var _merchant_service: MerchantService
var _doctor_service: DoctorService
var _planting_system: PlantingSystem
var _wildlife: WildlifeManager
var _hunting_system: HuntingSystem
var _player: PlayerActor
var _game_hud: GameHud
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
	npc_dialogue_system: NpcDialogueSystem,
	tool_service: ToolService,
	wallet: WalletService,
	merchant_service: MerchantService,
	doctor_service: DoctorService,
	planting_system: PlantingSystem,
	wildlife: WildlifeManager,
	hunting_system: HuntingSystem,
	player: PlayerActor,
	game_hud: GameHud,
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
	_npc_dialogue_system = npc_dialogue_system
	_tool_service = tool_service
	_wallet = wallet
	_merchant_service = merchant_service
	_doctor_service = doctor_service
	_planting_system = planting_system
	_wildlife = wildlife
	_hunting_system = hunting_system
	_player = player
	_game_hud = game_hud
	_overworld_actor_layer = overworld_actor_layer
	_overworld_collision_world = overworld_collision_world
	_mine_runtimes.assign(mine_runtimes)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(_validate_content())
	errors.append_array(_validate_overworld())
	errors.append_array(_validate_mines())
	errors.append_array(_validate_dialogue_flow())
	errors.append_array(_validate_transitions())
	return errors


func success_message() -> String:
	return (
		"PRADERA_SMOKE_TEST_OK areas=%d mines=%d portals=%d npcs=%d choices=%d trees=%d veins=%d minerals=%d obstacles=%d/%d"
		% [
			_world_area_system.area_count(),
			_mining_system.mine_count(),
			_world_area_system.portal_count(),
			_npc_dialogue_system.npc_count(),
			_npc_dialogue_system.total_choice_count(),
			_forestry_system.tree_count(),
			_mining_system.vein_count(),
			_mining_system.mineral_type_count(),
			_overworld_collision_world.obstacle_count(),
			_mine_collision_obstacle_count()
		]
	)


func _validate_content() -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(_validate_player_vitals())
	var equipped_tool := _tool_service.equipped_tool()
	if equipped_tool == null:
		errors.append("El personaje no tiene una herramienta equipada.")
	else:
		if equipped_tool.id != _catalog.default_tool_id:
			errors.append("La herramienta equipada no es la predeterminada.")
		if _tool_service.durability_of(equipped_tool.id) != equipped_tool.initial_durability():
			errors.append("La herramienta predeterminada no empieza a media durabilidad.")
		if not _tool_service.can_use_capability(&"chop"):
			errors.append("La herramienta predeterminada no permite talar.")
	errors.append_array(_validate_tool_usage())
	errors.append_array(_validate_merchant_flow())
	errors.append_array(_validate_planting_flow())
	errors.append_array(_validate_blacksmith_flow())
	errors.append_array(_validate_doctor_flow())
	errors.append_array(_validate_hunting_flow())
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
	var expected_area_count := _catalog.mine_definitions().size() + 1
	if _catalog.hotel != null:
		expected_area_count += 1
	if _world_area_system.area_count() != expected_area_count:
		errors.append("El registro de áreas no coincide con el catálogo.")
	if _world_area_system.portal_count() != _catalog.portal_definitions().size():
		errors.append("El registro de portales no coincide con el catálogo.")
	if _npc_dialogue_system.npc_count() != _catalog.npc_definitions().size():
		errors.append("El registro de NPC no coincide con el catálogo.")
	var expected_dialogues := 0
	var expected_merchants := 0
	var expected_doctors := 0
	for npc in _catalog.npc_definitions():
		if npc.dialogue != null:
			expected_dialogues += 1
		if npc.merchant != null:
			expected_merchants += 1
		if npc.doctor != null:
			expected_doctors += 1
	if _npc_dialogue_system.dialogue_count() != expected_dialogues:
		errors.append("El registro de diálogos no coincide con el catálogo.")
	if _npc_dialogue_system.merchant_count() != expected_merchants:
		errors.append("El registro de mercaderes no coincide con el catálogo.")
	if _npc_dialogue_system.doctor_count() != expected_doctors:
		errors.append("El registro de médicos no coincide con el catálogo.")
	var expected_choices := 0
	for npc in _catalog.npc_definitions():
		if npc.dialogue != null:
			expected_choices += npc.dialogue.choice_count()
	if _npc_dialogue_system.total_choice_count() != expected_choices:
		errors.append(
			"El sistema de diálogo contiene %d de %d elecciones."
			% [_npc_dialogue_system.total_choice_count(), expected_choices]
		)
	return errors


func _validate_player_vitals() -> PackedStringArray:
	var errors := PackedStringArray()
	var initial_health := _player.health
	var initial_maximum_health := _player.maximum_health
	var initial_stamina := _player.stamina
	var initial_maximum_stamina := _player.maximum_stamina
	var initial_stamina_cap := _player.stamina_cap
	if initial_health != initial_maximum_health:
		errors.append("La salud inicial no está completa.")
	if initial_stamina != initial_maximum_stamina:
		errors.append("La estamina inicial no está completa.")
	if initial_stamina_cap != initial_maximum_stamina:
		errors.append("La capacidad de estamina inicial no coincide con la máxima.")

	_player.advance_vitals(1.0, true)
	if _player.stamina >= initial_stamina:
		errors.append("Correr no consume estamina.")
	if _player.maximum_stamina >= initial_maximum_stamina:
		errors.append("Correr no reduce la estamina máxima.")
	var fatigued_stamina := _player.stamina
	var fatigued_maximum_stamina := _player.maximum_stamina
	var fatigued_stamina_cap := _player.stamina_cap
	if not is_equal_approx(fatigued_stamina_cap, initial_stamina_cap):
		errors.append("Correr entrena la capacidad sin haber corrido lo suficiente.")
	var before_exhaustion := _player.snapshot()
	var training_interval_before := _catalog.stamina_training_interval
	var stamina_cap_before := _catalog.player_max_stamina_cap
	_catalog.stamina_training_interval = 1.0
	_catalog.player_max_stamina_cap = fatigued_stamina_cap + 1.0
	_player.advance_vitals(5.0, true)
	if _player.stamina_cap != fatigued_stamina_cap + 1.0:
		errors.append("Correr no entrena la capacidad pulmonar o ignora su límite.")
	if _player.maximum_stamina > _player.stamina_cap:
		errors.append("La estamina máxima supera su capacidad entrenada.")
	_catalog.stamina_training_interval = training_interval_before
	_catalog.player_max_stamina_cap = stamina_cap_before
	_player.advance_vitals(10.0, true)
	if _player.stamina > 0.0:
		errors.append("La estamina no llega a cero al agotarse.")
	if _player.can_sprint(1.0 / 60.0):
		errors.append("El personaje puede correr con la estamina agotada.")
	var drained_maximum_stamina := _player.maximum_stamina
	_player.advance_vitals(2.0, false)
	if _player.stamina < _player.stamina_exhaustion_threshold():
		errors.append("La estamina no alcanza el umbral de recuperación del 25%.")
	if not _player.can_sprint(1.0 / 60.0):
		errors.append("La carrera no se desbloquea al recuperar el 25% de estamina.")
	if not is_equal_approx(_player.maximum_stamina, drained_maximum_stamina):
		errors.append("La estamina máxima se recupera sin dormir.")
	_player.restore(before_exhaustion)

	_player.advance_vitals(1.0, false)
	if _player.stamina <= fatigued_stamina:
		errors.append("La estamina no se recupera al descansar.")
	if not is_equal_approx(_player.maximum_stamina, fatigued_maximum_stamina):
		errors.append("La estamina máxima se recupera sin dormir.")

	_player.rest()
	if not is_equal_approx(_player.maximum_stamina, _player.stamina_cap):
		errors.append("Dormir no restaura la estamina máxima hasta su capacidad entrenada.")
	if not is_equal_approx(_player.stamina, _player.maximum_stamina):
		errors.append("Dormir no llena la estamina hasta la máxima.")

	_player.restore({
		"health": initial_health,
		"maximum_health": initial_maximum_health,
		"stamina": initial_stamina,
		"maximum_stamina": initial_maximum_stamina,
		"stamina_cap": initial_stamina_cap
	})
	return errors


func _validate_merchant_flow() -> PackedStringArray:
	var errors := PackedStringArray()
	var merchant: MerchantDefinition
	for npc in _catalog.npc_definitions():
		if npc.merchant != null:
			merchant = npc.merchant
			break
	if merchant == null:
		return ["No hay un mercader para probar la tienda."]

	var wood: ItemDefinition
	for item in _catalog.item_definitions():
		if item.id == &"wood":
			wood = item
			break
	var balance_before := _wallet.balance()
	if wood == null:
		return ["Falta la madera para probar la venta del mercader."]
	if not _merchant_service.open(merchant):
		return ["No se pudo abrir la tienda del mercader."]
	_inventory_add_for_smoke(wood, 1)
	var sale_message := _merchant_service.sell(&"wood")
	if _wallet.balance() != balance_before + 2:
		errors.append("El mercader no paga correctamente la madera.")
	if _merchant_service.offer_for(&"pickaxe") == null:
		errors.append("La tienda no ofrece un pico.")
	var purchase_message := _merchant_service.buy(&"pickaxe")
	if not _tool_service.has_tool(&"pickaxe"):
		errors.append("Comprar el pico no lo añade a las herramientas.")
	if _tool_service.equipped_tool_id() != &"pickaxe":
		errors.append("El pico comprado no queda equipado.")
	if not _tool_service.can_use_capability(&"mine"):
		errors.append("El pico comprado no permite minar.")
	var arrows_offer := _merchant_service.offer_for(&"arrows")
	if arrows_offer == null or arrows_offer.transaction_quantity != 10:
		errors.append("La tienda no ofrece un lote válido de flechas.")
	else:
		var arrows_before := _merchant_service.inventory_service().quantity_of(&"arrows")
		var arrows_message := _merchant_service.buy(&"arrows")
		if (
			_merchant_service.inventory_service().quantity_of(&"arrows")
			!= arrows_before + arrows_offer.transaction_quantity
		):
			errors.append("La compra de flechas no añade la cantidad correcta.")
		if arrows_message.is_empty():
			errors.append("La compra de flechas no devuelve un mensaje.")
	var bow_offer := _merchant_service.offer_for(&"bow")
	if bow_offer == null or bow_offer.tool == null or bow_offer.tool.id != &"bow":
		errors.append("La tienda no ofrece el arco como herramienta.")
	if sale_message.is_empty() or purchase_message.is_empty():
		errors.append("La tienda no devuelve mensajes de transacción.")

	_game_hud.show_merchant(merchant, _merchant_service)
	if not _game_hud.is_merchant_visible():
		errors.append("La interfaz del mercader no se hizo visible.")
	_game_hud.refresh_merchant("")
	_game_hud.hide_merchant()
	_merchant_service.close()
	return errors


func _validate_planting_flow() -> PackedStringArray:
	var errors := PackedStringArray()
	if _planting_system == null:
		return ["El sistema de plantación no está inicializado."]

	var seed_definition: ItemDefinition
	for item in _catalog.item_definitions():
		if item != null and item.id == PlantingSystem.TREE_SEED_ID:
			seed_definition = item
			break
	if seed_definition == null:
		return ["Falta la semilla de árbol en el catálogo."]

	var merchant: MerchantDefinition
	for npc in _catalog.npc_definitions():
		if npc.merchant != null:
			merchant = npc.merchant
			break
	if merchant == null or merchant.offer_for(PlantingSystem.TREE_SEED_ID) == null:
		errors.append("El mercader no ofrece semillas de árbol.")
	for seed_id in [&"tomato_seed", &"wheat_seed", &"carrot_seed"]:
		if merchant == null or merchant.offer_for(seed_id) == null:
			errors.append("El mercader no ofrece la semilla '%s'." % seed_id)

	var crop_definitions := _catalog.crop_definitions()
	if crop_definitions.size() != 3:
		errors.append("El catálogo no contiene los tres cultivos nuevos.")
	var expected_seed_ids: Array[StringName] = [
		&"tomato_seed",
		&"wheat_seed",
		&"carrot_seed"
	]
	var planting_options := _planting_system.seed_options()
	var all_seed_ids: Array[StringName] = [PlantingSystem.TREE_SEED_ID]
	all_seed_ids.append_array(expected_seed_ids)
	for seed_id in all_seed_ids:
		var option_found := false
		for option in planting_options:
			if option.get("id", StringName()) == seed_id:
				option_found = true
				break
		if not option_found:
			errors.append("La interfaz de plantación no ofrece '%s'." % seed_id)

	var cell := _planting_system.first_available_grass_cell()
	if cell.x < 0 or cell.y < 0:
		errors.append("No hay un tile de césped libre para probar la plantación.")
		return errors
	var inventory := _merchant_service.inventory_service()
	var inventory_snapshot := inventory.snapshot()
	var tree_count_before := _forestry_system.tree_count()
	var planted_tree_count_before := _forestry_system.planted_tree_count()
	_inventory_add(seed_definition, 1)
	var plots_before := _planting_system.plot_count()
	var plant_message := _planting_system.plant_seed(
		_game_world.tile_center(cell),
		PlantingSystem.TREE_SEED_ID
	)
	if _planting_system.plot_count() != plots_before + 1:
		errors.append("No se creó la parcela al plantar una semilla.")
	if plant_message.is_empty():
		errors.append("La plantación no devolvió un mensaje.")

	var planting_snapshot := _planting_system.snapshot()
	if planting_snapshot.size() != 1:
		errors.append("La parcela no se incluye en el guardado.")
	else:
		var saved_remaining := float(planting_snapshot[0].get("remaining", -1.0))
		if saved_remaining <= 0.0 or saved_remaining > _catalog.tree_seed_growth_time:
			errors.append("El tiempo restante de crecimiento no se guardó correctamente.")
		_planting_system.restore(planting_snapshot)
		if _planting_system.plot_count() != 1:
			errors.append("La parcela no se restauró desde el guardado.")

	_game_hud.show_planting(cell, _planting_system.seed_options())
	if not _game_hud.is_planting_visible():
		errors.append("La interfaz de plantación no se hizo visible.")
	_game_hud.hide_planting()

	_planting_system.update(_catalog.tree_seed_growth_time + 1.0)
	if _planting_system.plot_count() != 0:
		errors.append("La parcela no desapareció al completar el crecimiento.")
	if _forestry_system.tree_count() != tree_count_before + 1:
		errors.append("La parcela madura no creó un árbol.")
	if _forestry_system.planted_tree_count() != planted_tree_count_before + 1:
		errors.append("El árbol maduro no quedó registrado como plantado.")

	var grown_tree: TreeActor
	for tree in _forestry_system.trees:
		if tree.tree_index >= _catalog.forest.target_tree_count:
			grown_tree = tree
			break
	if grown_tree == null:
		errors.append("El árbol plantado no tiene una especie aleatoria asignada.")
	else:
		_forestry_system.remove_tree(grown_tree)

	if not crop_definitions.is_empty():
		var crop_definition: CropDefinition = crop_definitions[0]
		var crop_seed := inventory.definition_for(crop_definition.seed_id)
		var crop_cell := _planting_system.first_available_grass_cell()
		if crop_seed == null:
			errors.append("Falta la semilla del cultivo '%s'." % crop_definition.id)
		elif crop_cell.x < 0 or crop_cell.y < 0:
			errors.append("No hay un tile libre para probar el cultivo '%s'." % crop_definition.id)
		else:
			_inventory_add(crop_seed, 1)
			var crop_message := _planting_system.plant_seed(
				_game_world.tile_center(crop_cell),
				crop_definition.seed_id
			)
			if crop_message.is_empty() or _planting_system.plot_count() != 1:
				errors.append("No se pudo plantar el cultivo '%s'." % crop_definition.id)
			_planting_system.update(crop_definition.growth_time + 1.0)
			if _planting_system.plot_count() != 0:
				errors.append("El cultivo '%s' no completó su crecimiento." % crop_definition.id)
			if _planting_system.mature_crop_count() != 1:
				errors.append("El cultivo '%s' no creó su sprite maduro." % crop_definition.id)
			var mature_snapshot := _planting_system.snapshot()
			if mature_snapshot.size() != 1 or mature_snapshot[0].get("state", "") != "mature":
				errors.append("El cultivo maduro no se incluyó en el guardado.")
			_planting_system.restore(mature_snapshot)
			if _planting_system.mature_crop_count() != 1:
				errors.append("El cultivo maduro no se restauró desde el guardado.")
			var product := inventory.definition_for(crop_definition.harvest_item_id)
			if product == null:
				errors.append("El cultivo '%s' no tiene producto de cosecha." % crop_definition.id)
			else:
				var product_before := inventory.quantity_of(product.id)
				var harvest_result := _planting_system.harvest_crop(
					_game_world.tile_center(crop_cell)
				)
				if not bool(harvest_result.get("harvested", false)):
					errors.append("No se pudo cosechar el cultivo '%s'." % crop_definition.id)
				if _planting_system.mature_crop_count() != 0:
					errors.append("El cultivo cosechado no desapareció del mundo.")
				if inventory.quantity_of(product.id) != product_before + 1:
					errors.append("Cosechar no agregó el producto al inventario.")
	_planting_system.clear()
	inventory.restore(inventory_snapshot)
	return errors


func _validate_doctor_flow() -> PackedStringArray:
	var errors := PackedStringArray()
	if _doctor_service == null:
		return ["El servicio médico no está inicializado."]

	var doctor: DoctorDefinition
	for npc in _catalog.npc_definitions():
		if npc.doctor != null:
			doctor = npc.doctor
			break
	if doctor == null:
		return ["No hay un médico para probar la consulta."]
	if doctor.consultation_cost != 5:
		errors.append("La consulta médica no cuesta exactamente 5 monedas.")

	var saved_player := _player.snapshot()
	var balance_before := _wallet.balance()
	var consultation_balance := maxi(balance_before, doctor.consultation_cost)
	_wallet.set_balance(consultation_balance)
	_player.damage(25.0)
	if not _doctor_service.open(doctor):
		errors.append("No se pudo abrir la consulta médica.")
	else:
		var report := _doctor_service.consult(_player)
		if not bool(report.get("paid", false)):
			errors.append("El médico no pudo cobrar una consulta con saldo suficiente.")
		if _wallet.balance() != consultation_balance - doctor.consultation_cost:
			errors.append("La consulta médica no descuenta 5 monedas.")
		if not is_equal_approx(float(report.get("health", -1.0)), _player.health):
			errors.append("El informe médico no muestra la salud actual.")
		if not is_equal_approx(
			float(report.get("maximum_health", -1.0)),
			_player.maximum_health
		):
			errors.append("El informe médico no muestra la salud máxima.")
		if not is_equal_approx(
			float(report.get("maximum_stamina", -1.0)),
			_player.maximum_stamina
		):
			errors.append("El informe médico no muestra la estamina máxima.")
		if str(report.get("health_status", "")).is_empty():
			errors.append("El informe médico no muestra el estado de salud.")
		_game_hud.show_doctor(doctor)
		if not _game_hud.is_doctor_visible():
			errors.append("El menú del médico no se hizo visible.")
		_game_hud.show_doctor_report(doctor, report)
		if not _game_hud.is_doctor_visible():
			errors.append("El informe médico no se hizo visible.")
		_game_hud.hide_doctor()
		_doctor_service.close()

	_wallet.set_balance(0)
	if not _doctor_service.open(doctor):
		errors.append("No se pudo reabrir la consulta médica.")
	else:
		var refused_report := _doctor_service.consult(_player)
		if bool(refused_report.get("paid", false)):
			errors.append("El médico cobró una consulta sin saldo suficiente.")
		_doctor_service.close()

	_wallet.set_balance(balance_before)
	_player.restore(saved_player)
	return errors


func _validate_blacksmith_flow() -> PackedStringArray:
	var errors := PackedStringArray()
	_game_hud.show_blacksmith()
	if not _game_hud.is_blacksmith_visible():
		errors.append("La interfaz de la herrería no se hizo visible.")
	_game_hud.hide_blacksmith()
	return errors


func _validate_hunting_flow() -> PackedStringArray:
	var errors := PackedStringArray()
	if _hunting_system == null or _wildlife == null:
		return ["El modo de caza no está inicializado."]

	var inventory := _merchant_service.inventory_service()
	var arrows: ItemDefinition
	var meat: ItemDefinition
	for item in _catalog.item_definitions():
		if item == null:
			continue
		if item.id == &"arrows":
			arrows = item
		elif item.id == &"meat":
			meat = item
	if arrows == null or meat == null:
		return ["Faltan los recursos del modo de caza."]

	if not _tool_service.has_tool(&"bow"):
		if not _tool_service.acquire_tool(&"bow"):
			return ["No se pudo adquirir el arco para probar la caza."]
	elif _tool_service.durability_of(&"bow") <= 0:
		_tool_service.set_durability(&"bow", 1)
	if not _tool_service.equip_tool(&"bow"):
		return ["No se pudo equipar el arco para probar la caza."]
	if inventory.quantity_of(&"arrows") <= 0:
		_inventory_add(arrows, 1)
	_tool_service.equip_tool(_catalog.default_tool_id)
	_hunting_system.refresh_mode()
	if not _hunting_system.is_hunting_mode():
		errors.append("Tener arco y flechas no activa el modo de caza.")

	_wildlife.update_animals(2.0)
	if _wildlife.animals.is_empty():
		errors.append("No apareció ningún animal para probar la caza.")
	else:
		var target := _wildlife.animals[0]
		var arrows_before := inventory.quantity_of(&"arrows")
		var meat_before := inventory.quantity_of(&"meat")
		var durability_before := _tool_service.durability_of(&"bow")
		var shots_fired := 0
		for shot_index in range(target.definition.hunting_health):
			if not _hunting_system.shoot_at(target.hunting_target_position()):
				errors.append("El arco no pudo lanzar una flecha.")
				break
			shots_fired += 1
			if (
				shot_index < target.definition.hunting_health - 1
				and not _wildlife.animals.has(target)
			):
				errors.append("El animal murió antes de recibir todas sus flechas.")
				break
		if inventory.quantity_of(&"arrows") != arrows_before - shots_fired:
			errors.append("Disparar no consume una flecha por cada tiro.")
		if _tool_service.durability_of(&"bow") != durability_before - shots_fired:
			errors.append("Disparar no consume durabilidad del arco por tiro.")
		if _wildlife.animals.has(target):
			errors.append(
				"El animal alcanzado no fue eliminado tras %d flechas."
				% target.definition.hunting_health
			)
		if inventory.quantity_of(&"meat") != meat_before + 1:
			errors.append("Cazar un animal no entrega carne.")

	_tool_service.equip_tool(_catalog.default_tool_id)
	_hunting_system.refresh_mode()
	return errors


func _inventory_add_for_smoke(item: ItemDefinition, amount: int) -> void:
	if item != null:
		_inventory_add(item, amount)


func _inventory_add(item: ItemDefinition, amount: int) -> void:
	# Mantener la verificación aislada del servicio de inventario del controlador.
	var inventory := _merchant_service.inventory_service()
	if inventory != null:
		inventory.add_item(item, amount)


func _validate_tool_usage() -> PackedStringArray:
	var errors := PackedStringArray()
	if _forestry_system.trees.is_empty():
		return ["No hay árboles para probar el uso de la herramienta."]

	var tree := _forestry_system.trees[0]
	var tool := _tool_service.equipped_tool()
	if tool == null:
		return errors

	var health_before := tree.current_health
	var durability_before := _tool_service.durability_of(tool.id)
	tree.interact(_player)
	var expected_durability := durability_before - tool.durability_cost
	if _tool_service.durability_of(tool.id) != expected_durability:
		errors.append("Talar no consume durabilidad del hacha.")
	if tree.current_health != maxi(0, health_before - _catalog.forest.base_chop_damage):
		errors.append("El hacha no aplica daño al árbol.")
	return errors


func _validate_overworld() -> PackedStringArray:
	var errors := PackedStringArray()
	var expected_interactables := (
		_forestry_system.active_tree_count()
		+ _world_area_system.portal_count(GameCatalog.OVERWORLD_AREA_ID)
		+ _npc_dialogue_system.npc_count(GameCatalog.OVERWORLD_AREA_ID)
	)
	for house in _catalog.house_definitions():
		if house.id == &"blacksmith":
			expected_interactables += 1
			break
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
		+ _npc_dialogue_system.npc_count(GameCatalog.OVERWORLD_AREA_ID)
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


func _validate_dialogue_flow() -> PackedStringArray:
	var errors := PackedStringArray()
	var definitions := _catalog.npc_definitions()
	if definitions.is_empty():
		return errors

	var npc: NpcDefinition
	for candidate in definitions:
		if candidate.dialogue != null:
			npc = candidate
			break
	if npc == null:
		return errors
	if not _npc_dialogue_system.begin_dialogue(npc.id):
		errors.append("No se pudo iniciar el diálogo de '%s'." % npc.display_name)
		return errors
	if not _npc_dialogue_system.is_dialogue_active():
		errors.append("El diálogo de '%s' no quedó activo." % npc.display_name)
	if not _game_hud.is_dialogue_visible():
		errors.append("La interfaz de diálogo no se hizo visible.")
	if _game_hud.dialogue_visible_choice_count() != 4:
		errors.append("La interfaz inicial no muestra exactamente cuatro respuestas.")
	var action_definitions := npc.action_definitions()
	if _game_hud.dialogue_visible_action_count() != action_definitions.size():
		errors.append(
		"La interfaz no muestra las %d acciones sociales del NPC."
		% action_definitions.size()
	)
	if _game_hud.dialogue_visible_affinity() != 0:
		errors.append("La afinidad inicial del aldeano no es cero.")

	if action_definitions.size() >= 3:
		var initial_action_affinity := _npc_dialogue_system.affinity_for_npc(npc.id)
		_npc_dialogue_system.perform_action(0)
		var positive_expected := initial_action_affinity + action_definitions[0].affinity_delta
		if _npc_dialogue_system.affinity_for_npc(npc.id) != positive_expected:
			errors.append("La acción positiva no aumenta correctamente la afinidad.")
		if _game_hud.dialogue_visible_affinity() != positive_expected:
			errors.append("La interfaz no refleja el cambio de la acción positiva.")
		if (
			_npc_dialogue_system.action_cooldown_remaining(
				npc.id,
				action_definitions[0].id
			) <= 0.0
		):
			errors.append("La acción social no inició su cooldown de dos minutos.")
		_npc_dialogue_system.perform_action(0)
		if _npc_dialogue_system.affinity_for_npc(npc.id) != positive_expected:
			errors.append("Una acción social en cooldown volvió a modificar la afinidad.")
		_npc_dialogue_system.perform_action(2)
		if _npc_dialogue_system.affinity_for_npc(npc.id) != positive_expected:
			errors.append("La acción neutral modificó la afinidad.")
		_npc_dialogue_system.perform_action(3)
		if _npc_dialogue_system.affinity_for_npc(npc.id) >= positive_expected:
			errors.append("La acción negativa no reduce la afinidad.")

	_npc_dialogue_system.choose(0)
	if _game_hud.dialogue_visible_choice_count() != 4:
		errors.append("La transición de diálogo duplicó o perdió respuestas.")
	var dialogue_snapshot := _npc_dialogue_system.snapshot()
	var discovered: Variant = dialogue_snapshot.get(String(npc.dialogue.id), [])
	if not (discovered is Array) or (discovered as Array).size() != 1:
		errors.append("La elección de prueba no quedó registrada.")
	if _npc_dialogue_system.affinity_for_npc(npc.id) != 1:
		errors.append("El primer diálogo nuevo no suma exactamente 1 de afinidad.")
	if _game_hud.dialogue_visible_affinity() != 1:
		errors.append("La interfaz no muestra la afinidad actualizada.")
	if action_definitions.size() >= 4:
		_npc_dialogue_system.restore_action_cooldowns({})
		_npc_dialogue_system.perform_action(3)
		_npc_dialogue_system.restore_action_cooldowns({})
		_npc_dialogue_system.perform_action(3)
		if _npc_dialogue_system.affinity_for_npc(npc.id) >= 0:
			errors.append("La afinidad no puede bajar por debajo de cero.")
		var saved_affinity := _npc_dialogue_system.affinity_snapshot()
		_npc_dialogue_system.restore(dialogue_snapshot)
		_npc_dialogue_system.restore_affinity(saved_affinity)
		if _npc_dialogue_system.affinity_for_npc(npc.id) >= 0:
			errors.append("La afinidad negativa no se conserva al restaurar.")
		_npc_dialogue_system.restore(dialogue_snapshot)

	_npc_dialogue_system.close_dialogue()
	if not _npc_dialogue_system.begin_dialogue(npc.id):
		errors.append("No se pudo repetir el diálogo del aldeano.")
	else:
		_npc_dialogue_system.choose(0)
		if _npc_dialogue_system.affinity_for_npc(npc.id) != 1:
			errors.append("Repetir un diálogo ya descubierto volvió a sumar afinidad.")
		_npc_dialogue_system.close_dialogue()
	if _npc_dialogue_system.is_dialogue_active():
		errors.append("El diálogo de prueba no se cerró.")
	if _game_hud.is_dialogue_visible():
		errors.append("La interfaz de diálogo continuó visible tras cerrarse.")
	if not _interaction_system.is_enabled():
		errors.append("Las interacciones no se reactivaron tras el diálogo.")
	_npc_dialogue_system.restore({})
	_npc_dialogue_system.restore_action_cooldowns({})
	return errors


func _validate_transitions() -> PackedStringArray:
	var errors := PackedStringArray()
	var mining_tool_checked := false
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
		elif not mining_tool_checked:
			errors.append_array(_validate_mining_tool_usage(runtime))
			mining_tool_checked = true

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

	if _catalog.hotel != null:
		var hotel_id := _catalog.hotel.area_id
		var hotel_runtime := _world_area_system.area_runtime(hotel_id)
		if hotel_runtime == null:
			errors.append("El hotel no tiene un runtime registrado.")
		elif not _world_area_system.transition_to(hotel_id, _catalog.hotel.player_spawn):
			errors.append("No se pudo entrar en el hotel.")
		else:
			if (
				_world_area_system.active_area_id() != hotel_id
				or _player.get_parent() != hotel_runtime.actor_layer
				or _player.collision_world != hotel_runtime.collision_world
			):
				errors.append("La transición al hotel dejó un contexto incoherente.")
			var expected_interactions := _world_area_system.portal_count(hotel_id) + 1
			if _interaction_system.registered_count(hotel_id) != expected_interactions:
				errors.append("El hotel no registró correctamente la cama y su salida.")
			if hotel_runtime.collision_world.obstacle_count() != _catalog.hotel.interior_obstacles.size():
				errors.append("El hotel no registró sus obstáculos interiores.")
			var saved_player := _player.snapshot()
			_player.damage(25.0)
			_player.advance_vitals(1.0, true)
			_player.rest()
			if _player.health != _player.maximum_health or _player.stamina != _player.maximum_stamina:
				errors.append("La cama del hotel no restaura la salud y la estamina.")
			_player.restore(saved_player)

		if not _world_area_system.transition_to(
			GameCatalog.OVERWORLD_AREA_ID,
			_catalog.player_spawn
		):
			errors.append("No se pudo salir del hotel.")

	_tool_service.equip_tool(_catalog.default_tool_id)
	return errors


func _validate_mining_tool_usage(runtime: MineAreaRuntime) -> PackedStringArray:
	var errors := PackedStringArray()
	if not _tool_service.has_tool(&"pickaxe"):
		return ["No se adquirió el pico para probar la minería."]
	if not _tool_service.equip_tool(&"pickaxe"):
		return ["No se pudo equipar el pico para probar la minería."]

	var vein: OreVeinActor
	for candidate in _mining_system.veins:
		if (
			is_instance_valid(candidate)
			and candidate.interaction_area_id() == runtime.definition.area_id
			and not candidate.harvest_depleted
		):
			vein = candidate
			break
	if vein == null:
		return ["No hay una veta activa para probar la minería."]

	var health_before := vein.current_health
	var durability_before := _tool_service.durability_of(&"pickaxe")
	vein.interact(_player)
	if _tool_service.durability_of(&"pickaxe") != durability_before - 1:
		errors.append("Minar no consume durabilidad del pico.")
	var expected_health := maxi(
		0,
		health_before - runtime.definition.base_mining_damage
	)
	if vein.current_health != expected_health:
		errors.append("El pico no aplica daño a la veta.")
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
