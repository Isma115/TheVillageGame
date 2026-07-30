extends Control
class_name MobileControls

signal direction_changed(direction: Vector2)
signal sprint_changed(active: bool)
signal primary_action_pressed

const INVALID_POINTER_ID := -999
const MOUSE_POINTER_ID := -1
const DEAD_ZONE := 0.2
const STICK_MARGIN := 24.0
const STICK_RADIUS := 58.0
const KNOB_RADIUS := 24.0
const RUN_SIZE := Vector2(104.0, 58.0)
const ACTION_SIZE := Vector2(122.0, 58.0)
const ACTION_GAP := 18.0

var controls_enabled := false
var stick_pointer_id := INVALID_POINTER_ID
var run_pointer_id := INVALID_POINTER_ID
var action_pointer_id := INVALID_POINTER_ID
var knob_offset := Vector2.ZERO
var primary_action_label := "ACCIÓN"
var primary_action_available := false
var run_button_style: StyleBoxFlat
var run_button_pressed_style: StyleBoxFlat
var action_button_style: StyleBoxFlat
var action_button_pressed_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	run_button_style = _create_run_button_style(false)
	run_button_pressed_style = _create_run_button_style(true)
	action_button_style = _create_action_button_style(false)
	action_button_pressed_style = _create_action_button_style(true)
	queue_redraw()


func set_enabled(active: bool) -> void:
	controls_enabled = active
	visible = active
	if not controls_enabled:
		_reset()
	queue_redraw()


