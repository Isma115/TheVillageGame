extends Node2D
class_name MineWorld

const MINE_ROCK_TEXTURE_PATH := "res://assets/mining/mine-rock-texture.png"
const FLOOR_TILE_SIZE := 48.0
const ROCK_BORDER_WIDTH := 40.0

var definition: MineDefinition
var _mine_rock_texture: Texture2D


func _ready() -> void:
	_mine_rock_texture = ResourceLoader.load(
		MINE_ROCK_TEXTURE_PATH,
		"Texture2D"
	) as Texture2D


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
	_draw_rock_surfaces()
	for index in range(definition.interior_obstacles.size()):
		_draw_boulder_field(definition.interior_obstacles[index], index)
	_draw_wall_lamp(Vector2(definition.wall_inset * 0.62, definition.interior_size.y * 0.50))
	_draw_wall_lamp(
		Vector2(
			definition.interior_size.x - definition.wall_inset * 0.62,
			definition.interior_size.y * 0.50
		)
	)


func _draw_rock_surfaces() -> void:
	var bounds := definition.playable_bounds()
	var rock_border := bounds.grow(ROCK_BORDER_WIDTH)
	if _mine_rock_texture != null:
		draw_texture_rect(
			_mine_rock_texture,
			rock_border,
			true,
			Color(0.62, 0.58, 0.68, 1.0)
		)
	else:
		draw_rect(rock_border, Color("#514d5b"))
	draw_rect(bounds, definition.floor_color)
	if _mine_rock_texture != null:
		draw_texture_rect(
			_mine_rock_texture,
			bounds,
			true,
			Color(1.0, 1.0, 1.0, 0.16)
		)
	_draw_floor_details()


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
			if variation > 0.62:
				draw_circle(
					center + Vector2(
						_hash_2d(tile_x + 19, tile_y) * 18.0 - 9.0,
						_hash_2d(tile_x, tile_y + 23) * 18.0 - 9.0
					),
					1.2 + variation * 1.6,
					Color(definition.floor_light_color, 0.26)
				)
			if variation < 0.12:
				var crack_start := center + Vector2(-7.0, 2.0)
				draw_polyline(
					PackedVector2Array([
						crack_start,
						crack_start + Vector2(6.0, -2.0),
						crack_start + Vector2(11.0, 2.0)
					]),
					Color(definition.crack_color, 0.48),
					1.5,
					true
				)


func _draw_boulder_field(rectangle: Rect2, _seed_value: int) -> void:
	var shadow_rectangle := rectangle.grow(4.0)
	draw_rect(shadow_rectangle, Color(definition.crack_color, 0.72))
	if _mine_rock_texture != null:
		draw_texture_rect(
			_mine_rock_texture,
			rectangle,
			true,
			Color(0.68, 0.64, 0.74, 0.92)
		)
	else:
		draw_rect(rectangle, Color("#746b7a"))


func _draw_wall_lamp(center: Vector2) -> void:
	draw_circle(center, 48.0, Color(definition.lamp_color, 0.035))
	draw_circle(center, 26.0, Color(definition.lamp_color, 0.07))
	draw_rect(Rect2(center - Vector2(6.0, 9.0), Vector2(12.0, 18.0)), Color("#4a3527"))
	draw_circle(center, 6.0, definition.lamp_color)


func _hash_2d(x: int, y: int) -> float:
	var value := sin(x * 127.1 + y * 311.7 + definition.random_seed) * 43758.5453123
	return value - floorf(value)
