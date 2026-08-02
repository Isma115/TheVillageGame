extends Node2D
class_name HotelWorld

var definition: HotelDefinition

func initialize(next_definition: HotelDefinition) -> void:
	definition = next_definition
	queue_redraw()

func world_rect() -> Rect2:
	return definition.world_rect() if definition != null else Rect2()

func playable_bounds() -> Rect2:
	return definition.playable_bounds() if definition != null else Rect2()

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
	var bounds := definition.playable_bounds()
	draw_rect(definition.world_rect(), definition.void_color)
	draw_rect(bounds, definition.floor_color)
	_draw_floor_tiles(bounds)
	_draw_walls(bounds)
	_draw_reception()
	_draw_lounge()
	_draw_fireplace()
	_draw_kitchen()
	_draw_hotel_sign()

func _draw_floor_tiles(bounds: Rect2) -> void:
	var tile_size := 48.0
	var columns := int(ceil(bounds.size.x / tile_size))
	var rows := int(ceil(bounds.size.y / tile_size))
	for row in range(rows):
		for column in range(columns):
			if (row + column) % 2 != 0:
				continue
			var tile := Rect2(bounds.position + Vector2(column * tile_size, row * tile_size), Vector2(tile_size, tile_size))
			tile = tile.intersection(bounds)
			if tile.size.x > 0.0 and tile.size.y > 0.0:
				draw_rect(tile, definition.floor_light_color)

func _draw_walls(bounds: Rect2) -> void:
	var wall_width := 18.0
	draw_rect(Rect2(bounds.position - Vector2(wall_width, wall_width), Vector2(bounds.size.x + wall_width * 2.0, wall_width)), definition.wall_color)
	draw_rect(Rect2(Vector2(bounds.position.x - wall_width, bounds.end.y), Vector2(bounds.size.x + wall_width * 2.0, wall_width)), definition.wall_color)
	draw_rect(Rect2(bounds.position - Vector2(wall_width, 0.0), Vector2(wall_width, bounds.size.y)), definition.wall_color)
	draw_rect(Rect2(Vector2(bounds.end.x, bounds.position.y), Vector2(wall_width, bounds.size.y)), definition.wall_color)
	draw_line(bounds.position, Vector2(bounds.end.x, bounds.position.y), definition.wall_light_color, 3.0)
	draw_line(Vector2(bounds.position.x, bounds.end.y), bounds.end, definition.wall_light_color, 3.0)
	# Entrada abierta en la pared inferior.
	draw_rect(Rect2(430.0, bounds.end.y - 4.0, 100.0, 24.0), definition.accent_color)

func _draw_reception() -> void:
	var desk := Rect2(110.0, 155.0, 260.0, 70.0)
	draw_rect(desk, Color("5d3e2f"))
	draw_rect(Rect2(desk.position + Vector2(8.0, 8.0), desk.size - Vector2(16.0, 16.0)), Color("a87851"))
	draw_line(Vector2(desk.position.x, desk.end.y), desk.end, Color("3a2822"), 5.0)
	draw_circle(Vector2(325.0, 188.0), 10.0, definition.accent_color)
	draw_rect(Rect2(205.0, 120.0, 70.0, 24.0), definition.wall_light_color)

func _draw_lounge() -> void:
	draw_rect(Rect2(180.0, 390.0, 220.0, 70.0), Color("6b4b3c"))
	draw_rect(Rect2(198.0, 405.0, 184.0, 38.0), Color("b47a5c"))
	draw_circle(Vector2(490.0, 430.0), 34.0, Color("76543d"))
	draw_circle(Vector2(490.0, 430.0), 25.0, Color("c29563"))

func _draw_fireplace() -> void:
	var fireplace := Rect2(70.0, 300.0, 80.0, 150.0)
	draw_rect(fireplace, definition.wall_color)
	draw_rect(Rect2(fireplace.position + Vector2(14.0, 38.0), Vector2(52.0, 88.0)), Color("25313a"))
	draw_circle(Vector2(110.0, 404.0), 18.0, Color("e69a4c"))
	draw_circle(Vector2(110.0, 404.0), 9.0, Color("ffe19a"))

func _draw_kitchen() -> void:
	var kitchen := definition.kitchen_rect
	var counter := definition.kitchen_counter_rect
	draw_rect(kitchen, Color("87906d"))
	draw_rect(Rect2(kitchen.position + Vector2(8.0, 8.0), kitchen.size - Vector2(16.0, 16.0)), Color("b7b48a"))
	draw_rect(counter, Color("5d3e2f"))
	draw_rect(Rect2(counter.position + Vector2(8.0, 8.0), counter.size - Vector2(16.0, 16.0)), Color("a87851"))
	draw_line(Vector2(counter.position.x, counter.end.y), counter.end, Color("3a2822"), 5.0)
	# Fogones y utensilios de la encimera.
	for column in range(3):
		var stove_center := counter.position + Vector2(48.0 + column * 68.0, 34.0)
		draw_circle(stove_center, 18.0, Color("29343a"))
		draw_circle(stove_center, 11.0, Color("45545a"))
	var board := Rect2(kitchen.position + Vector2(238.0, 20.0), Vector2(58.0, 46.0))
	draw_rect(board, Color("d4a46e"))
	draw_rect(Rect2(board.position + Vector2(5.0, 5.0), board.size - Vector2(10.0, 10.0)), Color("efc78c"))
	draw_circle(board.position + Vector2(18.0, 23.0), 8.0, Color("d85f4e"))
	draw_circle(board.position + Vector2(39.0, 23.0), 7.0, Color("e69a3e"))
	# Un pequeño fregadero identifica visualmente el lugar como cocina.
	var sink := Rect2(kitchen.position + Vector2(18.0, 20.0), Vector2(76.0, 52.0))
	draw_rect(sink, Color("536d78"))
	draw_rect(Rect2(sink.position + Vector2(8.0, 8.0), sink.size - Vector2(16.0, 16.0)), Color("9ab5bb"))
	draw_line(sink.position + Vector2(38.0, 8.0), sink.position + Vector2(38.0, -4.0), definition.wall_light_color, 4.0)
	draw_arc(sink.position + Vector2(48.0, -4.0), 10.0, PI, TAU, 12, definition.wall_light_color, 4.0)

func _draw_hotel_sign() -> void:
	draw_rect(Rect2(390.0, 72.0, 180.0, 38.0), definition.accent_color)
	draw_rect(Rect2(398.0, 80.0, 164.0, 22.0), definition.wall_color)
