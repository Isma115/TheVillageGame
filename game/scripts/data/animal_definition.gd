extends Resource
class_name AnimalDefinition

@export_group("Identidad")
@export var id: StringName = &"animal"
@export var label := "Animal"
@export var texture: Texture2D

@export_group("Aparición")
@export var world_position := Vector2.ZERO
@export var initial_direction := Vector2.RIGHT
@export var random_seed := 1

@export_group("Representación")
@export_range(1.0, 1024.0, 1.0) var render_width := 58.0
@export_range(0.0, 1.0, 0.01) var anchor_y := 0.86
@export_range(1, 64, 1) var sprite_columns := 8
@export_range(1, 64, 1) var sprite_rows := 4
@export var frame_size := Vector2i(192, 256)
@export var animation_rows := {
	&"idle": 0,
	&"walking": 1,
	&"running": 2,
	&"jumping": 3
}
@export var animation_fps := {
	&"idle": 5.0,
	&"walking": 10.0,
	&"running": 14.0,
	&"jumping": 9.0
}
@export var casts_shadow := true

@export_group("Movimiento")
@export_range(0.0, 512.0, 1.0) var collision_radius := 16.0
@export_range(0.0, 4096.0, 1.0) var wander_radius := 80.0
@export_range(0.0, 512.0, 1.0) var walking_speed := 58.0
@export_range(0.0, 512.0, 1.0) var running_speed := 96.0
@export_range(0.0, 512.0, 1.0) var jumping_speed := 76.0
@export_range(0.0, 512.0, 1.0) var jump_height := 12.0
@export_range(0.0, 512.0, 1.0) var hover_height := 0.0
@export var grounded := true
@export var collides_with_world := true

@export_group("Comportamiento")
@export_range(0.0, 100.0, 0.1) var idle_weight := 4.0
@export_range(0.0, 100.0, 0.1) var walking_weight := 5.0
@export_range(0.0, 100.0, 0.1) var running_weight := 2.0
@export_range(0.0, 100.0, 0.1) var jumping_weight := 1.0
@export var idle_duration := Vector2(1.2, 3.0)
@export var walking_duration := Vector2(1.8, 4.4)
@export var running_duration := Vector2(0.7, 1.6)
@export var jumping_duration := Vector2(0.8, 1.15)


func speed_for_state(state: StringName) -> float:
	match state:
		&"running":
			return running_speed
		&"jumping":
			return jumping_speed
		_:
			return walking_speed


func behavior_weights() -> Dictionary:
	return {
		&"idle": idle_weight,
		&"walking": walking_weight,
		&"running": running_weight,
		&"jumping": jumping_weight
	}


func duration_for_state(state: StringName) -> Vector2:
	match state:
		&"walking":
			return walking_duration
		&"running":
			return running_duration
		&"jumping":
			return jumping_duration
		_:
			return idle_duration


func animation_row_for_state(state: StringName) -> int:
	return int(animation_rows.get(state, animation_rows.get(&"idle", 0)))


func animation_fps_for_state(state: StringName) -> float:
	return float(animation_fps.get(state, animation_fps.get(&"idle", 5.0)))


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un animal no tiene id.")
	if texture == null:
		errors.append("El animal '%s' no tiene textura." % id)
	if render_width <= 0.0:
		errors.append("El animal '%s' tiene un ancho visual inválido." % id)
	if frame_size.x <= 0 or frame_size.y <= 0 or sprite_columns <= 0 or sprite_rows <= 0:
		errors.append("El animal '%s' tiene una cuadrícula de animación inválida." % id)
	if collision_radius < 0.0 or wander_radius < 0.0:
		errors.append("El animal '%s' tiene radios inválidos." % id)
	if idle_weight + walking_weight + running_weight + jumping_weight <= 0.0:
		errors.append("El animal '%s' no tiene comportamientos con peso." % id)
	return errors
