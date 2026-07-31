extends Resource
class_name DoctorDefinition

@export var service_name := "Consulta médica"
@export_range(1, 999999, 1) var consultation_cost := 5


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if service_name.strip_edges().is_empty():
		errors.append("La consulta médica no tiene nombre visible.")
	if consultation_cost <= 0:
		errors.append("La consulta médica debe tener un coste positivo.")
	return errors