func set_primary_action(label: String, available: bool) -> void:
	primary_action_label = label.to_upper() if available else "ACCIÓN"
	primary_action_available = available
	if not available:
		action_pointer_id = INVALID_POINTER_ID
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down(event.index, event.position)
		else:
			_pointer_up(event.index)
	elif event is InputEventScreenDrag:
		_pointer_move(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down(MOUSE_POINTER_ID, event.position)
		else:
			_pointer_up(MOUSE_POINTER_ID)
	elif event is InputEventMouseMotion:
		_pointer_move(MOUSE_POINTER_ID, event.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reset()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func _pointer_down(pointer_id: int, pointer_position: Vector2) -> void:
	if stick_pointer_id == INVALID_POINTER_ID and pointer_position.distance_to(_stick_center()) <= STICK_RADIUS:
		stick_pointer_id = pointer_id
		_update_stick(pointer_position)
		get_viewport().set_input_as_handled()
		return

	if (
		primary_action_available
		and action_pointer_id == INVALID_POINTER_ID
		and _action_rect().has_point(pointer_position)
	):
		action_pointer_id = pointer_id
		primary_action_pressed.emit()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if run_pointer_id == INVALID_POINTER_ID and _run_rect().has_point(pointer_position):
		run_pointer_id = pointer_id
		sprint_changed.emit(true)
		queue_redraw()
		get_viewport().set_input_as_handled()


func _pointer_move(pointer_id: int, pointer_position: Vector2) -> void:
	if pointer_id == stick_pointer_id:
		_update_stick(pointer_position)
		get_viewport().set_input_as_handled()


func _pointer_up(pointer_id: int) -> void:
	if pointer_id == stick_pointer_id:
		stick_pointer_id = INVALID_POINTER_ID
		knob_offset = Vector2.ZERO
		direction_changed.emit(Vector2.ZERO)
		queue_redraw()
		get_viewport().set_input_as_handled()

	if pointer_id == run_pointer_id:
		run_pointer_id = INVALID_POINTER_ID
		sprint_changed.emit(false)
		queue_redraw()
		get_viewport().set_input_as_handled()

	if pointer_id == action_pointer_id:
		action_pointer_id = INVALID_POINTER_ID
		queue_redraw()
		get_viewport().set_input_as_handled()


func _update_stick(pointer_position: Vector2) -> void:
	var offset := pointer_position - _stick_center()
	var max_distance := STICK_RADIUS - KNOB_RADIUS - 6.0
	if offset.length() > max_distance:
		offset = offset.normalized() * max_distance

	knob_offset = offset
	var normalized := offset / max_distance
	var direction := Vector2.ZERO
	if normalized.x < -DEAD_ZONE:
		direction.x = -1.0
	elif normalized.x > DEAD_ZONE:
		direction.x = 1.0
	if normalized.y < -DEAD_ZONE:
		direction.y = -1.0
	elif normalized.y > DEAD_ZONE:
		direction.y = 1.0

	direction_changed.emit(direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO)
	queue_redraw()


func _reset() -> void:
	stick_pointer_id = INVALID_POINTER_ID
	run_pointer_id = INVALID_POINTER_ID
	action_pointer_id = INVALID_POINTER_ID
	knob_offset = Vector2.ZERO
	direction_changed.emit(Vector2.ZERO)
	sprint_changed.emit(false)


func _stick_center() -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(
		STICK_MARGIN + STICK_RADIUS,
		viewport_size.y - STICK_MARGIN - STICK_RADIUS
	)


func _run_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	return Rect2(
		Vector2(
			viewport_size.x - STICK_MARGIN - RUN_SIZE.x,
			viewport_size.y - STICK_MARGIN - RUN_SIZE.y - 10.0
		),
		RUN_SIZE
	)


func _action_rect() -> Rect2:
	var run_rectangle := _run_rect()
	return Rect2(
		Vector2(
			run_rectangle.get_center().x - ACTION_SIZE.x / 2.0,
			run_rectangle.position.y - ACTION_GAP - ACTION_SIZE.y
		),
		ACTION_SIZE
	)


func _draw() -> void:
	if not controls_enabled:
		return

	var center := _stick_center()
	draw_circle(center, STICK_RADIUS, Color(0.094, 0.173, 0.114, 0.52))
	draw_arc(center, STICK_RADIUS, 0.0, TAU, 48, Color(0.945, 0.957, 0.867, 0.42), 2.0, true)
	draw_circle(center, 2.0, Color(0.945, 0.957, 0.867, 0.32))
	draw_circle(center + knob_offset, KNOB_RADIUS, Color(0.851, 0.925, 0.439, 0.45))
	draw_arc(center + knob_offset, KNOB_RADIUS, 0.0, TAU, 32, Color(0.851, 0.925, 0.439, 0.82), 2.0, true)

	if primary_action_available:
		var action_rectangle := _action_rect()
		var current_action_style := (
			action_button_pressed_style
			if action_pointer_id != INVALID_POINTER_ID
			else action_button_style
		)
		draw_style_box(current_action_style, action_rectangle)
		draw_string(
			ThemeDB.fallback_font,
			action_rectangle.position + Vector2(0.0, 35.0),
			primary_action_label,
			HORIZONTAL_ALIGNMENT_CENTER,
			action_rectangle.size.x,
			12,
			Color("#f1f4dd")
		)

	var run_rectangle := _run_rect()
	var button_style := (
		run_button_pressed_style
		if run_pointer_id != INVALID_POINTER_ID
		else run_button_style
	)
	draw_style_box(button_style, run_rectangle)
	draw_string(
		ThemeDB.fallback_font,
		run_rectangle.position + Vector2(14.0, 35.0),
		"CORRER",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color("#193724")
	)


func _create_run_button_style(pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f1f4dd") if pressed else Color(0.851, 0.925, 0.439, 0.86)
	style.border_color = Color(0.945, 0.957, 0.867, 0.72 if pressed else 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(RUN_SIZE.y / 2.0))
	return style


func _create_action_button_style(pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#315f3b") if pressed else Color(0.094, 0.173, 0.114, 0.88)
	style.border_color = Color("#f1f4dd") if pressed else Color(0.851, 0.925, 0.439, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(ACTION_SIZE.y / 2.0))
	return style
