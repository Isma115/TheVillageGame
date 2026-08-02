extends Resource
class_name MineDefinition

@export_group("Escenario")
@export var id: StringName = &"mine"
@export var area_id: StringName = &"mine"
@export var label := "Mina"
@export var interior_size := Vector2(2400.0, 1800.0)
@export_range(0.0, 512.0, 1.0) var wall_inset := 62.0
@export var player_spawn := Vector2(1200.0, 150.0)
@export var interior_obstacles: Array[Rect2] = []

@export_group("Contenido")
@export var minerals: Array[MineralDefinition] = []
@export var deposits: Array[MineralDepositDefinition] = []
@export var random_seed := 18437

@export_group("Minería")
@export_range(0.0, 10.0, 0.01) var mining_cooldown := 0.34
@export_range(1, 1000, 1) var base_mining_damage := 1

@export_group("Aspecto")
@export var void_color := Color("#17151a")
@export var wall_color := Color("#343039")
@export var wall_light_color := Color("#514851")
@export var floor_color := Color("#29262d")
@export var floor_light_color := Color("#38333a")
@export var crack_color := Color("#1d1b20")
@export var lamp_color := Color("#f3b94f")


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, interior_size)


func playable_bounds() -> Rect2:
	var inset := Vector2.ONE * wall_inset
	return Rect2(inset, interior_size - inset * 2.0)


func mineral_definitions() -> Array[MineralDefinition]:
	var definitions: Array[MineralDefinition] = []
	for resource in minerals:
		if resource is MineralDefinition:
			definitions.append(resource)
	return definitions


func deposit_definitions() -> Array[MineralDepositDefinition]:
	var definitions: Array[MineralDepositDefinition] = []
	for resource in deposits:
		if resource is MineralDepositDefinition:
			definitions.append(resource)
	return definitions


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("La mina no tiene id.")
	if String(area_id).is_empty():
		errors.append("La mina '%s' no tiene id de área." % id)
	if label.strip_edges().is_empty():
		errors.append("La mina '%s' no tiene nombre visible." % id)
	if interior_size.x <= 0.0 or interior_size.y <= 0.0:
		errors.append("La mina '%s' tiene dimensiones inválidas." % id)
	if playable_bounds().size.x <= 0.0 or playable_bounds().size.y <= 0.0:
		errors.append("Los muros dejan la mina '%s' sin área jugable." % id)
	if not playable_bounds().has_point(player_spawn):
		errors.append("El jugador aparece fuera del área jugable de la mina '%s'." % id)
	if mining_cooldown < 0.0 or base_mining_damage <= 0:
		errors.append("La configuración de minería de '%s' es inválida." % id)
	if mineral_definitions().size() != minerals.size():
		errors.append("La mina '%s' contiene una definición de mineral no válida." % id)
	if deposit_definitions().size() != deposits.size():
		errors.append("La mina '%s' contiene una definición de veta no válida." % id)

	var seen_mineral_ids: Dictionary = {}
	for mineral in mineral_definitions():
		errors.append_array(mineral.validate())
		if seen_mineral_ids.has(mineral.id):
			errors.append("El mineral '%s' está duplicado en la mina." % mineral.id)
		seen_mineral_ids[mineral.id] = true

	for obstacle_index in range(interior_obstacles.size()):
		var obstacle := interior_obstacles[obstacle_index]
		if obstacle.size.x <= 0.0 or obstacle.size.y <= 0.0:
			errors.append("El obstáculo %d de la mina es inválido." % obstacle_index)
		elif not world_rect().encloses(obstacle):
			errors.append("El obstáculo %d queda fuera de la mina." % obstacle_index)

	var seen_deposit_ids: Dictionary = {}
	for deposit in deposit_definitions():
		errors.append_array(deposit.validate())
		if seen_deposit_ids.has(deposit.id):
			errors.append("La veta '%s' está duplicada." % deposit.id)
		seen_deposit_ids[deposit.id] = true
		if deposit.mineral != null and not seen_mineral_ids.has(deposit.mineral.id):
			errors.append(
				"La veta '%s' usa un mineral no registrado en la mina."
				% deposit.id
			)
		if not playable_bounds().has_point(deposit.world_position):
			errors.append("La veta '%s' queda fuera del área jugable." % deposit.id)
			continue
		if deposit.mineral == null:
			continue
		var clearance := deposit.mineral.collision_radius * deposit.visual_scale
		for obstacle in interior_obstacles:
			if obstacle.grow(clearance).has_point(deposit.world_position):
				errors.append("La veta '%s' se solapa con un obstáculo." % deposit.id)
				break

	if not deposit_definitions().is_empty() and mineral_definitions().is_empty():
		errors.append("La mina tiene vetas pero no minerales registrados.")
	return errors
