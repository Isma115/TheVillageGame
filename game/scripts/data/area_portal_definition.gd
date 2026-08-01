extends Resource
class_name AreaPortalDefinition

@export_group("Identidad")
@export var id: StringName = &"portal"
@export var label := "Cambiar de área"
@export var source_area_id: StringName = &"overworld"
@export var target_area_id: StringName = &"area"

@export_group("Transición")
@export var world_position := Vector2.ZERO
@export var target_position := Vector2.ZERO
@export var interaction_offset := Vector2.ZERO
@export_range(1.0, 512.0, 1.0) var interaction_distance := 100.0
@export_range(-1000, 1000, 1) var priority := 100

@export_group("Representación")
@export_enum("sprite", "stairs") var visual_style := "stairs"
@export var texture: Texture2D
@export var render_rect := Rect2(-64.0, -84.0, 128.0, 96.0)
@export var collision_rect := Rect2()
@export var accent_color := Color("#d6ad72")
@export var visible := true


func world_render_rect() -> Rect2:
	return Rect2(world_position + render_rect.position, render_rect.size)


func world_collision_rect() -> Rect2:
	return Rect2(world_position + collision_rect.position, collision_rect.size)


func has_collision() -> bool:
	return collision_rect.size.x > 0.0 and collision_rect.size.y > 0.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un portal no tiene id.")
	if label.strip_edges().is_empty():
		errors.append("El portal '%s' no tiene texto de interacción." % id)
	if String(source_area_id).is_empty() or String(target_area_id).is_empty():
		errors.append("El portal '%s' no tiene áreas válidas." % id)
	if source_area_id == target_area_id:
		errors.append("El portal '%s' apunta a su propia área." % id)
	if interaction_distance <= 0.0:
		errors.append("El portal '%s' no tiene alcance válido." % id)
	if visual_style not in ["sprite", "stairs"]:
		errors.append("El portal '%s' usa un estilo visual desconocido." % id)
	if render_rect.size.x <= 0.0 or render_rect.size.y <= 0.0:
		errors.append("El portal '%s' tiene dimensiones visuales inválidas." % id)
	if visual_style == "sprite" and texture == null:
		errors.append("El portal '%s' necesita una textura." % id)
	if (
		collision_rect.size.x < 0.0
		or collision_rect.size.y < 0.0
		or (collision_rect.size.x == 0.0) != (collision_rect.size.y == 0.0)
	):
		errors.append("El portal '%s' tiene una colisión inválida." % id)
	return errors
