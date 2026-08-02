extends Node2D
class_name WaterAnimationLayer

const WATER_BLOCK_EDGE_COLOR := Color(0.46, 0.78, 0.78, 0.55)
const WATER_SHORE_COLOR := Color("#75c7c7")
const WATER_HIGHLIGHT_COLOR := Color(0.78, 0.97, 0.97, 0.58)
const WATER_SECONDARY_HIGHLIGHT_COLOR := Color(0.78, 0.97, 0.97, 0.38)
const WATER_FRAME_COUNT := 3
const WATER_FRAME_DURATION := 0.45
const WATER_TEXTURE_PATHS := [
	"res://assets/terrain/water-state-0.png",
	"res://assets/terrain/water-state-1.png",
	"res://assets/terrain/water-state-2.png",
]
const WATER_FRAME_COLORS := [
	Color("#2c8ca1"),
	Color("#3093a5"),
	Color("#28879e")
]

var catalog: GameCatalog
var water_cells: Array[Vector2i] = []
var water_tile_keys: Dictionary = {}
var _animation_elapsed := 0.0
var _animation_state := 0
var _water_textures: Array[Texture2D] = []
var view_camera: Camera2D
var _visible_draw_rect := Rect2()
var _visible_region_initialized := false


func initialize(
	game_catalog: GameCatalog,
	cells: Array[Vector2i],
	camera: Camera2D = null
) -> void:
	catalog = game_catalog
	view_camera = camera
	water_cells.assign(cells)
	water_tile_keys.clear()
	for cell in water_cells:
		water_tile_keys[_tile_key(cell.x, cell.y)] = true
	_animation_elapsed = 0.0
	_animation_state = 0
	_load_water_textures()
	_visible_region_initialized = false
	_refresh_visible_region(true)
	set_process(not water_cells.is_empty())
	queue_redraw()


func set_view_camera(camera: Camera2D) -> void:
	view_camera = camera
	_visible_region_initialized = false
	_refresh_visible_region(true)


func _process(delta: float) -> void:
	if water_cells.is_empty() or delta <= 0.0:
		return

	_refresh_visible_region()
	_animation_elapsed += delta
	if _animation_elapsed < WATER_FRAME_DURATION:
		return

	var frame_steps := floori(_animation_elapsed / WATER_FRAME_DURATION)
	_animation_elapsed = fmod(_animation_elapsed, WATER_FRAME_DURATION)
	_animation_state = posmod(_animation_state + frame_steps, WATER_FRAME_COUNT)
	queue_redraw()


func _draw() -> void:
	if catalog == null:
		return

	for cell in water_cells:
		if not _tile_rectangle(cell).intersects(_visible_draw_rect):
			continue
		_draw_water_tile(cell)


func _refresh_visible_region(force: bool = false) -> void:
	if catalog == null or catalog.tile_size <= 0.0:
		return

	var camera_rect := _camera_world_rect()
	var clipped_rect := camera_rect.intersection(catalog.world_rect())
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
	var changed := force or not _visible_region_initialized or draw_rect != _visible_draw_rect
	_visible_draw_rect = draw_rect
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


func _draw_water_tile(cell: Vector2i) -> void:
	var rectangle := _tile_rectangle(cell)
	if _water_textures.size() == WATER_FRAME_COUNT:
		draw_texture_rect(_water_textures[_animation_state], rectangle, false)
		return
	draw_rect(rectangle, WATER_FRAME_COLORS[_animation_state])
	_draw_water_shimmer(rectangle)


func _load_water_textures() -> void:
	_water_textures.clear()
	for texture_path in WATER_TEXTURE_PATHS:
		var texture := load(texture_path) as Texture2D
		if texture == null:
			push_warning("No se pudo cargar la textura de agua: %s" % texture_path)
			return
		_water_textures.append(texture)


func _draw_water_shimmer(rectangle: Rect2) -> void:
	match _animation_state:
		0:
			_draw_water_reflection(rectangle, 0.29, 0.16, 0.58, WATER_HIGHLIGHT_COLOR)
			_draw_water_reflection(rectangle, 0.68, 0.42, 0.82, WATER_SECONDARY_HIGHLIGHT_COLOR)
		1:
			_draw_water_reflection(rectangle, 0.42, 0.30, 0.76, WATER_HIGHLIGHT_COLOR)
			_draw_water_reflection(rectangle, 0.74, 0.12, 0.48, WATER_SECONDARY_HIGHLIGHT_COLOR)
		2:
			_draw_water_reflection(rectangle, 0.58, 0.18, 0.62, WATER_HIGHLIGHT_COLOR)
			_draw_water_reflection(rectangle, 0.31, 0.54, 0.88, WATER_SECONDARY_HIGHLIGHT_COLOR)


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
	if not _is_water_tile(cell + Vector2i(-1, 0)):
		draw_line(
			rectangle.position,
			rectangle.position + Vector2(0.0, catalog.tile_size),
			color,
			width,
			true
		)
	if not _is_water_tile(cell + Vector2i(1, 0)):
		draw_line(
			rectangle.position + Vector2(catalog.tile_size, 0.0),
			rectangle.position + Vector2(catalog.tile_size, catalog.tile_size),
			color,
			width,
			true
		)
	if not _is_water_tile(cell + Vector2i(0, -1)):
		draw_line(
			rectangle.position,
			rectangle.position + Vector2(catalog.tile_size, 0.0),
			color,
			width,
			true
		)
	if not _is_water_tile(cell + Vector2i(0, 1)):
		draw_line(
			rectangle.position + Vector2(0.0, catalog.tile_size),
			rectangle.position + Vector2(catalog.tile_size, catalog.tile_size),
			color,
			width,
			true
		)


func _tile_rectangle(cell: Vector2i) -> Rect2:
	return Rect2(
		Vector2(cell) * catalog.tile_size,
		Vector2.ONE * catalog.tile_size
	)


func _is_water_tile(cell: Vector2i) -> bool:
	return water_tile_keys.has(_tile_key(cell.x, cell.y))


func _tile_key(grid_x: int, grid_y: int) -> String:
	return "%d:%d" % [grid_x, grid_y]
