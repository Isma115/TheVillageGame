extends RefCounted
class_name TemperatureSystem

signal temperature_changed(temperature: float)

var minimum_temperature := 25.0
var maximum_temperature := 30.0
var cycle_duration := 240.0
var _elapsed := 0.0
var _temperature := 27.5


func initialize(
	minimum: float,
	maximum: float,
	duration: float
) -> void:
	minimum_temperature = minimum
	maximum_temperature = maxf(maximum, minimum_temperature)
	cycle_duration = maxf(duration, 1.0)
	_elapsed = 0.0
	_temperature = _temperature_for_elapsed(_elapsed)
	temperature_changed.emit(_temperature)


func update(delta: float) -> void:
	if delta <= 0.0 or cycle_duration <= 0.0:
		return
	_elapsed = fmod(_elapsed + delta, cycle_duration)
	var next_temperature := _temperature_for_elapsed(_elapsed)
	if is_equal_approx(next_temperature, _temperature):
		return
	_temperature = next_temperature
	temperature_changed.emit(_temperature)


func current_temperature() -> float:
	return _temperature


func snapshot() -> Dictionary:
	return {
		"elapsed": _elapsed,
		"temperature": _temperature
	}


func restore(snapshot_data: Dictionary) -> void:
	if snapshot_data.is_empty():
		return
	_elapsed = fmod(
		maxf(float(snapshot_data.get("elapsed", _elapsed)), 0.0),
		cycle_duration
	)
	_temperature = _temperature_for_elapsed(_elapsed)
	temperature_changed.emit(_temperature)


func _temperature_for_elapsed(elapsed: float) -> float:
	var phase := TAU * elapsed / cycle_duration
	var normalized := (sin(phase) + 1.0) * 0.5
	return lerpf(minimum_temperature, maximum_temperature, normalized)
