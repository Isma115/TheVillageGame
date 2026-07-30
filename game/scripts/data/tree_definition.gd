extends Resource
class_name TreeDefinition

@export_group("Identidad")
@export var id: StringName = &"tree"
@export var label := "Árbol"
@export_enum("broadleaf", "pine") var visual_style := "broadleaf"

@export_group("Representación")
@export var texture: Texture2D
@export_range(1.0, 512.0, 1.0) var sprite_render_size := 128.0
@export var trunk_color := Color("#76502f")
@export var trunk_light_color := Color("#9a7041")
@export var canopy_dark_color := Color("#285c35")
@export var canopy_color := Color("#3f7d42")
@export var canopy_light_color := Color("#64a64e")
@export var trunk_size := Vector2(15.0, 54.0)
@export_range(4.0, 256.0, 1.0) var canopy_radius := 42.0

@export_group("Interacción")
@export_range(1.0, 256.0, 1.0) var collision_radius := 15.0
@export_range(1.0, 512.0, 1.0) var interaction_distance := 92.0
@export_range(1, 1000, 1) var max_health := 3

@export_group("Recolección")
@export var yielded_item: ItemDefinition
@export_range(0, 9999, 1) var yield_min := 3
@export_range(0, 9999, 1) var yield_max := 5


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un árbol no tiene id.")
	if label.strip_edges().is_empty():
		errors.append("El árbol '%s' no tiene nombre visible." % id)
	if visual_style not in ["broadleaf", "pine"]:
		errors.append("El árbol '%s' usa un estilo visual desconocido." % id)
	if sprite_render_size <= 0.0:
		errors.append("El árbol '%s' tiene un tamaño de sprite inválido." % id)
	if trunk_size.x <= 0.0 or trunk_size.y <= 0.0 or canopy_radius <= 0.0:
		errors.append("El árbol '%s' tiene dimensiones visuales inválidas." % id)
	if collision_radius <= 0.0 or interaction_distance <= collision_radius:
		errors.append("El árbol '%s' tiene distancias de interacción inválidas." % id)
	if max_health <= 0:
		errors.append("El árbol '%s' no tiene salud válida." % id)
	if yielded_item == null:
		errors.append("El árbol '%s' no tiene recompensa configurada." % id)
	if yield_min < 0 or yield_max < yield_min:
		errors.append("El árbol '%s' tiene un rango de recompensa inválido." % id)
	return errors
