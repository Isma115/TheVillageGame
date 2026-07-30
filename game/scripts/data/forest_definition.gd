extends Resource
class_name ForestDefinition

@export_group("Generación")
@export var random_seed := 7319
@export_range(0, 10000, 1) var target_tree_count := 96
@export_range(1, 100000, 1) var max_generation_attempts := 6000
@export_range(1.0, 512.0, 1.0) var minimum_spacing := 72.0
@export_range(0.0, 4096.0, 1.0) var village_clear_radius := 510.0
@export_range(0.0, 512.0, 1.0) var path_clearance := 44.0
@export_range(0.0, 512.0, 1.0) var house_clearance := 76.0
@export_range(0.0, 512.0, 1.0) var player_spawn_clearance := 120.0
@export_range(0.0, 512.0, 1.0) var animal_spawn_clearance := 90.0
@export_range(0.0, 512.0, 1.0) var world_edge_inset := 26.0
@export var scale_range := Vector2(0.86, 1.16)

@export_group("Especies")
@export var tree_types: Array[TreeDefinition] = []
@export var type_weights := PackedFloat32Array()

@export_group("Tala")
@export_range(0.0, 10.0, 0.01) var chop_cooldown := 0.32
@export_range(1, 1000, 1) var base_chop_damage := 1


func tree_definitions() -> Array[TreeDefinition]:
	var definitions: Array[TreeDefinition] = []
	for resource in tree_types:
		if resource is TreeDefinition:
			definitions.append(resource)
	return definitions


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if target_tree_count < 0:
		errors.append("La cantidad objetivo de árboles es inválida.")
	if max_generation_attempts < maxi(target_tree_count, 1):
		errors.append("El bosque no tiene suficientes intentos de generación.")
	if minimum_spacing <= 0.0:
		errors.append("La separación mínima del bosque debe ser positiva.")
	if scale_range.x <= 0.0 or scale_range.y < scale_range.x:
		errors.append("El rango de escala del bosque es inválido.")
	if tree_definitions().is_empty() and target_tree_count > 0:
		errors.append("El bosque no tiene especies configuradas.")
	if tree_definitions().size() != tree_types.size():
		errors.append("El bosque contiene una definición de árbol no válida.")
	if not type_weights.is_empty() and type_weights.size() != tree_types.size():
		errors.append("Los pesos de especies no coinciden con las especies del bosque.")
	if base_chop_damage <= 0 or chop_cooldown < 0.0:
		errors.append("La configuración de tala es inválida.")

	for definition in tree_definitions():
		errors.append_array(definition.validate())

	var total_weight := 0.0
	for weight in type_weights:
		total_weight += maxf(weight, 0.0)
	if not type_weights.is_empty() and total_weight <= 0.0:
		errors.append("Las especies del bosque no tienen ningún peso positivo.")
	return errors
