extends Node2D
class_name GameWorld

const WATER_COLOR := Color("#2c8ca1")
const WATER_BLOCK_EDGE_COLOR := Color(0.46, 0.78, 0.78, 0.55)
const WATER_SHORE_COLOR := Color("#75c7c7")
const WATER_HIGHLIGHT_COLOR := Color(0.78, 0.97, 0.97, 0.58)
const WATER_SECONDARY_HIGHLIGHT_COLOR := Color(0.78, 0.97, 0.97, 0.38)
const WATER_FRAME_COUNT := 3
const WATER_FRAME_DURATION := 0.45
const WATER_FRAME_COLORS := [
	Color("#2c8ca1"),
	Color("#3093a5"),
	Color("#28879e")
]

@export var house_scene: PackedScene

var catalog: GameCatalog
var houses: Array[HouseActor] = []
var water_cells: Array[Vector2i] = []
var water_tile_keys: Dictionary = {}
var path_tiles: Array[Vector2i] = []
var path_tile_keys: Dictionary = {}
var placement_reservations: Dictionary = {}
var _water_animation_elapsed := 0.0
var _water_animation_state := 0
@onready var water_animation_layer: Node = get_node_or_null("WaterAnimationLayer")
var view_camera: Camera2D
var _visible_world_rect := Rect2()
var _visible_draw_rect := Rect2()
var _visible_first_cell := Vector2i.ZERO
var _visible_last_cell := Vector2i.ZERO
var _visible_region_initialized := false


func initialize(
	game_catalog: GameCatalog,
	actor_layer: Node2D,
	camera: Camera2D = null
) -> void:
	catalog = game_catalog
	view_camera = camera
	_visible_region_initialized = false
	_clear_water_tiles()
	_clear_houses()
	placement_reservations.clear()
	_water_animation_elapsed = 0.0
	_water_animation_state = 0
	_configure_water_tiles()
	if water_animation_layer != null:
		water_animation_layer.call("initialize", catalog, water_cells, view_camera)

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
	_refresh_visible_region(true)
	queue_redraw()


func set_view_camera(camera: Camera2D) -> void:
	view_camera = camera
	_visible_region_initialized = false
	if water_animation_layer != null:
		water_animation_layer.call("set_view_camera", view_camera)
	_refresh_visible_region(true)


func refresh_camera_culling() -> void:
	_refresh_visible_region()


func _process(_delta: float) -> void:
	_refresh_visible_region()


func _refresh_visible_region(force: bool = false) -> void:
	if catalog == null or catalog.tile_size <= 0.0:
		return

	var camera_rect := _camera_world_rect()
	var world_rect := catalog.world_rect()
	var clipped_rect := camera_rect.intersection(world_rect)
	var first_cell := catalog.world_origin_cell
	var last_cell := catalog.world_origin_cell
	if clipped_rect.size.x > 0.0 and clipped_rect.size.y > 0.0:
		first_cell = Vector2i(
			clampi(
				floori(clipped_rect.position.x / catalog.tile_size),
				catalog.world_origin_cell.x,
				catalog.last_world_cell_exclusive().x
			),
			clampi(
				floori(clipped_rect.position.y / catalog.tile_size),
				catalog.world_origin_cell.y,
				catalog.last_world_cell_exclusive().y
			)
		)
		last_cell = Vector2i(
			clampi(
				ceili(clipped_rect.end.x / catalog.tile_size),
				catalog.world_origin_cell.x,
				catalog.last_world_cell_exclusive().x
			),
			clampi(
				ceili(clipped_rect.end.y / catalog.tile_size),
				catalog.world_origin_cell.y,
				catalog.last_world_cell_exclusive().y
			)
		)

	var draw_rect := Rect2(
		Vector2(first_cell) * catalog.tile_size,
		Vector2(last_cell - first_cell) * catalog.tile_size
	)
	var changed := (
		force
		or not _visible_region_initialized
		or first_cell != _visible_first_cell
		or last_cell != _visible_last_cell
	)
	_visible_world_rect = camera_rect
	_visible_draw_rect = draw_rect
	_visible_first_cell = first_cell
	_visible_last_cell = last_cell
	_visible_region_initialized = true
	if changed:
		queue_redraw()


