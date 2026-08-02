extends Resource
class_name ItemDefinition

@export var id: StringName = &"item"
@export var label := "Objeto"
@export_range(1, 999999, 1) var max_stack := 999
@export var display_color := Color("#f1f4dd")
@export var usable := false
@export_range(0.0, 999999.0, 0.1) var health_recovery := 0.0
@export_range(0.0, 999999.0, 0.1) var health_recovery_duration := 0.0


func is_usable() -> bool:
	return usable


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un objeto no tiene id.")
	if label.strip_edges().is_empty():
		errors.append("El objeto '%s' no tiene nombre visible." % id)
	if max_stack <= 0:
		errors.append("El objeto '%s' tiene un tamaño de pila inválido." % id)
	if usable and health_recovery <= 0.0:
		errors.append("El objeto consumible '%s' no tiene una curacion valida." % id)
	if usable and health_recovery_duration <= 0.0:
		errors.append("El objeto consumible '%s' no tiene una duracion valida." % id)
	return errors
