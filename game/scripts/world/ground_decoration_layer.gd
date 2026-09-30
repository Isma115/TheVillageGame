extends Node2D
class_name GroundDecorationLayer

const STONE_TEXTURE_PATH := "res://assets/terrain/ground-stone.png"
const STONE_ITEM_ID: StringName = &"stone"
const STONE_DENSITY := 0.020
const STONE_CLEARANCE := 8.0
const GRASS_MEDIUM_TEXTURE_PATH := "res://assets/terrain/grass-medium.png"
const GRASS_LOW_TEXTURE_PATH := "res://assets/terrain/grass-low.png"
const GRASS_ITEM_ID: StringName = &"grass"
const GRASS_MEDIUM_KIND: StringName = &"medium"
const GRASS_LOW_KIND: StringName = &"low"
const GRASS_MEDIUM_DENSITY := 0.010
const GRASS_LOW_DENSITY := 0.022
const GRASS_CLEARANCE := 4.0
const GRASS_MEDIUM_YIELD := 2
const GRASS_LOW_YIELD := 1
const PLAYER_CLEARANCE_TILES := 2.5
const PLAZA_CLEARANCE_TILES := 2.0

signal stone_picked
signal grass_picked(amount: int)

var _world: GameWorld
var _catalog: GameCatalog
var _stone_texture: Texture2D
var _grass_medium_texture: Texture2D
var _grass_low_texture: Texture2D
var _interaction_system: InteractionSystem
var _inventory: InventoryService
var _stone_item: ItemDefinition
var _grass_item: ItemDefinition
var _stone_cells: Array[Vector2i] = []
var _stone_pickups: Dictionary = {}
var _grass_cells: Array[Vector2i] = []
var _grass_kind_by_cell: Dictionary = {}
var _grass_pickups: Dictionary = {}


func _ready() -> void:
	_stone_texture = ResourceLoader.load(STONE_TEXTURE_PATH, "Texture2D") as Texture2D
	_grass_medium_texture = ResourceLoader.load(
		GRASS_MEDIUM_TEXTURE_PATH,
		"Texture2D"
	) as Texture2D
	_grass_low_texture = ResourceLoader.load(
		GRASS_LOW_TEXTURE_PATH,
		"Texture2D"
	) as Texture2D


func initialize(
	game_world: GameWorld,
	game_catalog: GameCatalog,
	interaction_system: InteractionSystem,
	inventory: InventoryService
) -> void:
	_clear_stone_pickups()
	_clear_grass_pickups()
	_world = game_world
	_catalog = game_catalog
	_interaction_system = interaction_system
	_inventory = inventory
	_stone_item = inventory.definition_for(STONE_ITEM_ID) if inventory != null else null
	_grass_item = inventory.definition_for(GRASS_ITEM_ID) if inventory != null else null
	_build_stone_cells()
	_build_grass_cells()
	_spawn_stone_pickups()
	_spawn_grass_pickups()
	queue_redraw()


func stone_count() -> int:
	return _stone_cells.size()


func grass_count() -> int:
	return _grass_cells.size()


func has_stone_at(cell: Vector2i) -> bool:
	return _stone_cells.has(cell)


func clear_grass_at(cell: Vector2i) -> bool:
	if not _grass_cells.has(cell):
		return false

	var pickup := _grass_pickups.get(_cell_key(cell)) as GroundGrassPickup
	_grass_cells.erase(cell)
	_grass_kind_by_cell.erase(_cell_key(cell))
	_grass_pickups.erase(_cell_key(cell))
	if _interaction_system != null and pickup != null:
		_interaction_system.unregister_interactable(pickup)
	if is_instance_valid(pickup):
		pickup.set_interaction_active(false)
		pickup.queue_free()
	queue_redraw()
	return true


func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in _stone_cells:
		result.append({
			"x": cell.x,
			"y": cell.y
		})
	return result


func grass_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in _grass_cells:
		result.append({
			"x": cell.x,
			"y": cell.y,
			"kind": String(_grass_kind_by_cell.get(
				_cell_key(cell),
				GRASS_LOW_KIND
			))
		})
	return result


func restore(snapshot_data: Array) -> void:
	if _world == null or _catalog == null:
		return

	var saved_cells: Array[Vector2i] = []
	for value in snapshot_data:
		if not value is Dictionary:
			continue
		var data := value as Dictionary
		var cell := Vector2i(
			int(data.get("x", 2147483647)),
			int(data.get("y", 2147483647))
		)
		if _world.is_grass_tile(cell) and not saved_cells.has(cell):
			saved_cells.append(cell)

	_clear_stone_pickups()
	_stone_cells.clear()
	for cell in saved_cells:
		_stone_cells.append(cell)
	_spawn_stone_pickups()
	queue_redraw()


