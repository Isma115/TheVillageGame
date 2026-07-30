extends Node2D
class_name GameWorld

@export var house_scene: PackedScene

var catalog: GameCatalog
var houses: Array[HouseActor] = []
var path_tiles: Array[Vector2i] = []
var path_tile_keys: Dictionary = {}
var placement_reservations: Dictionary = {}


func initialize(game_catalog: GameCatalog, actor_layer: Node2D) -> void:
	catalog = game_catalog
	_clear_houses()
	placement_reservations.clear()

	if house_scene == null:
		push_error("GameWorld necesita una escena de casa.")
		return

	for definition in catalog.house_definitions():
		var house := house_scene.instantiate() as HouseActor
		if house == null:
			push_error("La escena de casa no crea un HouseActor.")
			continue
		house.configure(definition)
		actor_layer.add_child(house)
		houses.append(house)
		register_placement_reservation(
			StringName("house:%s" % definition.id),
			definition.world_collision_rect()
		)

	_build_path_tiles()
	queue_redraw()


func collision_obstacles() -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	for house in catalog.house_definitions():
		rectangles.append(house.world_collision_rect())
	return rectangles


func house_count() -> int:
	return houses.size()


func path_tile_count() -> int:
	return path_tiles.size()


func is_position_near_path(world_position: Vector2, clearance: float) -> bool:
	var center_cell := Vector2i(
		floori(world_position.x / catalog.tile_size),
		floori(world_position.y / catalog.tile_size)
	)
	var cell_radius := maxi(1, ceili(maxf(clearance, 0.0) / catalog.tile_size) + 1)

	for offset_y in range(-cell_radius, cell_radius + 1):
		for offset_x in range(-cell_radius, cell_radius + 1):
			var cell := center_cell + Vector2i(offset_x, offset_y)
			if not path_tile_keys.has(_path_tile_key(cell.x, cell.y)):
				continue

			var tile_rectangle := Rect2(
				Vector2(cell) * catalog.tile_size,
				Vector2.ONE * catalog.tile_size
			).grow(maxf(clearance, 0.0))
			if tile_rectangle.has_point(world_position):
				return true

	return false


func register_placement_reservation(reservation_id: StringName, rectangle: Rect2) -> void:
	if (
		String(reservation_id).is_empty()
		or rectangle.size.x <= 0.0
		or rectangle.size.y <= 0.0
	):
		return
	placement_reservations[reservation_id] = rectangle


func unregister_placement_reservation(reservation_id: StringName) -> void:
	placement_reservations.erase(reservation_id)


func is_position_reserved(world_position: Vector2, clearance: float) -> bool:
	for rectangle in placement_reservations.values():
		var reserved_rectangle: Rect2 = rectangle
		if reserved_rectangle.grow(maxf(clearance, 0.0)).has_point(world_position):
			return true
	return false


func placement_reservation_count() -> int:
	return placement_reservations.size()


func _clear_houses() -> void:
	for house in houses:
		if is_instance_valid(house):
			house.queue_free()
	houses.clear()


