extends Node2D
class_name GroundDecorationLayer

const STONE_TEXTURE_PATH := "res://assets/terrain/ground-stone.png"
const STONE_ITEM_ID: StringName = &"stone"
const STONE_DENSITY := 0.020
const STONE_CLEARANCE := 8.0
const PLAYER_CLEARANCE_TILES := 2.5
const PLAZA_CLEARANCE_TILES := 2.0

signal stone_picked

var _world: GameWorld
var _catalog: GameCatalog
var _stone_texture: Texture2D
var _interaction_system: InteractionSystem
var _inventory: InventoryService
var _stone_item: ItemDefinition
var _stone_cells: Array[Vector2i] = []
var _stone_pickups: Dictionary = {}


func _ready() -> void:
	_stone_texture = ResourceLoader.load(STONE_TEXTURE_PATH, "Texture2D") as Texture2D


func initialize(
	game_world: GameWorld,
	game_catalog: GameCatalog,
	interaction_system: InteractionSystem,
	inventory: InventoryService
) -> void:
	_clear_stone_pickups()
	_world = game_world
	_catalog = game_catalog
	_interaction_system = interaction_system
	_inventory = inventory
	_stone_item = inventory.definition_for(STONE_ITEM_ID) if inventory != null else null
	_build_stone_cells()
	_spawn_stone_pickups()
	queue_redraw()


func stone_count() -> int:
	return _stone_cells.size()


func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in _stone_cells:
		result.append({
			"x": cell.x,
			"y": cell.y
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


func _build_stone_cells() -> void:
	_stone_cells.clear()
	if _world == null or _catalog == null:
		return

	var first_cell := _catalog.world_origin_cell
	var last_cell := _catalog.last_world_cell_exclusive()
	for tile_y in range(first_cell.y, last_cell.y):
		for tile_x in range(first_cell.x, last_cell.x):
			var cell := Vector2i(tile_x, tile_y)
			if not _world.is_grass_tile(cell):
				continue

			var center := _world.tile_center(cell)
			if _world.is_position_reserved(center, STONE_CLEARANCE):
				continue
			if center.distance_to(_catalog.player_spawn) < _catalog.tile_size * PLAYER_CLEARANCE_TILES:
				continue
			if center.distance_to(_catalog.plaza) < _catalog.tile_size * PLAZA_CLEARANCE_TILES:
				continue
			if _hash_2d(cell.x + 53, cell.y - 89) > STONE_DENSITY:
				continue

			_stone_cells.append(cell)


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


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


func _draw() -> void:
	if _stone_texture == null or _catalog == null or _world == null:
		return

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

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _hash_2d(x: int, y: int) -> float:
	var value := sin(x * 127.1 + y * 311.7) * 43758.5453123
	return value - floorf(value)