func restore_grass(snapshot_data: Array) -> void:
	if _world == null or _catalog == null:
		return

	var saved_cells: Array[Vector2i] = []
	var saved_kinds: Dictionary = {}
	for value in snapshot_data:
		if not value is Dictionary:
			continue
		var data := value as Dictionary
		var cell := Vector2i(
			int(data.get("x", 2147483647)),
			int(data.get("y", 2147483647))
		)
		if not _world.is_grass_tile(cell) or _stone_cells.has(cell):
			continue
		var kind := StringName(str(data.get("kind", GRASS_LOW_KIND)))
		if kind != GRASS_MEDIUM_KIND and kind != GRASS_LOW_KIND:
			kind = GRASS_LOW_KIND
		var key := _cell_key(cell)
		if saved_kinds.has(key):
			continue
		saved_cells.append(cell)
		saved_kinds[key] = kind

	_clear_grass_pickups()
	_grass_cells.clear()
	_grass_kind_by_cell.clear()
	for cell in saved_cells:
		_grass_cells.append(cell)
		_grass_kind_by_cell[_cell_key(cell)] = saved_kinds[_cell_key(cell)]
	_spawn_grass_pickups()
	queue_redraw()


func _build_stone_cells() -> void:
	_stone_cells.clear()
	if _world == null or _catalog == null:
		return

	var first_cell := _catalog.world_origin_cell
	var last_cell := _catalog.last_world_cell_exclusive()
	for tile_y in range(first_cell.y, last_cell.y):
		for tile_x in range(first_cell.x, last_cell.x):
			var cell := Vector2i(tile_x, tile_y)
			if not _is_available_ground_cell(cell, STONE_CLEARANCE):
				continue
			if _hash_2d(cell.x + 53, cell.y - 89) > STONE_DENSITY:
				continue

			_stone_cells.append(cell)


func _build_grass_cells() -> void:
	_grass_cells.clear()
	_grass_kind_by_cell.clear()
	if _world == null or _catalog == null:
		return

	var first_cell := _catalog.world_origin_cell
	var last_cell := _catalog.last_world_cell_exclusive()
	for tile_y in range(first_cell.y, last_cell.y):
		for tile_x in range(first_cell.x, last_cell.x):
			var cell := Vector2i(tile_x, tile_y)
			if (
				not _is_available_ground_cell(cell, GRASS_CLEARANCE)
				or _stone_cells.has(cell)
			):
				continue

			var density_value := _hash_2d(cell.x + 431, cell.y - 271)
			var kind: StringName
			if density_value <= GRASS_MEDIUM_DENSITY:
				kind = GRASS_MEDIUM_KIND
			elif density_value <= GRASS_MEDIUM_DENSITY + GRASS_LOW_DENSITY:
				kind = GRASS_LOW_KIND
			else:
				continue

			_grass_cells.append(cell)
			_grass_kind_by_cell[_cell_key(cell)] = kind


func _is_available_ground_cell(cell: Vector2i, clearance: float) -> bool:
	if not _world.is_grass_tile(cell):
		return false

	var center := _world.tile_center(cell)
	if _world.is_position_reserved(center, clearance):
		return false
	if center.distance_to(_catalog.player_spawn) < _catalog.tile_size * PLAYER_CLEARANCE_TILES:
		return false
	if center.distance_to(_catalog.plaza) < _catalog.tile_size * PLAZA_CLEARANCE_TILES:
		return false
	return true


func _spawn_stone_pickups() -> void:
	if _stone_item == null or _interaction_system == null:
		return

	for cell in _stone_cells:
		var pickup := GroundStonePickup.new()
		pickup.initialize(cell, _world.tile_center(cell))
		add_child(pickup)
		pickup.interaction_requested.connect(_on_stone_interaction_requested)
		_interaction_system.register_interactable(pickup)
		_stone_pickups[_cell_key(cell)] = pickup


func _spawn_grass_pickups() -> void:
	if _grass_item == null or _interaction_system == null:
		return

	for cell in _grass_cells:
		var kind := _grass_kind_by_cell.get(_cell_key(cell), GRASS_LOW_KIND) as StringName
		var pickup := GroundGrassPickup.new()
		pickup.initialize(
			cell,
			_world.tile_center(cell),
			_grass_yield_for_kind(kind)
		)
		add_child(pickup)
		pickup.interaction_requested.connect(_on_grass_interaction_requested)
		_interaction_system.register_interactable(pickup)
		_grass_pickups[_cell_key(cell)] = pickup


func _clear_stone_pickups() -> void:
	for value in _stone_pickups.values():
		var pickup := value as GroundStonePickup
		if pickup == null:
			continue
		if _interaction_system != null:
			_interaction_system.unregister_interactable(pickup)
		if is_instance_valid(pickup):
			pickup.queue_free()
	_stone_pickups.clear()


