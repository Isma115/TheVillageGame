extends Resource
class_name MineralDepositDefinition

@export var id: StringName = &"deposit"
@export var mineral: MineralDefinition
@export var world_position := Vector2.ZERO
@export_range(0.1, 4.0, 0.01) var visual_scale := 1.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Una veta no tiene id.")
	if mineral == null:
		errors.append("La veta '%s' no tiene mineral." % id)
	if visual_scale <= 0.0:
		errors.append("La veta '%s' tiene una escala inválida." % id)
	return errors
