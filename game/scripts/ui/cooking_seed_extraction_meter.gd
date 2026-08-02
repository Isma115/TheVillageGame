extends Control
class_name CookingSeedExtractionMeter

signal cut_performed(
	valid: bool,
	hit_center: bool,
	already_cut: bool,
	coverage_gain: float,
	start: Vector2,
	end: Vector2
)

const GESTURE_MIN_DISTANCE := 14.0
const CUT_SWATH_WIDTH := 30.0
const COVERAGE_SAMPLE_STEP := 6.0
const TOMATO_RADIUS := 108.0
const CARROT_HALF_WIDTH := 56.0
const CARROT_HALF_HEIGHT := 108.0
const SAFE_RADIUS := 30.0

var vegetable_id: StringName = &"tomato"
var _active := false
var _dragging := false
var _gesture_start := Vector2.ZERO
var _gesture_end := Vector2.ZERO
var _outcome := 0 # 0: en curso, 1: acierto, 2: fallo.
var _cuts: Array[Dictionary] = []
var _coverage_samples: Array[Vector2] = []
var _covered_sample_indices: Dictionary = {}
var _control_settings


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_control_settings(settings) -> void:
	_control_settings = settings


func configure(next_vegetable_id: StringName) -> void:
	vegetable_id = next_vegetable_id
	_active = true
	_dragging = false
	_gesture_start = Vector2.ZERO
	_gesture_end = Vector2.ZERO
	_outcome = 0
	_cuts.clear()
	_build_coverage_samples()
	queue_redraw()


func stop() -> void:
	_active = false
	_dragging = false
	_gesture_start = Vector2.ZERO
	_gesture_end = Vector2.ZERO
	queue_redraw()


func set_outcome(success: bool) -> void:
	_outcome = 1 if success else 2
	_active = false
	_dragging = false
	_gesture_start = Vector2.ZERO
	_gesture_end = Vector2.ZERO
	queue_redraw()


func reset() -> void:
	vegetable_id = &"tomato"
	_active = false
	_dragging = false
	_gesture_start = Vector2.ZERO
	_gesture_end = Vector2.ZERO
	_outcome = 0
	_cuts.clear()
	_build_coverage_samples()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseButton:
		if not _matches_cut_event(event):
			return
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if get_global_rect().has_point(mouse_event.position):
				_begin_gesture(get_local_mouse_position())
				accept_event()
			return
		if _dragging:
			_finish_gesture(get_local_mouse_position())
			accept_event()
		return

	if event is InputEventMouseMotion and _dragging:
		_append_gesture_point(get_local_mouse_position())
		accept_event()
		return

	if event is InputEventKey and _matches_cut_event(event):
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			_begin_gesture(get_local_mouse_position())
			accept_event()
		elif not key_event.pressed and _dragging:
			_finish_gesture(get_local_mouse_position())
			accept_event()


func _matches_cut_event(event: InputEvent) -> bool:
	if _control_settings != null:
		return _control_settings.matches_event(&"minigame_action", event)
	return (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	)


func _begin_gesture(start: Vector2) -> void:
	_dragging = true
	_gesture_start = start
	_gesture_end = start
	queue_redraw()


func _append_gesture_point(point: Vector2) -> void:
	if point.distance_to(_gesture_end) < 1.0:
		return
	_gesture_end = point
	queue_redraw()


func _finish_gesture(end: Vector2) -> void:
	if not _dragging:
		return
	_append_gesture_point(end)
	_dragging = false
	if _gesture_start.distance_to(_gesture_end) >= GESTURE_MIN_DISTANCE:
		_register_cut(_gesture_start, _gesture_end)
	queue_redraw()


func _register_cut(start: Vector2, end: Vector2) -> void:
	var hit_center := _segment_distance_to_point(start, end, _vegetable_center()) <= SAFE_RADIUS
	var touches_vegetable := _segment_touches_vegetable(start, end)
	var valid := not hit_center and touches_vegetable
	var already_cut := valid and _segment_overlaps_cut_area(start, end)
	if already_cut:
		valid = false
	var coverage_gain := _coverage_gain_for_segment(start, end) if valid else 0.0
	_cuts.append({
		"start": start,
		"end": end,
		"valid": valid,
		"hit_center": hit_center,
		"already_cut": already_cut,
		"coverage_gain": coverage_gain
	})
	cut_performed.emit(valid, hit_center, already_cut, coverage_gain, start, end)
	queue_redraw()