func _clear_grass_pickups() -> void:
	for value in _grass_pickups.values():
		var pickup := value as GroundGrassPickup
		if pickup == null:
			continue
		if _interaction_system != null:
			_interaction_system.unregister_interactable(pickup)
		if is_instance_valid(pickup):
			pickup.queue_free()
	_grass_pickups.clear()


func _on_stone_interaction_requested(target: Node2D, _source: Node2D) -> void:
	var pickup := target as GroundStonePickup
	if (
		pickup == null
		or _inventory == null
		or _stone_item == null
		or not _stone_cells.has(pickup.cell)
	):
		return

	if _inventory.add_item(_stone_item, 1) != 1:
		return

	_stone_cells.erase(pickup.cell)
	_stone_pickups.erase(_cell_key(pickup.cell))
	if _interaction_system != null:
		_interaction_system.unregister_interactable(pickup)
	pickup.set_interaction_active(false)
	pickup.queue_free()
	queue_redraw()
	stone_picked.emit()


func _on_grass_interaction_requested(target: Node2D, _source: Node2D) -> void:
	var pickup := target as GroundGrassPickup
	if (
		pickup == null
		or _inventory == null
		or _grass_item == null
		or not _grass_cells.has(pickup.cell)
	):
		return

	if _inventory.add_item(_grass_item, pickup.yield_amount) != pickup.yield_amount:
		return

	_grass_cells.erase(pickup.cell)
	_grass_kind_by_cell.erase(_cell_key(pickup.cell))
	_grass_pickups.erase(_cell_key(pickup.cell))
	if _interaction_system != null:
		_interaction_system.unregister_interactable(pickup)
	pickup.set_interaction_active(false)
	pickup.queue_free()
	queue_redraw()
	grass_picked.emit(pickup.yield_amount)


func _grass_yield_for_kind(kind: StringName) -> int:
	return GRASS_MEDIUM_YIELD if kind == GRASS_MEDIUM_KIND else GRASS_LOW_YIELD


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


func _draw() -> void:
	if _catalog == null or _world == null:
		return

	if _stone_texture != null:
		var texture_size := Vector2(
			_stone_texture.get_width(),
			_stone_texture.get_height()
		)
		for cell in _stone_cells:
			var position := _world.tile_center(cell)
			var offset := Vector2(
				(_hash_2d(cell.x + 101, cell.y + 17) - 0.5) * _catalog.tile_size * 0.26,
				(_hash_2d(cell.x - 37, cell.y + 73) - 0.5) * _catalog.tile_size * 0.14
				+ _catalog.tile_size * 0.08
			)
			var rotation := lerpf(
				-0.14,
				0.14,
				_hash_2d(cell.x + 211, cell.y - 131)
			)
			var scale_value := lerpf(
				0.064,
				0.086,
				_hash_2d(cell.x - 167, cell.y + 197)
			)

			draw_set_transform(
				position + offset,
				rotation,
				Vector2.ONE * scale_value
			)
			draw_texture_rect(
				_stone_texture,
				Rect2(-texture_size / 2.0, texture_size),
				false
			)

	for cell in _grass_cells:
		var kind := _grass_kind_by_cell.get(_cell_key(cell), GRASS_LOW_KIND) as StringName
		var texture: Texture2D = (
			_grass_medium_texture if kind == GRASS_MEDIUM_KIND else _grass_low_texture
		)
		if texture == null:
			continue

		var grass_texture_size := Vector2(texture.get_width(), texture.get_height())
		var offset := Vector2(
			(_hash_2d(cell.x + 601, cell.y + 47) - 0.5) * _catalog.tile_size * 0.24,
			(_hash_2d(cell.x - 113, cell.y + 389) - 0.5) * _catalog.tile_size * 0.12
			+ _catalog.tile_size * 0.08
		)
		var rotation := lerpf(
			-0.16,
			0.16,
			_hash_2d(cell.x + 719, cell.y - 157)
		)
		var variation := _hash_2d(cell.x - 271, cell.y + 503)
		var scale_value := (
			lerpf(0.050, 0.064, variation)
			if kind == GRASS_MEDIUM_KIND
			else lerpf(0.085, 0.105, variation)
		)

		draw_set_transform(
			_world.tile_center(cell) + offset,
			rotation,
			Vector2.ONE * scale_value
		)
		draw_texture_rect(
			texture,
			Rect2(-grass_texture_size / 2.0, grass_texture_size),
			false
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hash_2d(x: int, y: int) -> float:
	var value := sin(x * 127.1 + y * 311.7) * 43758.5453123
	return value - floorf(value)
