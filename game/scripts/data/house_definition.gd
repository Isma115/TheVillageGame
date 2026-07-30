extends Resource
class_name HouseDefinition

@export_group("Identidad")
@export var id: StringName = &"house"
@export var label := "Casa"
@export var texture: Texture2D

@export_group("Mundo")
@export var world_position := Vector2.ZERO
@export_range(1.0, 2048.0, 1.0) var render_size := 350.0
@export var collision_rect := Rect2(-126.0, -96.0, 252.0, 84.0)


func world_collision_rect() -> Rect2:
	return Rect2(world_position + collision_rect.position, collision_rect.size)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Una casa no tiene id.")
	if texture == null:
		errors.append("La casa '%s' no tiene textura." % id)
	if render_size <= 0.0:
		errors.append("La casa '%s' tiene un tamaño visual inválido." % id)
	if collision_rect.size.x <= 0.0 or collision_rect.size.y <= 0.0:
		errors.append("La casa '%s' tiene una colisión inválida." % id)
	return errors