func _build_coverage_samples() -> void:
	_coverage_samples.clear()
	_covered_sample_indices.clear()
	var bounds := _coverage_bounds()
	var first_x := int(floor(bounds.position.x / COVERAGE_SAMPLE_STEP))
	var last_x := int(ceil(bounds.end.x / COVERAGE_SAMPLE_STEP))
	var first_y := int(floor(bounds.position.y / COVERAGE_SAMPLE_STEP))
	var last_y := int(ceil(bounds.end.y / COVERAGE_SAMPLE_STEP))
	for grid_y in range(first_y, last_y + 1):
		for grid_x in range(first_x, last_x + 1):
			var point := Vector2(
				float(grid_x) * COVERAGE_SAMPLE_STEP,
				float(grid_y) * COVERAGE_SAMPLE_STEP
			)
			if (
				_point_in_vegetable(point)
				and point.distance_to(_vegetable_center()) > SAFE_RADIUS
			):
				_coverage_samples.append(point)


func _coverage_bounds() -> Rect2:
	var center := _vegetable_center()
	if vegetable_id == &"carrot":
		return Rect2(
			center - Vector2(CARROT_HALF_WIDTH, CARROT_HALF_HEIGHT),
			Vector2(CARROT_HALF_WIDTH * 2.0, CARROT_HALF_HEIGHT * 2.0)
		)
	return Rect2(
		center - Vector2(TOMATO_RADIUS, TOMATO_RADIUS),
		Vector2(TOMATO_RADIUS * 2.0, TOMATO_RADIUS * 2.0)
	)


func _coverage_gain_for_segment(start: Vector2, end: Vector2) -> float:
	if _coverage_samples.is_empty():
		return 0.0
	var newly_covered := 0
	var half_swath := CUT_SWATH_WIDTH * 0.5
	for index in range(_coverage_samples.size()):
		if _covered_sample_indices.has(index):
			continue
		if _segment_distance_to_point(start, end, _coverage_samples[index]) <= half_swath:
			_covered_sample_indices[index] = true
			newly_covered += 1
	return float(newly_covered) / float(_coverage_samples.size()) * 100.0


func _segment_overlaps_cut_area(start: Vector2, end: Vector2) -> bool:
	if _covered_sample_indices.is_empty():
		return false
	var half_swath := CUT_SWATH_WIDTH * 0.5
	for sample_index_value in _covered_sample_indices.keys():
		var sample_index := int(sample_index_value)
		if (
			sample_index >= 0
			and sample_index < _coverage_samples.size()
			and _segment_distance_to_point(
				start,
				end,
				_coverage_samples[sample_index]
			) <= half_swath
		):
			return true
	return false


func _vegetable_center() -> Vector2:
	return size * 0.5 + Vector2(0.0, 8.0)


func safe_center() -> Vector2:
	return _vegetable_center()


func safe_radius() -> float:
	return SAFE_RADIUS


func _segment_touches_vegetable(start: Vector2, end: Vector2) -> bool:
	if _point_in_vegetable(start) or _point_in_vegetable(end):
		return true
	for step in range(1, 8):
		var point := start.lerp(end, float(step) / 8.0)
		if _point_in_vegetable(point):
			return true
	return false


func _point_in_vegetable(point: Vector2) -> bool:
	var local := point - _vegetable_center()
	if vegetable_id == &"carrot":
		var normalized := Vector2(
			local.x / CARROT_HALF_WIDTH,
			local.y / CARROT_HALF_HEIGHT
		)
		return normalized.length_squared() <= 1.2
	return local.length_squared() <= TOMATO_RADIUS * TOMATO_RADIUS


