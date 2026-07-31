extends Resource
class_name HotelDefinition

@export_group("Identidad")
@export var id: StringName = &"hotel"
@export var area_id: StringName = &"village_hotel"
@export var label: String = "Hotel de la aldea"

@export_group("Distribución")
@export var interior_size: Vector2 = Vector2(960.0, 720.0)
@export_range(16.0, 256.0, 1.0) var wall_inset: float = 56.0
@export var player_spawn: Vector2 = Vector2(480.0, 560.0)
@export var bed_position: Vector2 = Vector2(720.0, 200.0)
@export var rest_position: Vector2 = Vector2(720.0, 310.0)
@export var interior_obstacles: Array[Rect2] = []

@export_group("Paleta")
@export var void_color: Color = Color("182a38")
@export var wall_color: Color = Color("324c63")
@export var wall_light_color: Color = Color("54738e")
@export var floor_color: Color = Color("b7a58a")
@export var floor_light_color: Color = Color("d6c7a9")
@export var accent_color: Color = Color("6fa5cf")

func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, interior_size)

func playable_bounds() -> Rect2:
	var inset := Vector2.ONE * wall_inset
	return Rect2(inset, interior_size - inset * 2.0)

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == StringName():
		errors.append("El hotel debe tener un id.")
	if area_id == StringName():
		errors.append("El hotel debe tener un area_id.")
	if label.strip_edges().is_empty():
		errors.append("El hotel debe tener un nombre.")
	if interior_size.x <= wall_inset * 2.0 or interior_size.y <= wall_inset * 2.0:
		errors.append("El interior del hotel debe ser mayor que sus paredes.")
	var bounds := playable_bounds()
	if not bounds.has_point(player_spawn):
		errors.append("El punto de aparición del hotel debe estar dentro del área jugable.")
	if not bounds.has_point(rest_position):
		errors.append("El punto de descanso del hotel debe estar dentro del área jugable.")
	if not world_rect().has_point(bed_position):
		errors.append("La cama del hotel debe estar dentro del interior.")
	for obstacle in interior_obstacles:
		if obstacle.size.x <= 0.0 or obstacle.size.y <= 0.0:
			errors.append("El hotel contiene un obstáculo sin tamaño.")
		elif not bounds.encloses(obstacle):
			errors.append("El hotel contiene un obstáculo fuera del área jugable: %s" % obstacle)
	return errors