func _camera_world_rect() -> Rect2:
	if (
		view_camera == null
		or not is_instance_valid(view_camera)
		or catalog == null
	):
		return catalog.world_rect() if catalog != null else Rect2()

	var viewport_size := view_camera.get_viewport_rect().size
	var zoom := view_camera.zoom
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return catalog.world_rect()

	var world_size := Vector2(
		viewport_size.x / maxf(absf(zoom.x), 0.01),
		viewport_size.y / maxf(absf(zoom.y), 0.01)
	)
	return Rect2(
		view_camera.get_screen_center_position() - world_size * 0.5,
		world_size
	)


func collision_obstacles() -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	for house in catalog.house_definitions():
		rectangles.append(house.world_collision_rect())
	for cell in water_cells:
		rectangles.append(_tile_rectangle(cell))
	return rectangles


func house_count() -> int:
	return houses.size()


func water_block_count() -> int:
	return water_cells.size()


func has_water_source() -> bool:
	return not water_cells.is_empty()


func path_tile_count() -> int:
	return path_tiles.size()


func cell_for_world_position(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / catalog.tile_size),
		floori(world_position.y / catalog.tile_size)
	)


func tile_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * catalog.tile_size + Vector2.ONE * catalog.tile_size / 2.0


func is_valid_cell(cell: Vector2i) -> bool:
	return catalog != null and catalog.is_valid_cell(cell)


func is_grass_tile(cell: Vector2i) -> bool:
	return (
		is_valid_cell(cell)
		and not path_tile_keys.has(_path_tile_key(cell.x, cell.y))
		and not is_water_tile(cell)
	)


func is_water_tile(cell: Vector2i) -> bool:
	return is_valid_cell(cell) and water_tile_keys.has(_path_tile_key(cell.x, cell.y))


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


func _clear_water_tiles() -> void:
	water_cells.clear()
	water_tile_keys.clear()


func _configure_water_tiles() -> void:
	if (
		catalog == null
		or catalog.tile_size <= 0.0
		or catalog.lake_size.x <= 0.0
		or catalog.lake_size.y <= 0.0
	):
		return

	var lake_columns := maxi(1, roundi(catalog.lake_size.x / catalog.tile_size))
	var lake_rows := maxi(1, roundi(catalog.lake_size.y / catalog.tile_size))
	var lake_origin := catalog.lake_position - Vector2(
		lake_columns * catalog.tile_size,
		lake_rows * catalog.tile_size
	) / 2.0
	var origin_cell := Vector2i(
		roundi(lake_origin.x / catalog.tile_size),
		roundi(lake_origin.y / catalog.tile_size)
	)
	var shape: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)
	]

	for offset in shape:
		if offset.x >= lake_columns or offset.y >= lake_rows:
			continue
		var cell := origin_cell + offset
		if not is_valid_cell(cell):
			continue
		water_cells.append(cell)
		water_tile_keys[_path_tile_key(cell.x, cell.y)] = true

	for index in range(water_cells.size()):
		register_placement_reservation(
			StringName("water:%d" % index),
			_tile_rectangle(water_cells[index]).grow(12.0)
		)


func _tile_rectangle(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(cell) * catalog.tile_size,
		Vector2.ONE * catalog.tile_size
	)


func _draw() -> void:
	if catalog == null:
		return

	var world_rect := catalog.world_rect()
	var visible_world_rect := _visible_draw_rect.intersection(world_rect)
	if visible_world_rect.size.x > 0.0 and visible_world_rect.size.y > 0.0:
		draw_rect(visible_world_rect, catalog.grass_color)

	var first_cell := _visible_first_cell
	var last_cell := _visible_last_cell
	for tile_y in range(first_cell.y, last_cell.y):
		for tile_x in range(first_cell.x, last_cell.x):
			var cell := Vector2i(tile_x, tile_y)
			if is_water_tile(cell):
				continue

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
		if (
			is_water_tile(tile)
			or not _tile_rectangle(tile).intersects(_visible_draw_rect)
		):
			continue
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
	_draw_path_transitions(_visible_draw_rect)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_water_tile(cell: Vector2i) -> void:
	var rectangle := _tile_rectangle(cell)
	var water_color: Color = WATER_FRAME_COLORS[_water_animation_state]
	draw_rect(rectangle, water_color)
	_draw_water_shimmer(rectangle)


