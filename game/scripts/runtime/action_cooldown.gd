extends RefCounted
class_name ActionCooldown

var _ready_at_msec := 0


func try_start(duration_seconds: float) -> bool:
	var now := Time.get_ticks_msec()
	if now < _ready_at_msec:
		return false

	_ready_at_msec = now + roundi(maxf(duration_seconds, 0.0) * 1000.0)
	return true


func reset() -> void:
	_ready_at_msec = 0


func remaining_seconds() -> float:
	return maxf(0.0, float(_ready_at_msec - Time.get_ticks_msec()) / 1000.0)
