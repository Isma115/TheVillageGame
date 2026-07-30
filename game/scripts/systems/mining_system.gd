extends Node
class_name MiningSystem

signal deposit_depleted(
	deposit: OreVeinActor,
	item: ItemDefinition,
	amount: int
)

@export var ore_vein_scene: PackedScene

var veins: Array[OreVeinActor] = []
var _sites: Dictionary = {}
var _vein_sites: Dictionary = {}
var _interaction_system: InteractionSystem
var _inventory: InventoryService


func initialize(
	interaction_system: InteractionSystem,
	inventory: InventoryService
) -> void:
	_clear_veins()
	_interaction_system = interaction_system
	_inventory = inventory


func register_mine(
	mine_definition: MineDefinition,
	actor_layer: Node2D,
	collision_world: CollisionWorld
) -> MiningSiteRuntime:
	if ore_vein_scene == null:
		push_error("MiningSystem necesita una escena de veta.")
		return null
	if _interaction_system == null or _inventory == null:
		push_error("MiningSystem debe inicializarse antes de registrar minas.")
		return null
	if mine_definition == null:
		push_error("No se puede registrar una mina sin definición.")
		return null
	if _sites.has(mine_definition.area_id):
		push_error("La mina '%s' ya está registrada." % mine_definition.area_id)
		return null

	var site := MiningSiteRuntime.new()
	if not site.configure(mine_definition, actor_layer, collision_world):
		push_error("La mina '%s' no tiene un runtime válido." % mine_definition.id)
		return null

	_sites[mine_definition.area_id] = site
	var definitions := mine_definition.deposit_definitions()
	for index in range(definitions.size()):
		_spawn_vein(site, definitions[index], index)
	return site


func site_runtime(area_id: StringName) -> MiningSiteRuntime:
	return _sites.get(area_id) as MiningSiteRuntime


func mine_count() -> int:
	return _sites.size()


func vein_count(area_id: StringName = &"") -> int:
	if String(area_id).is_empty():
		return veins.size()
	var site := site_runtime(area_id)
	return site.vein_count() if site != null else 0


func active_vein_count(area_id: StringName = &"") -> int:
	if not String(area_id).is_empty():
		var site := site_runtime(area_id)
		return site.active_vein_count if site != null else 0

	var total := 0
	for value in _sites.values():
		var site := value as MiningSiteRuntime
		if site != null:
			total += site.active_vein_count
	return total


func depleted_vein_count(area_id: StringName = &"") -> int:
	return vein_count(area_id) - active_vein_count(area_id)


func mineral_type_count() -> int:
	var mineral_ids: Dictionary = {}
	for value in _sites.values():
		var site := value as MiningSiteRuntime
		if site == null:
			continue
		for mineral in site.definition.mineral_definitions():
			mineral_ids[mineral.id] = true
	return mineral_ids.size()


func has_mineral(mineral_id: StringName) -> bool:
	for value in _sites.values():
		var site := value as MiningSiteRuntime
		if site == null:
			continue
		for mineral in site.definition.mineral_definitions():
			if mineral.id == mineral_id:
				return true
	return false


func _spawn_vein(
	site: MiningSiteRuntime,
	definition: MineralDepositDefinition,
	index: int
) -> void:
	var vein := ore_vein_scene.instantiate() as OreVeinActor
	if vein == null:
		push_error("La escena de veta no crea un OreVeinActor.")
		return

	vein.initialize(
		definition,
		site.definition.area_id,
		site.definition.random_seed + index * 104729,
		index
	)
	site.actor_layer.add_child(vein)
	vein.interaction_requested.connect(_on_vein_interaction_requested)
	site.collision_world.register_obstacle(
		vein.collision_key(),
		vein.collision_rectangle()
	)
	_interaction_system.register_interactable(vein)
	site.veins.append(vein)
	site.active_vein_count += 1
	veins.append(vein)
	_vein_sites[vein.get_instance_id()] = site


func _on_vein_interaction_requested(target: Node2D, source: Node2D) -> void:
	var vein := target as OreVeinActor
	if vein == null or not vein.can_interact(source):
		return

	var site := _vein_sites.get(vein.get_instance_id()) as MiningSiteRuntime
	if site == null or not site.action_cooldown.try_start(site.definition.mining_cooldown):
		return
	if not vein.apply_mining_hit(site.definition.base_mining_damage):
		return

	site.collision_world.unregister_obstacle(vein.collision_key())
	_interaction_system.unregister_interactable(vein)
	var item := vein.definition.mineral.yielded_item
	var amount_added := _inventory.add_item(item, vein.resource_yield)
	site.active_vein_count = maxi(0, site.active_vein_count - 1)
	deposit_depleted.emit(vein, item, amount_added)


func _clear_veins() -> void:
	for vein in veins:
		if not is_instance_valid(vein):
			continue
		var site := _vein_sites.get(vein.get_instance_id()) as MiningSiteRuntime
		if site != null:
			site.collision_world.unregister_obstacle(vein.collision_key())
		if _interaction_system != null:
			_interaction_system.unregister_interactable(vein)
		vein.queue_free()
	veins.clear()
	_vein_sites.clear()
	_sites.clear()
