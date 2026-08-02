extends Resource
class_name DoctorDefinition

@export var service_name := "Consulta médica"
@export_range(1, 999999, 1) var consultation_cost := 5
@export var bandage_item: ItemDefinition
@export_range(1, 999999, 1) var bandage_cost := 8
@export_range(1, 999999, 1) var bandage_quantity := 1


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if service_name.strip_edges().is_empty():
		errors.append("La consulta médica no tiene nombre visible.")
	if consultation_cost <= 0:
		errors.append("La consulta médica debe tener un coste positivo.")
	if bandage_item == null:
		errors.append("La consulta medica no tiene una venda disponible.")
	if bandage_cost <= 0:
		errors.append("La venda del medico debe tener un coste positivo.")
	if bandage_quantity <= 0:
		errors.append("La compra de vendas debe tener una cantidad positiva.")
	return errors
