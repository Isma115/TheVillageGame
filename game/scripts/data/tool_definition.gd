extends Resource
class_name ToolDefinition

@export var id: StringName = &"tool"
@export var label := "Herramienta"
@export var capabilities: Array[StringName] = []
@export_range(1, 999999, 1) var maximum_durability := 100
@export_range(0.0, 1.0, 0.01) var initial_durability_ratio := 0.5
@export_range(1, 999999, 1) var durability_cost := 1
@export var display_color := Color("#f1f4dd")


func supports(capability: StringName) -> bool:
	return capability in capabilities


func initial_durability() -> int:
	return clampi(
		roundi(float(maximum_durability) * initial_durability_ratio),
		0,
		maximum_durability
	)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Una herramienta no tiene id.")
	if label.strip_edges().is_empty():
		errors.append("La herramienta '%s' no tiene nombre visible." % id)
	if capabilities.is_empty():
		errors.append("La herramienta '%s' no tiene ninguna capacidad." % id)
	for capability in capabilities:
		if String(capability).strip_edges().is_empty():
			errors.append("La herramienta '%s' tiene una capacidad vacía." % id)
	if maximum_durability <= 0:
		errors.append("La herramienta '%s' tiene una durabilidad máxima inválida." % id)
	if initial_durability_ratio < 0.0 or initial_durability_ratio > 1.0:
		errors.append("La durabilidad inicial de '%s' debe estar entre 0 y 1." % id)
	if durability_cost <= 0:
		errors.append("La herramienta '%s' tiene un coste de uso inválido." % id)
	return errors
