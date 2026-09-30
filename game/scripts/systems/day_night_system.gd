extends RefCounted
class_name DayNightSystem

signal time_changed(day_number: int, hour: int, minute: int, phase: StringName)
signal phase_changed(phase: StringName)

const MINUTES_PER_DAY := 1440.0

const PHASE_NIGHT: StringName = &"night"
const PHASE_DAWN: StringName = &"dawn"
const PHASE_DAY: StringName = &"day"
const PHASE_DUSK: StringName = &"dusk"

var cycle_duration_seconds := 900.0
var initial_hour := 8.0
var dawn_start_hour := 5.0
var sunrise_hour := 7.0
var sunset_hour := 19.0
var dusk_end_hour := 21.0

var night_color := Color("#35466f")
var dawn_color := Color("#d18f83")
var day_color := Color("#fffdf2")
var dusk_color := Color("#d98a70")

var _day_number := 1
var _time_minutes := 480.0
var _last_displayed_minute := -1
var _phase: StringName = &""
var _canvas_modulate: CanvasModulate


func initialize(
	duration_seconds: float,
	starting_hour: float,
	dawn_start: float,
	sunrise: float,
	sunset: float,
	dusk_end: float,
	canvas_modulate: CanvasModulate
) -> void:
	cycle_duration_seconds = maxf(duration_seconds, 1.0)
	initial_hour = fposmod(starting_hour, 24.0)
	dawn_start_hour = clampf(dawn_start, 0.0, 24.0)
	sunrise_hour = clampf(sunrise, dawn_start_hour, 24.0)
	sunset_hour = clampf(sunset, sunrise_hour, 24.0)
	dusk_end_hour = clampf(dusk_end, sunset_hour, 24.0)
	_canvas_modulate = canvas_modulate
	_day_number = 1
	_time_minutes = initial_hour * 60.0
	_phase = &""
	_last_displayed_minute = -1
	_apply_visual_state()
	_emit_time(true)


func update(delta: float) -> void:
	if delta <= 0.0 or cycle_duration_seconds <= 0.0:
		return

	var minutes_advanced := delta * MINUTES_PER_DAY / cycle_duration_seconds
	var next_time := _time_minutes + minutes_advanced
	var completed_days := int(floor(next_time / MINUTES_PER_DAY))
	if completed_days > 0:
		_day_number += completed_days
	_time_minutes = fmod(next_time, MINUTES_PER_DAY)
	_apply_visual_state()
	_emit_time(false)


func advance_to_next_day(wake_hour: float = 6.0) -> void:
	_day_number += 1
	_time_minutes = clampf(wake_hour, 0.0, 23.99) * 60.0
	_apply_visual_state()
	_emit_time(true)


func set_time(day_number: int, time_minutes: float) -> void:
	_day_number = maxi(day_number, 1)
	_time_minutes = fposmod(time_minutes, MINUTES_PER_DAY)
	_apply_visual_state()
	_emit_time(true)


func day_number() -> int:
	return _day_number


func time_minutes() -> float:
	return _time_minutes


func hour() -> int:
	return int(floor(_time_minutes / 60.0))


func minute() -> int:
	return int(floor(fmod(_time_minutes, 60.0)))


func phase() -> StringName:
	return _phase_for_hour(_time_minutes / 60.0)


func is_night() -> bool:
	return phase() == PHASE_NIGHT


func formatted_time() -> String:
	return "%02d:%02d" % [hour(), minute()]


func phase_label() -> String:
	match phase():
		PHASE_DAWN:
			return "Amanecer"
		PHASE_DAY:
			return "Día"
		PHASE_DUSK:
			return "Atardecer"
		_:
			return "Noche"


func snapshot() -> Dictionary:
	return {
		"day": _day_number,
		"time_minutes": _time_minutes
	}


func restore(snapshot_data: Dictionary) -> void:
	if snapshot_data.is_empty():
		return
	var saved_day: Variant = snapshot_data.get("day", _day_number)
	var saved_minutes: Variant = snapshot_data.get("time_minutes", _time_minutes)
	var next_day := _day_number
	var next_minutes := _time_minutes
	if typeof(saved_day) == TYPE_INT or typeof(saved_day) == TYPE_FLOAT:
		next_day = maxi(int(saved_day), 1)
	if typeof(saved_minutes) == TYPE_INT or typeof(saved_minutes) == TYPE_FLOAT:
		next_minutes = float(saved_minutes)
	set_time(next_day, next_minutes)


func _phase_for_hour(current_hour: float) -> StringName:
	if current_hour >= dawn_start_hour and current_hour < sunrise_hour:
		return PHASE_DAWN
	if current_hour >= sunrise_hour and current_hour < sunset_hour:
		return PHASE_DAY
	if current_hour >= sunset_hour and current_hour < dusk_end_hour:
		return PHASE_DUSK
	return PHASE_NIGHT


func _apply_visual_state() -> void:
	if not is_instance_valid(_canvas_modulate):
		return
	var current_hour := _time_minutes / 60.0
	var visual_color := night_color
	if current_hour >= dawn_start_hour and current_hour < sunrise_hour:
		var dawn_progress := _smoothstep(
			dawn_start_hour,
			sunrise_hour,
			current_hour
		)
		visual_color = night_color.lerp(dawn_color, dawn_progress)
	elif current_hour >= sunrise_hour and current_hour < sunset_hour:
		visual_color = day_color
	elif current_hour >= sunset_hour and current_hour < dusk_end_hour:
		var dusk_progress := _smoothstep(
			sunset_hour,
			dusk_end_hour,
			current_hour
		)
		visual_color = day_color.lerp(dusk_color, dusk_progress)
	_canvas_modulate.color = visual_color


func _emit_time(force: bool) -> void:
	var current_phase := phase()
	var displayed_minute := _day_number * int(MINUTES_PER_DAY) + minute()
	if force or displayed_minute != _last_displayed_minute:
		_last_displayed_minute = displayed_minute
		time_changed.emit(_day_number, hour(), minute(), current_phase)
	if force or current_phase != _phase:
		_phase = current_phase
		phase_changed.emit(current_phase)


func _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
	if edge_end <= edge_start:
		return 1.0 if value >= edge_end else 0.0
	var normalized := clampf(
		(value - edge_start) / (edge_end - edge_start),
		0.0,
		1.0
	)
	return normalized * normalized * (3.0 - 2.0 * normalized)