func _draw() -> void:
	if catalog == null:
		return

	var size := catalog.world_size()
	draw_rect(Rect2(Vector2.ZERO, size), catalog.grass_color)

	for tile_y in range(catalog.world_rows):
		for tile_x in range(catalog.world_columns):
			var center := Vector2(
				tile_x * catalog.tile_size + catalog.tile_size / 2.0,
				tile_y * catalog.tile_size + catalog.tile_size / 2.0
			)
			var rotation := floorf(_hash_2d(tile_x, tile_y) * 4.0) * (PI / 2.0)
			draw_set_transform(center, rotation, Vector2.ONE)
			draw_texture_rect(
				catalog.grass_texture,
				Rect2(-catalog.tile_size / 2.0, -catalog.tile_size / 2.0, catalog.tile_size, catalog.tile_size),
				false
			)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for tile in path_tiles:
		var path_center := Vector2(
			tile.x * catalog.tile_size + catalog.tile_size / 2.0,
			tile.y * catalog.tile_size + catalog.tile_size / 2.0
		)
		var path_rotation := floorf(_hash_2d(tile.x + 41, tile.y - 17) * 4.0) * (PI / 2.0)
		draw_set_transform(path_center, path_rotation, Vector2.ONE)
		draw_texture_rect(
			catalog.path_texture,
			Rect2(-catalog.tile_size / 2.0, -catalog.tile_size / 2.0, catalog.tile_size, catalog.tile_size),
			false
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_path_transitions()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_path_transitions() -> void:
	for tile in path_tiles:
		var neighbors := [
			{"grid": Vector2i(tile.x - 1, tile.y), "side": &"left"},
			{"grid": Vector2i(tile.x + 1, tile.y), "side": &"right"},
			{"grid": Vector2i(tile.x, tile.y - 1), "side": &"top"},
			{"grid": Vector2i(tile.x, tile.y + 1), "side": &"bottom"}
		]

		for neighbor in neighbors:
			var neighbor_grid: Vector2i = neighbor["grid"]
			if path_tile_keys.has(_path_tile_key(neighbor_grid.x, neighbor_grid.y)):
				continue
			_draw_grass_transition(tile, neighbor["side"])


func _draw_grass_transition(tile: Vector2i, side: StringName) -> void:
	var tile_origin := Vector2(tile.x * catalog.tile_size, tile.y * catalog.tile_size)
	var segment_count := 8
	var segment_size := catalog.tile_size / float(segment_count)
	var fade_steps := 4
	var side_seed: int = int({
		&"left": 11,
		&"right": 17,
		&"top": 23,
		&"bottom": 29
	}[side])
	var texture_size := Vector2(catalog.grass_texture.get_width(), catalog.grass_texture.get_height())

	for segment in range(segment_count):
		var variation := _hash_2d(tile.x * 17 + segment * 7 + side_seed, tile.y * 31 + side_seed)
		var depth := catalog.tile_size * (0.24 + variation * 0.30)
		var band_size := depth / float(fade_steps)

		for step in range(fade_steps):
			var progress := float(step) / float(fade_steps - 1)
			var alpha := 0.94 * pow(1.0 - progress, 1.35)
			var band := Rect2(tile_origin, Vector2(catalog.tile_size, catalog.tile_size))

			match side:
				&"left":
					band = Rect2(tile_origin + Vector2(step * band_size, segment * segment_size), Vector2(band_size + 1.0, segment_size + 1.0))
				&"right":
					band = Rect2(tile_origin + Vector2(catalog.tile_size - (step + 1) * band_size, segment * segment_size), Vector2(band_size + 1.0, segment_size + 1.0))
				&"top":
					band = Rect2(tile_origin + Vector2(segment * segment_size, step * band_size), Vector2(segment_size + 1.0, band_size + 1.0))
				&"bottom":
					band = Rect2(tile_origin + Vector2(segment * segment_size, catalog.tile_size - (step + 1) * band_size), Vector2(segment_size + 1.0, band_size + 1.0))

			var source := Rect2(
				(band.position - tile_origin) / catalog.tile_size * texture_size,
				band.size / catalog.tile_size * texture_size
			)
			draw_texture_rect_region(
				catalog.grass_texture,
				band,
				source,
				Color(1.0, 1.0, 1.0, alpha),
				false,
				true
			)


func _build_path_tiles() -> void:
	var tile_map: Dictionary = {}
	path_tiles.clear()
	path_tile_keys.clear()

	for route in catalog.route_definitions():
		for index in range(1, route.points.size()):
			var start := route.points[index - 1]
			var finish := route.points[index]
			var distance := start.distance_to(finish)
			var samples := maxi(1, ceili(distance / (catalog.tile_size * 0.35)))

			for sample in range(samples + 1):
				var amount := float(sample) / float(samples)
				var point := start.lerp(finish, amount)
				var grid_x := floori(point.x / catalog.tile_size)
				var grid_y := floori(point.y / catalog.tile_size)
				_add_path_strip_tiles(tile_map, grid_x, grid_y, point, start, finish)

	var plaza_grid_x := floori(catalog.plaza.x / catalog.tile_size)
	var plaza_grid_y := floori(catalog.plaza.y / catalog.tile_size)
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			_add_path_tile(tile_map, plaza_grid_x + offset_x, plaza_grid_y + offset_y)

	path_tiles.assign(tile_map.values())
	path_tiles.sort_custom(_sort_tiles)
	for tile in path_tiles:
		path_tile_keys[_path_tile_key(tile.x, tile.y)] = true


func _add_path_strip_tiles(
	tile_map: Dictionary,
	grid_x: int,
	grid_y: int,
	point: Vector2,
	start: Vector2,
	finish: Vector2
) -> void:
	_add_path_tile(tile_map, grid_x, grid_y)
	var horizontal := absf(finish.x - start.x) >= absf(finish.y - start.y)
	var tile_center := Vector2(
		grid_x * catalog.tile_size + catalog.tile_size / 2.0,
		grid_y * catalog.tile_size + catalog.tile_size / 2.0
	)

	if horizontal:
		_add_path_tile(tile_map, grid_x, grid_y - 1 if point.y < tile_center.y else grid_y + 1)
	else:
		_add_path_tile(tile_map, grid_x - 1 if point.x < tile_center.x else grid_x + 1, grid_y)


func _add_path_tile(tile_map: Dictionary, grid_x: int, grid_y: int) -> void:
	if grid_x < 0 or grid_y < 0 or grid_x >= catalog.world_columns or grid_y >= catalog.world_rows:
		return
	tile_map[_path_tile_key(grid_x, grid_y)] = Vector2i(grid_x, grid_y)


func _sort_tiles(first: Vector2i, second: Vector2i) -> bool:
	if first.y != second.y:
		return first.y < second.y
	return first.x < second.x


func _path_tile_key(grid_x: int, grid_y: int) -> String:
	return "%d:%d" % [grid_x, grid_y]


func _hash_2d(x: int, y: int) -> float:
	var value := sin(x * 127.1 + y * 311.7) * 43758.5453123
	return value - floorf(value)
