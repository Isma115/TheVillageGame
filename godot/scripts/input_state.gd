extends RefCounted
class_name InputState

var virtual_direction := Vector2.ZERO
var virtual_sprinting := false

func direction() -> Vector2:
	var keyboard_direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		keyboard_direction.x += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		keyboard_direction.x -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		keyboard_direction.y += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		keyboard_direction.y -= 1.0

	var combined := keyboard_direction + virtual_direction
	return combined.limit_length(1.0)

func sprinting() -> bool:
	return virtual_sprinting or Input.is_key_pressed(KEY_SHIFT)

func set_virtual_direction(direction_value: Vector2) -> void:
	virtual_direction = direction_value.limit_length(1.0)

func set_virtual_sprinting(active: bool) -> void:
	virtual_sprinting = active
