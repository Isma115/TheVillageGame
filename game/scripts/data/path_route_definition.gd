extends Resource
class_name PathRouteDefinition

@export var id: StringName = &"route"
@export var points := PackedVector2Array()


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Una ruta no tiene id.")
	if points.size() < 2:
		errors.append("La ruta '%s' necesita al menos dos puntos." % id)
	return errors