func _draw_water_shimmer(rectangle: Rect2) -> void:
	match _water_animation_state:
		0:
			_draw_water_reflection(
				rectangle,
				0.29,
				0.16,
				0.58,
				WATER_HIGHLIGHT_COLOR
			)
			_draw_water_reflection(
				rectangle,
				0.68,
				0.42,
				0.82,
				WATER_SECONDARY_HIGHLIGHT_COLOR
			)
		1:
			_draw_water_reflection(
				rectangle,
				0.42,
				0.30,
				0.76,
				WATER_HIGHLIGHT_COLOR
			)
			_draw_water_reflection(
				rectangle,
				0.74,
				0.12,
				0.48,
				WATER_SECONDARY_HIGHLIGHT_COLOR
			)
		2:
			_draw_water_reflection(
				rectangle,
				0.58,
				0.18,
				0.62,
				WATER_HIGHLIGHT_COLOR
			)
			_draw_water_reflection(
				rectangle,
				0.31,
				0.54,
				0.88,
				WATER_SECONDARY_HIGHLIGHT_COLOR
			)


func _draw_water_reflection(
	rectangle: Rect2,
	y_ratio: float,
	start_ratio: float,
	end_ratio: float,
	color: Color
) -> void:
	var y := rectangle.position.y + catalog.tile_size * y_ratio
	draw_line(
		Vector2(rectangle.position.x + catalog.tile_size * start_ratio, y),
		Vector2(rectangle.position.x + catalog.tile_size * end_ratio, y),
		color,
		2.0,
		true
	)


func _draw_water_boundary_edges(
	cell: Vector2i,
	rectangle: Rect2,
	color: Color,
	width: float
) -> void:
	if not is_water_tile(cell + Vector2i(-1, 0)):
		draw_line(
			rectangle.position,
			rectangle.position + Vector2(0.0, catalog.tile_size),
			color,
			width,
			true
		)
	if not is_water_tile(cell + Vector2i(1, 0)):
		draw_line(
			rectangle.position + Vector2(catalog.tile_size, 0.0),
			rectangle.position + Vector2(catalog.tile_size, catalog.tile_size),
			color,
			width,
			true
		)
	if not is_water_tile(cell + Vector2i(0, -1)):
		draw_line(
			rectangle.position,
			rectangle.position + Vector2(catalog.tile_size, 0.0),
			color,
			width,
			true
		)
	if not is_water_tile(cell + Vector2i(0, 1)):
		draw_line(
			rectangle.position + Vector2(0.0, catalog.tile_size),
			rectangle.position + Vector2(catalog.tile_size, catalog.tile_size),
			color,
			width,
			true
		)


func _draw_path_transitions(visible_rect: Rect2) -> void:
	for tile in path_tiles:
		if (
			is_water_tile(tile)
			or not _tile_rectangle(tile).intersects(visible_rect)
		):
			continue
		var neighbors := [
			{"grid": Vector2i(tile.x - 1, tile.y), "side": &"left"},
			{"grid": Vector2i(tile.x + 1, tile.y), "side": &"right"},
			{"grid": Vector2i(tile.x, tile.y - 1), "side": &"top"},
			{"grid": Vector2i(tile.x, tile.y + 1), "side": &"bottom"}
		]

		for neighbor in neighbors:
			var neighbor_grid: Vector2i = neighbor["grid"]
			if (
				path_tile_keys.has(_path_tile_key(neighbor_grid.x, neighbor_grid.y))
				or is_water_tile(neighbor_grid)
			):
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
	if not catalog.is_valid_cell(Vector2i(grid_x, grid_y)):
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
