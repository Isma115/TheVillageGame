extends Node2D
class_name GameWorld

const GRASS_TEXTURE: Texture2D = preload("res://assets/grass-texture.png")
const PATH_TEXTURE: Texture2D = preload("res://assets/stone-grass-texture.png")

var houses: Array[Dictionary] = []
var path_tiles: Array[Vector2i] = []
var path_tile_keys: Dictionary = {}
var path_routes: Array = []

func _init() -> void:
	for definition in GameConfig.houses():
		var house := definition.duplicate(true)
		house["texture"] = load("res://assets/" + house["asset"])
		houses.append(house)

	var center_x := GameConfig.WORLD_WIDTH / 2.0
	var plaza: Vector2 = GameConfig.PLAZA
	var cream_house: Dictionary = houses[0]
	var wood_house: Dictionary = houses[1]
	var stone_house: Dictionary = houses[2]

	path_routes = [
		[
			Vector2(center_x, GameConfig.WORLD_HEIGHT + 140.0),
			Vector2(center_x + 34.0, GameConfig.WORLD_HEIGHT - 980.0),
			Vector2(center_x - 22.0, plaza.y + 210.0),
			plaza
		],
		[
			plaza,
			Vector2(center_x - 170.0, plaza.y + 6.0),
			cream_house["position"]
		],
		[
			plaza,
			Vector2(center_x + 170.0, plaza.y + 6.0),
			wood_house["position"]
		],
		[
			plaza,
			Vector2(center_x, plaza.y - 145.0),
			stone_house["position"]
		]
	]

	_build_path_tiles()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, GameConfig.WORLD_WIDTH, GameConfig.WORLD_HEIGHT), GameConfig.GRASS_COLOR)

	for tile_y in range(GameConfig.WORLD_COLUMNS):
		for tile_x in range(GameConfig.WORLD_COLUMNS):
			var center := Vector2(
				tile_x * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0,
				tile_y * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
			)
			var rotation := floorf(_hash_2d(tile_x, tile_y) * 4.0) * (PI / 2.0)
			draw_set_transform(center, rotation, Vector2.ONE)
			draw_texture_rect(
				GRASS_TEXTURE,
				Rect2(-GameConfig.TILE_SIZE / 2.0, -GameConfig.TILE_SIZE / 2.0, GameConfig.TILE_SIZE, GameConfig.TILE_SIZE),
				false
			)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for tile in path_tiles:
		var path_center := Vector2(
			tile.x * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0,
			tile.y * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
		)
		var path_rotation := floorf(_hash_2d(tile.x + 41, tile.y - 17) * 4.0) * (PI / 2.0)
		draw_set_transform(path_center, path_rotation, Vector2.ONE)
		draw_texture_rect(
			PATH_TEXTURE,
			Rect2(-GameConfig.TILE_SIZE / 2.0, -GameConfig.TILE_SIZE / 2.0, GameConfig.TILE_SIZE, GameConfig.TILE_SIZE),
			false
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_path_transitions()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_path_transitions() -> void:
	for tile in path_tiles:
		var neighbors := [
			{"grid": Vector2i(tile.x - 1, tile.y), "side": "left"},
			{"grid": Vector2i(tile.x + 1, tile.y), "side": "right"},
			{"grid": Vector2i(tile.x, tile.y - 1), "side": "top"},
			{"grid": Vector2i(tile.x, tile.y + 1), "side": "bottom"}
		]

		for neighbor in neighbors:
			var neighbor_grid: Vector2i = neighbor["grid"]
			if path_tile_keys.has(_path_tile_key(neighbor_grid.x, neighbor_grid.y)):
				continue
			_draw_grass_transition(tile, neighbor["side"])

func _draw_grass_transition(tile: Vector2i, side: String) -> void:
	var tile_left := tile.x * GameConfig.TILE_SIZE
	var tile_top := tile.y * GameConfig.TILE_SIZE
	var segment_count := 8
	var segment_size := GameConfig.TILE_SIZE / float(segment_count)
	var fade_steps := 4
	var side_seed: int = int({"left": 11, "right": 17, "top": 23, "bottom": 29}[side])

	for segment in range(segment_count):
		var variation := _hash_2d(tile.x * 17 + segment * 7 + side_seed, tile.y * 31 + side_seed)
		var depth := GameConfig.TILE_SIZE * (0.24 + variation * 0.30)
		var band_size := depth / float(fade_steps)

		for step in range(fade_steps):
			var progress := float(step) / float(fade_steps - 1)
			var alpha := 0.94 * pow(1.0 - progress, 1.35)
			var band := Rect2(tile_left, tile_top, GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)

			match side:
				"left":
					band = Rect2(tile_left + step * band_size, tile_top + segment * segment_size, band_size + 1.0, segment_size + 1.0)
				"right":
					band = Rect2(tile_left + GameConfig.TILE_SIZE - (step + 1) * band_size, tile_top + segment * segment_size, band_size + 1.0, segment_size + 1.0)
				"top":
					band = Rect2(tile_left + segment * segment_size, tile_top + step * band_size, segment_size + 1.0, band_size + 1.0)
				"bottom":
					band = Rect2(tile_left + segment * segment_size, tile_top + GameConfig.TILE_SIZE - (step + 1) * band_size, segment_size + 1.0, band_size + 1.0)

			draw_rect(band, Color(GameConfig.GRASS_COLOR, alpha))

func _build_path_tiles() -> void:
	var tile_map: Dictionary = {}

	for route in path_routes:
		for index in range(1, route.size()):
			var start: Vector2 = route[index - 1]
			var finish: Vector2 = route[index]
			var distance := start.distance_to(finish)
			var samples := maxi(1, ceili(distance / (GameConfig.TILE_SIZE * 0.35)))

			for sample in range(samples + 1):
				var amount := float(sample) / float(samples)
				var point := start.lerp(finish, amount)
				var grid_x := floori(point.x / GameConfig.TILE_SIZE)
				var grid_y := floori(point.y / GameConfig.TILE_SIZE)
				_add_path_strip_tiles(tile_map, grid_x, grid_y, point, start, finish)

	var plaza_grid_x := floori(GameConfig.PLAZA.x / GameConfig.TILE_SIZE)
	var plaza_grid_y := floori(GameConfig.PLAZA.y / GameConfig.TILE_SIZE)
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			_add_path_tile(tile_map, plaza_grid_x + offset_x, plaza_grid_y + offset_y)

	path_tiles.assign(tile_map.values())
	path_tiles.sort_custom(_sort_tiles)
	for tile in path_tiles:
		path_tile_keys[_path_tile_key(tile.x, tile.y)] = true

func _add_path_strip_tiles(tile_map: Dictionary, grid_x: int, grid_y: int, point: Vector2, start: Vector2, finish: Vector2) -> void:
	_add_path_tile(tile_map, grid_x, grid_y)
	var horizontal := absf(finish.x - start.x) >= absf(finish.y - start.y)
	var tile_center := Vector2(
		grid_x * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0,
		grid_y * GameConfig.TILE_SIZE + GameConfig.TILE_SIZE / 2.0
	)

	if horizontal:
		_add_path_tile(tile_map, grid_x, grid_y - 1 if point.y < tile_center.y else grid_y + 1)
	else:
		_add_path_tile(tile_map, grid_x - 1 if point.x < tile_center.x else grid_x + 1, grid_y)

func _add_path_tile(tile_map: Dictionary, grid_x: int, grid_y: int) -> void:
	if grid_x < 0 or grid_y < 0 or grid_x >= GameConfig.WORLD_COLUMNS or grid_y >= GameConfig.WORLD_COLUMNS:
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
