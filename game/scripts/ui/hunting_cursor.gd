extends Control
class_name HuntingCursor

var _active := false
var _cursor_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	visible = false


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	visible = active
	if active:
		_cursor_position = get_viewport().get_mouse_position()
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _active:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN and _active:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _process(_delta: float) -> void:
	if not _active:
		return
	_cursor_position = get_viewport().get_mouse_position()
	queue_redraw()


func _draw() -> void:
	if not _active:
		return

	draw_circle(_cursor_position, 15.0, Color(0.047, 0.09, 0.063, 0.30))
	draw_arc(
		_cursor_position,
		13.0,
		0.0,
		TAU,
		32,
		Color(0.85098, 0.92549, 0.439216, 0.96),
		2.0,
		true
	)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2.from_angle(angle)
		draw_line(
			_cursor_position + direction * 17.0,
			_cursor_position + direction * 23.0,
			Color(0.945, 0.957, 0.867, 0.96),
			2.0,
			true
		)
	draw_circle(_cursor_position, 2.5, Color(0.870588, 0.337255, 0.337255, 1.0))
