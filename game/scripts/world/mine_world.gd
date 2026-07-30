extends Node2D
class_name MineWorld

const FLOOR_TILE_SIZE := 48.0

var definition: MineDefinition


func initialize(mine_definition: MineDefinition) -> void:
	definition = mine_definition
	queue_redraw()


func collision_obstacles() -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	if definition == null:
		return rectangles
	for obstacle in definition.interior_obstacles:
		rectangles.append(obstacle)
	return rectangles


func obstacle_count() -> int:
	return definition.interior_obstacles.size() if definition != null else 0


func _draw() -> void:
	if definition == null:
		return

	draw_rect(definition.world_rect(), definition.void_color)
	draw_rect(definition.playable_bounds(), definition.floor_color)
	_draw_floor_details()
	_draw_wall_border()
	for index in range(definition.interior_obstacles.size()):
		_draw_boulder_field(definition.interior_obstacles[index], index)
	_draw_wall_lamp(Vector2(definition.wall_inset * 0.62, definition.interior_size.y * 0.50))
	_draw_wall_lamp(
		Vector2(
			definition.interior_size.x - definition.wall_inset * 0.62,
			definition.interior_size.y * 0.50
		)
	)


func _draw_floor_details() -> void:
	var bounds := definition.playable_bounds()
	var first_x := floori(bounds.position.x / FLOOR_TILE_SIZE)
	var first_y := floori(bounds.position.y / FLOOR_TILE_SIZE)
	var last_x := ceili(bounds.end.x / FLOOR_TILE_SIZE)
	var last_y := ceili(bounds.end.y / FLOOR_TILE_SIZE)

	for tile_y in range(first_y, last_y):
		for tile_x in range(first_x, last_x):
			var center := Vector2(
				tile_x * FLOOR_TILE_SIZE + FLOOR_TILE_SIZE / 2.0,
				tile_y * FLOOR_TILE_SIZE + FLOOR_TILE_SIZE / 2.0
			)
			if not bounds.has_point(center):
				continue
			var variation := _hash_2d(tile_x, tile_y)
			if variation > 0.42:
				var radius := 1.4 + variation * 2.2
				draw_circle(
					center + Vector2(
						_hash_2d(tile_x + 19, tile_y) * 18.0 - 9.0,
						_hash_2d(tile_x, tile_y + 23) * 18.0 - 9.0
					),
					radius,
					Color(definition.floor_light_color, 0.34)
				)
			if variation < 0.16:
				var crack_start := center + Vector2(-9.0, 2.0)
				draw_polyline(
					PackedVector2Array([
						crack_start,
						crack_start + Vector2(7.0, -3.0),
						crack_start + Vector2(13.0, 3.0)
					]),
					Color(definition.crack_color, 0.66),
					2.0,
					true
				)


func _draw_wall_border() -> void:
	var bounds := definition.playable_bounds()
	var spacing := 42.0
	var horizontal_count := ceili(bounds.size.x / spacing)
	var vertical_count := ceili(bounds.size.y / spacing)

	for index in range(horizontal_count + 1):
		var x := bounds.position.x + minf(index * spacing, bounds.size.x)
		_draw_wall_rock(Vector2(x, bounds.position.y - 18.0), index)
		_draw_wall_rock(Vector2(x, bounds.end.y + 18.0), index + 500)
	for index in range(vertical_count + 1):
		var y := bounds.position.y + minf(index * spacing, bounds.size.y)
		_draw_wall_rock(Vector2(bounds.position.x - 18.0, y), index + 1000)
		_draw_wall_rock(Vector2(bounds.end.x + 18.0, y), index + 1500)


func _draw_wall_rock(center: Vector2, seed_value: int) -> void:
	var width := 27.0 + _hash_2d(seed_value, 3) * 15.0
	var height := 22.0 + _hash_2d(seed_value, 7) * 13.0
	draw_set_transform(center, 0.0, Vector2(width, height))
	draw_circle(Vector2.ZERO, 1.0, definition.wall_color)
	draw_circle(
		Vector2(-0.18, -0.18),
		0.52,
		Color(definition.wall_light_color, 0.66)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_boulder_field(rectangle: Rect2, seed_value: int) -> void:
	draw_rect(rectangle, Color(definition.wall_color, 0.92))
	var columns := maxi(2, ceili(rectangle.size.x / 44.0))
	var rows := maxi(2, ceili(rectangle.size.y / 40.0))
	for row in range(rows):
		for column in range(columns):
			var center := Vector2(
				rectangle.position.x + (float(column) + 0.5) * rectangle.size.x / columns,
				rectangle.position.y + (float(row) + 0.5) * rectangle.size.y / rows
			)
			center += Vector2(
				_hash_2d(seed_value + column, row + 31) * 12.0 - 6.0,
				_hash_2d(seed_value + row, column + 47) * 10.0 - 5.0
			)
			var radius := minf(rectangle.size.x / columns, rectangle.size.y / rows) * 0.55
			draw_circle(center, radius, definition.wall_color)
			draw_circle(
				center + Vector2(-radius * 0.22, -radius * 0.24),
				radius * 0.48,
				Color(definition.wall_light_color, 0.72)
			)


func _draw_wall_lamp(center: Vector2) -> void:
	draw_circle(center, 48.0, Color(definition.lamp_color, 0.035))
	draw_circle(center, 26.0, Color(definition.lamp_color, 0.07))
	draw_rect(Rect2(center - Vector2(6.0, 9.0), Vector2(12.0, 18.0)), Color("#4a3527"))
	draw_circle(center, 6.0, definition.lamp_color)


func _hash_2d(x: int, y: int) -> float:
	var value := sin(x * 127.1 + y * 311.7 + definition.random_seed) * 43758.5453123
	return value - floorf(value)
