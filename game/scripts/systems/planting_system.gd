extends RefCounted
class_name PlantingSystem

const TREE_SEED_ID: StringName = &"tree_seed"

var _catalog: GameCatalog
var _world: GameWorld
var _actor_layer: Node2D
var _collision_world: CollisionWorld
var _inventory: InventoryService
var _forestry_system: ForestrySystem
var _player: PlayerActor
var _plots: Dictionary = {}
var _mature_crops: Dictionary = {}


func initialize(
	game_catalog: GameCatalog,
	game_world: GameWorld,
	actor_layer: Node2D,
	collision_world: CollisionWorld,
	inventory: InventoryService,
	forestry_system: ForestrySystem,
	player: PlayerActor
) -> void:
	_clear_plots()
	_catalog = game_catalog
	_world = game_world
	_actor_layer = actor_layer
	_collision_world = collision_world
	_inventory = inventory
	_forestry_system = forestry_system
	_player = player


func update(delta: float) -> void:
	if delta <= 0.0 or _plots.is_empty():
		return

	var ready_cells: Array[Vector2i] = []
	for plot_key in _plots:
		var cell: Vector2i = plot_key
		var plot: Dictionary = _plots[cell]
		var remaining := maxf(float(plot.get("remaining", 0.0)) - delta, 0.0)
		plot["remaining"] = remaining
		_plots[cell] = plot
		var actor := plot.get("actor") as PlantingPlotActor
		if is_instance_valid(actor):
			actor.set_growth(remaining, float(plot.get("duration", 1.0)))
		if remaining <= 0.0:
			ready_cells.append(cell)

	for cell in ready_cells:
		_complete_plot(cell)


func seed_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if _inventory == null:
		return options
	for seed_definition in _seed_definitions():
		options.append({
			"id": seed_definition.id,
			"label": seed_definition.label,
			"quantity": _inventory.quantity_of(seed_definition.id),
			"color": seed_definition.display_color
		})
	return options


func can_plant_at(world_position: Vector2) -> bool:
	if _catalog == null or _world == null or _collision_world == null:
		return false
	var cell := _world.cell_for_world_position(world_position)
	if not _world.is_grass_tile(cell):
		return false
	var center := _world.tile_center(cell)
	if not _catalog.playable_bounds().has_point(center):
		return false
	if _plots.has(cell):
		return false
	if _mature_crops.has(cell):
		return false
	if _world.is_position_reserved(center, 0.0):
		return false
	if _collision_world.is_position_blocked(center, 5.0):
		return false
	if _player != null and _player.global_position.distance_to(center) < _catalog.player_radius + 7.0:
		return false
	return true


func cell_for_world_position(world_position: Vector2) -> Vector2i:
	return _world.cell_for_world_position(world_position) if _world != null else Vector2i(-1, -1)


func tile_center_for_world_position(world_position: Vector2) -> Vector2:
	if _world == null:
		return Vector2.ZERO
	return _world.tile_center(_world.cell_for_world_position(world_position))


func first_available_grass_cell() -> Vector2i:
	if _world == null or _catalog == null:
		return Vector2i(-1, -1)
	for cell_y in range(_catalog.world_rows):
		for cell_x in range(_catalog.world_columns):
			var cell := Vector2i(cell_x, cell_y)
			if can_plant_at(_world.tile_center(cell)):
				return cell
	return Vector2i(-1, -1)


func plant_seed(world_position: Vector2, seed_id: StringName) -> String:
	var crop_definition := _crop_for_seed(seed_id)
	if seed_id != TREE_SEED_ID and crop_definition == null:
		return "Esa semilla no se puede plantar aquí."
	if not can_plant_at(world_position):
		return "Solo puedes plantar en un hueco de césped libre."
	if _inventory == null or not _inventory.has_item(seed_id):
		return "No tienes esa semilla."

	var cell := _world.cell_for_world_position(world_position)
	var center := _world.tile_center(cell)
	var duration := (
		_catalog.tree_seed_growth_time
		if crop_definition == null
		else crop_definition.growth_time
	)
	if _inventory.remove_item(seed_id, 1) != 1:
		return "No se pudo utilizar la semilla."

	var plot := {
		"cell": cell,
		"position": center,
		"seed_id": String(seed_id),
		"remaining": duration,
		"duration": duration,
		"actor": _create_plot_actor(center, duration, duration)
	}
	_plots[cell] = plot
	var crop_label := "árbol" if crop_definition == null else crop_definition.label.to_lower()
	return "Semilla plantada. El cultivo de %s crecerá en %d segundos." % [
		crop_label,
		roundi(duration)
	]


func plot_count() -> int:
	return _plots.size()


func mature_crop_count() -> int:
	return _mature_crops.size()


func remaining_time_at(cell: Vector2i) -> float:
	var plot: Dictionary = _plots.get(cell, {})
	return float(plot.get("remaining", -1.0))


