extends RefCounted
class_name InputState

var virtual_direction := Vector2.ZERO
var virtual_sprinting := false
var _interaction_requested := false
var _control_settings


func configure(control_settings) -> void:
	_control_settings = control_settings


func direction() -> Vector2:
	var keyboard_direction := Vector2.ZERO

	if _is_action_pressed(&"move_right", KEY_RIGHT, KEY_D):
		keyboard_direction.x += 1.0
	if _is_action_pressed(&"move_left", KEY_LEFT, KEY_A):
		keyboard_direction.x -= 1.0
	if _is_action_pressed(&"move_down", KEY_DOWN, KEY_S):
		keyboard_direction.y += 1.0
	if _is_action_pressed(&"move_up", KEY_UP, KEY_W):
		keyboard_direction.y -= 1.0

	return (keyboard_direction + virtual_direction).limit_length(1.0)


func sprinting() -> bool:
	return virtual_sprinting or _is_action_pressed(&"sprint", KEY_SHIFT)


func set_virtual_direction(direction_value: Vector2) -> void:
	virtual_direction = direction_value.limit_length(1.0)


func set_virtual_sprinting(active: bool) -> void:
	virtual_sprinting = active


func handle_event(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if _matches_action(event, &"interact", KEY_E, KEY_SPACE):
		request_interaction()


func request_interaction() -> void:
	_interaction_requested = true


func consume_interaction_request() -> bool:
	var requested := _interaction_requested
	_interaction_requested = false
	return requested


func reset_virtual_controls() -> void:
	virtual_direction = Vector2.ZERO
	virtual_sprinting = false
	_interaction_requested = false


func _is_action_pressed(
	action_id: StringName,
	primary_fallback: Key,
	secondary_fallback: Key = KEY_NONE
) -> bool:
	if _control_settings != null:
		return _control_settings.is_action_pressed(action_id)
	return (
		Input.is_key_pressed(primary_fallback)
		or (
			secondary_fallback != KEY_NONE
			and Input.is_key_pressed(secondary_fallback)
		)
	)


func _matches_action(
	event: InputEvent,
	action_id: StringName,
	primary_fallback: Key,
	secondary_fallback: Key = KEY_NONE
) -> bool:
	if _control_settings != null:
		return _control_settings.matches_event(action_id, event)
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	return (
		key_event.keycode == primary_fallback
		or key_event.physical_keycode == primary_fallback
		or (
			secondary_fallback != KEY_NONE
			and key_event.keycode == secondary_fallback
		)
	)
