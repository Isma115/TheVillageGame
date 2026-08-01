extends Resource
class_name CropDefinition

@export_group("Identidad")
@export var id: StringName = &"crop"
@export var seed_id: StringName = &"crop_seed"
@export var label := "Cultivo"
@export var harvest_item_id: StringName = &""

@export_group("Crecimiento")
@export_range(1.0, 999999.0, 1.0) var growth_time := 45.0

@export_group("Representación")
@export var grown_texture: Texture2D
@export_range(1.0, 256.0, 1.0) var sprite_render_size := 64.0
@export var display_color := Color("#7eb957")


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un cultivo no tiene id.")
	if String(seed_id).is_empty():
		errors.append("El cultivo '%s' no tiene semilla configurada." % id)
	if String(harvest_item_id).is_empty():
		errors.append("El cultivo '%s' no tiene objeto de cosecha configurado." % id)
	if label.strip_edges().is_empty():
		errors.append("El cultivo '%s' no tiene nombre visible." % id)
	if growth_time <= 0.0:
		errors.append("El cultivo '%s' tiene un tiempo de crecimiento inválido." % id)
	if grown_texture == null:
		errors.append("El cultivo '%s' no tiene sprite maduro." % id)
	if sprite_render_size <= 0.0:
		errors.append("El cultivo '%s' tiene un tamaño de sprite inválido." % id)
	return errors
