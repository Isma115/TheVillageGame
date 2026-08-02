extends Control
class_name CookingMeter

signal released_in_zone(zone: StringName)

const GREEN_END := 0.52
const YELLOW_END := 0.76
const BLUE_END := 0.82
const CHARGE_START_SPEED := 0.22
const CHARGE_ACCELERATION := 0.16
const CHARGE_MAX_SPEED := 0.92
const DECAY_SPEED := 0.15

var _active := false
var _holding := false
var _hold_time := 0.0
var _charge := 0.0
var _outcome: StringName = &""
var _control_settings


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_control_settings(settings) -> void:
	_control_settings = settings


func configure() -> void:
	_active = true
	_holding = false
	_hold_time = 0.0
	_charge = 0.0
	_outcome = &""
	set_process(true)
	queue_redraw()


func stop() -> void:
	_active = false
	_holding = false
	_hold_time = 0.0
	set_process(false)
	queue_redraw()


func reset() -> void:
	stop()
	_charge = 0.0
	_outcome = &""
	queue_redraw()


func set_outcome(outcome: StringName) -> void:
	_outcome = outcome
	_active = false
	_holding = false
	set_process(false)
	queue_redraw()


func charge_value() -> float:
	return _charge


func current_zone() -> StringName:
	return _zone_for_value(_charge)


func _process(delta: float) -> void:
	if not _active:
		return
	if _holding:
		_hold_time += delta
		var speed := minf(
			CHARGE_START_SPEED + _hold_time * CHARGE_ACCELERATION,
			CHARGE_MAX_SPEED
		)
		_charge = minf(1.0, _charge + speed * delta)
	else:
		_charge = maxf(0.0, _charge - DECAY_SPEED * delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if not _matches_input_event(event):
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if get_global_rect().has_point(mouse_event.position):
				_holding = true
				_hold_time = 0.0
				accept_event()
			return

		if _holding:
			_holding = false
			_resolve_release()
			accept_event()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			_holding = true
			_hold_time = 0.0
			accept_event()
		elif not key_event.pressed and _holding:
			_holding = false
			_resolve_release()
			accept_event()


func _matches_input_event(event: InputEvent) -> bool:
	if _control_settings != null:
		return _control_settings.matches_event(&"minigame_action", event)
	return (
		(
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		)
		or (
			event is InputEventKey
			and (
				(event as InputEventKey).keycode == KEY_SPACE
				or (event as InputEventKey).keycode == KEY_ENTER
			)
		)
	)


func _resolve_release() -> void:
	var zone := _zone_for_value(_charge)
	if zone == &"green":
		released_in_zone.emit(zone)
		return
	_active = false
	set_process(false)
	released_in_zone.emit(zone)
	queue_redraw()


func _zone_for_value(value: float) -> StringName:
	if value < GREEN_END:
		return &"green"
	if value < YELLOW_END:
		return &"yellow"
	if value < BLUE_END:
		return &"blue"
	return &"red"


func _bar_rect() -> Rect2:
	var bar_height := maxf(size.y - 24.0, 1.0)
	return Rect2(Vector2(size.x * 0.5 - 42.0, 12.0), Vector2(84.0, bar_height))


func _zone_rect(bar: Rect2, lower: float, upper: float) -> Rect2:
	var top := bar.end.y - bar.size.y * upper
	var bottom := bar.end.y - bar.size.y * lower
	return Rect2(Vector2(bar.position.x, top), Vector2(bar.size.x, bottom - top))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("152d21"))
	draw_rect(Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0)), Color("1d3a29"))
	var bar := _bar_rect()
	draw_rect(bar, Color("0b1710"))
	draw_rect(_zone_rect(bar, 0.0, GREEN_END), Color("5dbd5b"))
	draw_rect(_zone_rect(bar, GREEN_END, YELLOW_END), Color("e5c34d"))
	draw_rect(_zone_rect(bar, YELLOW_END, BLUE_END), Color("5e9ed8"))
	draw_rect(_zone_rect(bar, BLUE_END, 1.0), Color("c84e4e"))
	draw_rect(bar, Color("07110a"), false, 3.0)

	for boundary in [GREEN_END, YELLOW_END, BLUE_END]:
		var boundary_y: float = bar.end.y - bar.size.y * float(boundary)
		draw_line(
			Vector2(bar.position.x, boundary_y),
			Vector2(bar.end.x, boundary_y),
			Color(0.05, 0.12, 0.08, 0.72),
			2.0
		)

	var marker_y := bar.end.y - bar.size.y * _charge
	var orange_fill := Rect2(
		Vector2(bar.position.x + 23.0, marker_y),
		Vector2(bar.size.x - 46.0, bar.end.y - marker_y)
	)
	draw_rect(orange_fill, Color(1.0, 0.67, 0.29, 0.34))
	var marker_color := Color("ffb15c")
	if _outcome == &"perfect":
		marker_color = Color("b8e7ff")
	elif _outcome == &"normal":
		marker_color = Color("fff0a8")
	elif _outcome == &"burned":
		marker_color = Color("ff806b")
	draw_rect(
		Rect2(Vector2(bar.position.x - 12.0, marker_y - 5.0), Vector2(bar.size.x + 24.0, 10.0)),
		marker_color
	)
	draw_circle(Vector2(bar.end.x + 18.0, marker_y), 5.0, marker_color)
