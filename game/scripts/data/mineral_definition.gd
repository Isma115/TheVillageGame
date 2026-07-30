extends Resource
class_name MineralDefinition

@export_group("Identidad")
@export var id: StringName = &"mineral"
@export var label := "Mineral"
@export var yielded_item: ItemDefinition

@export_group("Representación")
@export var rock_color := Color("#49454a")
@export var rock_dark_color := Color("#302d32")
@export var ore_color := Color("#9a744d")
@export var ore_light_color := Color("#d6ad72")
@export_range(8.0, 128.0, 1.0) var visual_radius := 34.0

@export_group("Interacción")
@export_range(1.0, 128.0, 1.0) var collision_radius := 22.0
@export_range(1.0, 256.0, 1.0) var interaction_distance := 92.0
@export_range(1, 1000, 1) var max_health := 3

@export_group("Extracción")
@export_range(0, 9999, 1) var yield_min := 2
@export_range(0, 9999, 1) var yield_max := 4


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un mineral no tiene id.")
	if label.strip_edges().is_empty():
		errors.append("El mineral '%s' no tiene nombre visible." % id)
	if yielded_item == null:
		errors.append("El mineral '%s' no tiene recurso extraíble." % id)
	if visual_radius <= 0.0 or collision_radius <= 0.0:
		errors.append("El mineral '%s' tiene dimensiones inválidas." % id)
	if interaction_distance <= collision_radius:
		errors.append("El mineral '%s' tiene un alcance de interacción inválido." % id)
	if max_health <= 0:
		errors.append("El mineral '%s' no tiene resistencia válida." % id)
	if yield_min < 0 or yield_max < yield_min:
		errors.append("El mineral '%s' tiene un rango de extracción inválido." % id)
	return errors
