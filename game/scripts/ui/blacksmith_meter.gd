extends Control
class_name BlacksmithMeter

signal strike_requested

const GREEN_ZONE_HEIGHT := 0.16
const MARKER_HEIGHT := 0.018

var _active := false
var _marker_progress := 0.22
var _marker_velocity := 0.82
var _green_progress := 0.58
var _green_velocity := -0.31


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(false)


func start() -> void:
	_active = true
	_marker_progress = 0.22
	_marker_velocity = 0.82
	_green_progress = 0.58
	_green_velocity = -0.31
	set_process(true)
	queue_redraw()


func stop() -> void:
	_active = false
	set_process(false)
	queue_redraw()


func is_marker_in_green() -> bool:
	return absf(_marker_progress - _green_progress) <= (
		GREEN_ZONE_HEIGHT + MARKER_HEIGHT
	) * 0.5


func _process(delta: float) -> void:
	if not _active or delta <= 0.0:
		return

	_marker_progress += _marker_velocity * delta
	if _marker_progress <= 0.06:
		_marker_progress = 0.06
		_marker_velocity = absf(_marker_velocity)
	elif _marker_progress >= 0.94:
		_marker_progress = 0.94
		_marker_velocity = -absf(_marker_velocity)

	_green_progress += _green_velocity * delta
	if _green_progress <= 0.20:
		_green_progress = 0.20
		_green_velocity = absf(_green_velocity)
	elif _green_progress >= 0.80:
		_green_progress = 0.80
		_green_velocity = -absf(_green_velocity)

	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		strike_requested.emit()
		accept_event()
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)
	):
		strike_requested.emit()
		accept_event()


func _draw() -> void:
	var bar_width := minf(72.0, maxf(size.x - 20.0, 20.0))
	var bar_height := maxf(size.y - 28.0, 80.0)
	var bar := Rect2(
		Vector2((size.x - bar_width) * 0.5, 14.0),
		Vector2(bar_width, bar_height)
	)

	draw_rect(bar.grow(7.0), Color("#142018"))
	draw_rect(bar, Color("#d04d43"))
	_draw_segment(bar, 0.20, 0.20, Color("#d04d43"))
	_draw_segment(bar, 0.20, 0.40, Color("#e88942"))
	_draw_segment(bar, 0.40, 0.60, Color("#f0c65c"))
	_draw_segment(bar, 0.60, 0.80, Color("#e88942"))
	_draw_segment(bar, 0.80, 1.00, Color("#d04d43"))

	var green_rect := Rect2(
		bar.position + Vector2(0.0, (_green_progress - GREEN_ZONE_HEIGHT * 0.5) * bar.size.y),
		Vector2(bar.size.x, GREEN_ZONE_HEIGHT * bar.size.y)
	)
	draw_rect(green_rect, Color("#72c85b"))
	draw_line(
		Vector2(green_rect.position.x, green_rect.position.y),
		Vector2(green_rect.end.x, green_rect.position.y),
		Color("#c8f28a"),
		2.0
	)
	draw_line(
		Vector2(green_rect.position.x, green_rect.end.y),
		Vector2(green_rect.end.x, green_rect.end.y),
		Color("#326d3d"),
		2.0
	)

	var marker_y := bar.position.y + _marker_progress * bar.size.y
	var marker_rect := Rect2(
		Vector2(bar.position.x - 9.0, marker_y - 3.0),
		Vector2(bar.size.x + 18.0, 6.0)
	)
	draw_rect(marker_rect, Color("#fffdf1"))
	draw_line(
		Vector2(marker_rect.position.x, marker_rect.position.y),
		Vector2(marker_rect.end.x, marker_rect.position.y),
		Color("#ffffff"),
		1.0
	)


func _draw_segment(
	bar: Rect2,
	from_ratio: float,
	to_ratio: float,
	color: Color
) -> void:
	draw_rect(
		Rect2(
			bar.position + Vector2(0.0, from_ratio * bar.size.y),
			Vector2(bar.size.x, (to_ratio - from_ratio) * bar.size.y)
		),
		color
	)
