extends Node2D
class_name InteractionHighlight

const INVALID_CELL := Vector2i(2147483647, 2147483647)

var catalog: GameCatalog
var current_cell := INVALID_CELL
var enabled := false


func initialize(game_catalog: GameCatalog, active: bool) -> void:
	catalog = game_catalog
	set_enabled(active)


func set_enabled(active: bool) -> void:
	enabled = active
	visible = active
	if not active:
		current_cell = INVALID_CELL
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return

	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var pointer_position: Vector2 = event.position
		var world_position: Vector2 = get_canvas_transform().affine_inverse() * pointer_position
		_update_cell(world_position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		current_cell = INVALID_CELL
		queue_redraw()


func _update_cell(world_position: Vector2) -> void:
	var next_cell := Vector2i(
		floori(world_position.x / catalog.tile_size),
		floori(world_position.y / catalog.tile_size)
	)
	if not catalog.is_valid_cell(next_cell):
		next_cell = INVALID_CELL

	if next_cell == current_cell:
		return

	current_cell = next_cell
	queue_redraw()


func _draw() -> void:
	if not enabled or current_cell == INVALID_CELL:
		return

	var origin := Vector2(current_cell) * catalog.tile_size
	draw_rect(
		Rect2(
			origin + Vector2(2.0, 2.0),
			Vector2.ONE * (catalog.tile_size - 4.0)
		),
		Color(1.0, 1.0, 1.0, 0.92),
		false,
		3.0,
		true
	)