func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for plot_key in _plots:
		var cell: Vector2i = plot_key
		var plot: Dictionary = _plots[cell]
		var plot_cell: Vector2i = plot.get("cell", cell)
		var position: Vector2 = plot.get("position", _world.tile_center(plot_cell))
		result.append({
			"state": "growing",
			"cell_x": plot_cell.x,
			"cell_y": plot_cell.y,
			"position_x": position.x,
			"position_y": position.y,
			"seed_id": str(plot.get("seed_id", String(TREE_SEED_ID))),
			"remaining": maxf(float(plot.get("remaining", 0.0)), 0.0),
			"duration": maxf(float(plot.get("duration", _catalog.tree_seed_growth_time)), 1.0)
		})
	for crop_key in _mature_crops:
		var cell: Vector2i = crop_key
		var crop: Dictionary = _mature_crops[cell]
		var crop_cell: Vector2i = crop.get("cell", cell)
		var position: Vector2 = crop.get("position", _world.tile_center(crop_cell))
		result.append({
			"state": "mature",
			"cell_x": crop_cell.x,
			"cell_y": crop_cell.y,
			"position_x": position.x,
			"position_y": position.y,
			"seed_id": str(crop.get("seed_id", ""))
		})
	return result


func restore(snapshot_data: Array) -> void:
	_clear_plots()
	if _world == null or _catalog == null:
		return
	for value in snapshot_data:
		if not value is Dictionary:
			continue
		var state := value as Dictionary
		var cell := Vector2i(
			int(state.get("cell_x", -1)),
			int(state.get("cell_y", -1))
		)
		if not _world.is_grass_tile(cell) or _plots.has(cell):
			continue
		if _mature_crops.has(cell):
			continue
		var position := _world.tile_center(cell)
		var seed_id := StringName(str(state.get("seed_id", String(TREE_SEED_ID))))
		if str(state.get("state", "growing")) == "mature":
			var mature_definition := _crop_for_seed(seed_id)
			if mature_definition != null:
				_spawn_mature_crop(cell, position, mature_definition)
			continue

		var crop_definition := _crop_for_seed(seed_id)
		var default_duration := _catalog.tree_seed_growth_time
		if crop_definition != null:
			default_duration = crop_definition.growth_time
		var duration := maxf(
			float(state.get("duration", default_duration)),
			1.0
		)
		var remaining := clampf(float(state.get("remaining", duration)), 0.0, duration)
		_plots[cell] = {
			"cell": cell,
			"position": position,
			"seed_id": str(seed_id),
			"remaining": remaining,
			"duration": duration,
			"actor": _create_plot_actor(position, remaining, duration)
		}


func clear() -> void:
	_clear_plots()


func _create_plot_actor(
	world_position: Vector2,
	remaining: float,
	duration: float
) -> PlantingPlotActor:
	if _actor_layer == null:
		return null
	var actor := PlantingPlotActor.new()
	actor.initialize(world_position, remaining, duration)
	_actor_layer.add_child(actor)
	return actor


func _complete_plot(cell: Vector2i) -> void:
	var plot: Dictionary = _plots.get(cell, {})
	if plot.is_empty():
		return
	var actor := plot.get("actor") as PlantingPlotActor
	if is_instance_valid(actor):
		actor.queue_free()
	_plots.erase(cell)
	var position: Vector2 = plot.get("position", _world.tile_center(cell))
	var seed_id := StringName(str(plot.get("seed_id", String(TREE_SEED_ID))))
	if seed_id == TREE_SEED_ID:
		if _forestry_system != null and _forestry_system.spawn_planted_tree(position) == null:
			push_warning("La semilla de la parcela %s no pudo convertirse en árbol." % cell)
		return

	var crop_definition := _crop_for_seed(seed_id)
	if crop_definition == null:
		push_warning("La semilla de la parcela %s no tiene un cultivo configurado." % cell)
		return
	_spawn_mature_crop(cell, position, crop_definition)


func _clear_plots() -> void:
	for plot_value in _plots.values():
		var plot: Dictionary = plot_value
		var actor := plot.get("actor") as PlantingPlotActor
		if is_instance_valid(actor):
			actor.queue_free()
	_plots.clear()
	for crop_value in _mature_crops.values():
		var crop: Dictionary = crop_value
		var actor := crop.get("actor") as CropActor
		if is_instance_valid(actor):
			actor.queue_free()
	_mature_crops.clear()


func _seed_definitions() -> Array[ItemDefinition]:
	var definitions: Array[ItemDefinition] = []
	if _inventory == null:
		return definitions
	var seed_ids: Array[StringName] = [TREE_SEED_ID]
	if _catalog != null:
		for crop in _catalog.crop_definitions():
			if not seed_ids.has(crop.seed_id):
				seed_ids.append(crop.seed_id)
	for seed_id in seed_ids:
		var definition := _inventory.definition_for(seed_id)
		if definition != null:
			definitions.append(definition)
	return definitions


func _crop_for_seed(seed_id: StringName) -> CropDefinition:
	if _catalog == null:
		return null
	for crop in _catalog.crop_definitions():
		if crop.seed_id == seed_id:
			return crop
	return null


func _spawn_mature_crop(
	cell: Vector2i,
	world_position: Vector2,
	definition: CropDefinition
) -> CropActor:
	if (
		_actor_layer == null
		or definition == null
		or _mature_crops.has(cell)
	):
		return null
	var actor := CropActor.new()
	actor.initialize(definition, world_position)
	_actor_layer.add_child(actor)
	_mature_crops[cell] = {
		"cell": cell,
		"position": world_position,
		"seed_id": str(definition.seed_id),
		"actor": actor
	}
	return actor