func _segment_distance_to_point(start: Vector2, end: Vector2, point: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.001:
		return start.distance_to(point)
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return start.lerp(end, ratio).distance_to(point)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("152d21"))
	draw_rect(Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0)), Color("1d3a29"))
	draw_line(
		Vector2(size.x * 0.5, 18.0),
		Vector2(size.x * 0.5, size.y - 18.0),
		Color(0.85098, 0.92549, 0.439216, 0.22),
		1.0
	)

	var center := _vegetable_center()
	if vegetable_id == &"carrot":
		_draw_carrot(center)
	else:
		_draw_tomato(center)

	if _dragging and _gesture_start.distance_to(_gesture_end) >= 1.0:
		draw_line(_gesture_start, _gesture_end, Color("f1f4dd", 0.48), 3.0, true)

	for cut in _cuts:
		var start := cut.get("start", Vector2.ZERO) as Vector2
		var end := cut.get("end", Vector2.ZERO) as Vector2
		var cut_color := Color("ff8d78") if bool(cut.get("hit_center", false)) else Color("f1f4dd")
		if bool(cut.get("already_cut", false)):
			cut_color = Color("e4b75b")
		if bool(cut.get("valid", false)):
			cut_color = Color("9be27a")
		draw_line(start, end, cut_color, 4.0, true)
		draw_circle(end, 3.5, cut_color)

	var safe_color := Color("ffe19a", 0.34)
	if _outcome == 2:
		safe_color = Color("ff8d78", 0.62)
	elif _outcome == 1:
		safe_color = Color("9be27a", 0.55)
	draw_arc(center, SAFE_RADIUS, 0.0, TAU, 40, safe_color, 3.0, true)
	draw_arc(center, SAFE_RADIUS - 7.0, 0.0, TAU, 40, safe_color, 1.0, true)


func _draw_tomato(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, 7.0), TOMATO_RADIUS, Color("753c35"))
	draw_circle(center, TOMATO_RADIUS - 5.0, Color("d85f4e"))
	draw_arc(center, TOMATO_RADIUS - 5.0, 0.0, TAU, 48, Color("f08b68"), 3.0, true)
	draw_circle(center + Vector2(-34.0, -40.0), 13.0, Color(1.0, 0.86, 0.72, 0.42))
	var leaf_color := Color("6c9c4c")
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-5.0, -72.0),
			center + Vector2(-34.0, -101.0),
			center + Vector2(-17.0, -68.0)
		]),
		leaf_color
	)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-8.0, -66.0),
			center + Vector2(-58.0, -74.0),
			center + Vector2(-13.0, -54.0)
		]),
		leaf_color
	)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(4.0, -71.0),
			center + Vector2(34.0, -96.0),
			center + Vector2(19.0, -59.0)
		]),
		leaf_color
	)
	draw_line(center + Vector2(0.0, -78.0), center + Vector2(0.0, -96.0), Color("496f3c"), 5.0)


func _draw_carrot(center: Vector2) -> void:
	var body := PackedVector2Array([
		center + Vector2(-39.0, -91.0),
		center + Vector2(0.0, -108.0),
		center + Vector2(39.0, -91.0),
		center + Vector2(43.0, -34.0),
		center + Vector2(30.0, 38.0),
		center + Vector2(10.0, 91.0),
		center + Vector2(0.0, 108.0),
		center + Vector2(-10.0, 91.0),
		center + Vector2(-30.0, 38.0),
		center + Vector2(-43.0, -34.0)
	])
	draw_colored_polygon(body, Color("9a4e29"))
	var inner_body := PackedVector2Array([
		center + Vector2(-34.0, -88.0),
		center + Vector2(0.0, -101.0),
		center + Vector2(34.0, -88.0),
		center + Vector2(37.0, -32.0),
		center + Vector2(24.0, 35.0),
		center + Vector2(0.0, 98.0),
		center + Vector2(-24.0, 35.0),
		center + Vector2(-37.0, -32.0)
	])
	draw_colored_polygon(inner_body, Color("e69a3e"))
	draw_polyline(body, Color("f3bd68"), 3.0, true)
	for offset in [-38.0, 0.0, 38.0]:
		draw_line(center + Vector2(offset * 0.45, -38.0), center + Vector2(offset * 0.18, 55.0), Color(0.56, 0.25, 0.12, 0.38), 2.0)
	var leaf_color := Color("6c9c4c")
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-4.0, -84.0),
			center + Vector2(-42.0, -125.0),
			center + Vector2(-18.0, -82.0)
		]),
		leaf_color
	)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -84.0),
			center + Vector2(2.0, -132.0),
			center + Vector2(12.0, -83.0)
		]),
		leaf_color
	)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(8.0, -83.0),
			center + Vector2(47.0, -116.0),
			center + Vector2(22.0, -73.0)
		]),
		leaf_color
	)
