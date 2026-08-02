extends Resource
class_name GameCatalog

const OVERWORLD_AREA_ID: StringName = &"overworld"
const HOTEL_AREA_ID: StringName = &"village_hotel"
const REPAIRED_HOUSE_AREA_ID: StringName = &"repaired_house"

@export_category("Mundo")
@export_range(1, 4096, 1) var world_columns := 35
@export_range(1, 4096, 1) var world_rows := 35
@export var world_origin_cell := Vector2i.ZERO
@export_range(1.0, 1024.0, 1.0) var tile_size := 48.0
@export_range(0.0, 4096.0, 1.0) var edge_padding := 54.0
@export var grass_color := Color("#5d934f")
@export var ink_color := Color("#193724")
@export var grass_texture: Texture2D
@export var path_texture: Texture2D
@export var lake_position := Vector2(1368.0, 1248.0)
@export var lake_size := Vector2(240.0, 192.0)

@export_category("Entorno")
@export_range(0.0, 60.0, 0.1) var temperature_minimum := 25.0
@export_range(0.0, 60.0, 0.1) var temperature_maximum := 30.0
@export_range(1.0, 3600.0, 1.0) var temperature_cycle_duration := 240.0
@export_range(0.0, 0.5, 0.01) var temperature_thirst_bonus := 0.05

@export_category("Contenido")
@export var plaza := Vector2.ZERO
@export var path_routes: Array[PathRouteDefinition] = []
@export var houses: Array[HouseDefinition] = []
@export var animals: Array[AnimalDefinition] = []
@export var items: Array[ItemDefinition] = []
@export var crops: Array[CropDefinition] = []
@export var tools: Array[ToolDefinition] = []
@export var forest: ForestDefinition
@export var hotel: HotelDefinition
@export var repaired_house_interior: HotelDefinition
@export var mines: Array[MineDefinition] = []
@export var area_portals: Array[AreaPortalDefinition] = []
@export var npcs: Array[NpcDefinition] = []

@export_category("Jugador")
@export_range(1.0, 256.0, 1.0) var player_radius := 19.0
@export_range(0.0, 2048.0, 1.0) var player_walk_speed := 170.0
@export_range(0.0, 2048.0, 1.0) var player_run_speed := 270.0
@export_range(1.0, 2048.0, 1.0) var player_exhausted_speed := 60.0
@export var player_spawn := Vector2.ZERO
@export var default_tool_id: StringName = &"axe"
@export_range(1.0, 9999.0, 1.0) var player_max_health := 100.0
@export_range(1.0, 9999.0, 1.0) var player_max_stamina := 100.0
@export_range(1.0, 9999.0, 1.0) var player_max_stamina_cap := 200.0
@export_range(1.0, 9999.0, 1.0) var player_max_thirst := 100.0
@export_range(1.0, 9999.0, 1.0) var player_min_stamina_capacity := 20.0
@export_range(0.1, 9999.0, 0.1) var stamina_drain_rate := 12.0
@export_range(0.0, 999.0, 0.01) var stamina_capacity_drain_rate := 0.1
@export_range(0.1, 9999.0, 0.1) var stamina_recovery_rate := 20.0
@export_range(1.0, 999999.0, 1.0) var stamina_training_interval := 15.0
@export_range(0.0, 999.0, 0.01) var thirst_drain_rate := 0.05
@export_range(0, 999999, 1) var starting_coins := 100
@export_range(1.0, 999999.0, 1.0) var tree_seed_growth_time := 60.0

@export_category("Cámara")
@export_range(0.1, 100.0, 0.1) var camera_follow_strength := 7.2
@export var camera_zoom := Vector2(1.35, 1.35)


func world_size() -> Vector2:
	return Vector2(world_columns * tile_size, world_rows * tile_size)


func world_origin() -> Vector2:
	return Vector2(world_origin_cell) * tile_size


func last_world_cell_exclusive() -> Vector2i:
	return world_origin_cell + Vector2i(world_columns, world_rows)


func is_valid_cell(cell: Vector2i) -> bool:
	var last_cell := last_world_cell_exclusive()
	return (
		cell.x >= world_origin_cell.x
		and cell.y >= world_origin_cell.y
		and cell.x < last_cell.x
		and cell.y < last_cell.y
	)


func world_rect() -> Rect2:
	return Rect2(world_origin(), world_size())


func playable_bounds() -> Rect2:
	return world_rect().grow(-edge_padding)


func house_definitions() -> Array[HouseDefinition]:
	var definitions: Array[HouseDefinition] = []
	for resource in houses:
		if resource is HouseDefinition:
			definitions.append(resource)
	return definitions


func animal_definitions() -> Array[AnimalDefinition]:
	var definitions: Array[AnimalDefinition] = []
	for resource in animals:
		if resource is AnimalDefinition:
			definitions.append(resource)
	return definitions


func route_definitions() -> Array[PathRouteDefinition]:
	var definitions: Array[PathRouteDefinition] = []
	for resource in path_routes:
		if resource is PathRouteDefinition:
			definitions.append(resource)
	return definitions


func item_definitions() -> Array[ItemDefinition]:
	var definitions: Array[ItemDefinition] = []
	for resource in items:
		if resource is ItemDefinition:
			definitions.append(resource)
	return definitions


func crop_definitions() -> Array[CropDefinition]:
	var definitions: Array[CropDefinition] = []
	for resource in crops:
		if resource is CropDefinition:
			definitions.append(resource)
	return definitions


func tool_definitions() -> Array[ToolDefinition]:
	var definitions: Array[ToolDefinition] = []
	for resource in tools:
		if resource is ToolDefinition:
			definitions.append(resource)
	return definitions


func mine_definitions() -> Array[MineDefinition]:
	var definitions: Array[MineDefinition] = []
	for resource in mines:
		if resource is MineDefinition:
			definitions.append(resource)
	return definitions


func portal_definitions() -> Array[AreaPortalDefinition]:
	var definitions: Array[AreaPortalDefinition] = []
	for resource in area_portals:
		if resource is AreaPortalDefinition:
			definitions.append(resource)
	return definitions


func npc_definitions() -> Array[NpcDefinition]:
	var definitions: Array[NpcDefinition] = []
	for resource in npcs:
		if resource is NpcDefinition:
			definitions.append(resource)
	return definitions


func mine_for_area(area_id: StringName) -> MineDefinition:
	for mine in mine_definitions():
		if mine.area_id == area_id:
			return mine
	return null


func area_world_rect(area_id: StringName) -> Rect2:
	if area_id == OVERWORLD_AREA_ID:
		return world_rect()
	if hotel != null and area_id == hotel.area_id:
		return hotel.world_rect()
	if repaired_house_interior != null and area_id == repaired_house_interior.area_id:
		return repaired_house_interior.world_rect()
	var mine := mine_for_area(area_id)
	return mine.world_rect() if mine != null else Rect2()


func area_playable_bounds(area_id: StringName) -> Rect2:
	if area_id == OVERWORLD_AREA_ID:
		return playable_bounds()
	if hotel != null and area_id == hotel.area_id:
		return hotel.playable_bounds()
	if repaired_house_interior != null and area_id == repaired_house_interior.area_id:
		return repaired_house_interior.playable_bounds()
	var mine := mine_for_area(area_id)
	return mine.playable_bounds() if mine != null else Rect2()


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(_validate_world())
	errors.append_array(_validate_player_stats())
	errors.append_array(_validate_content_types())
	errors.append_array(_validate_houses())
	errors.append_array(_validate_animals())
	errors.append_array(_validate_routes())

	var item_ids: Dictionary = {}
	errors.append_array(_validate_items(item_ids))
	errors.append_array(_validate_crops(item_ids))
	errors.append_array(_validate_tools())
	errors.append_array(_validate_forest(item_ids))
	errors.append_array(_validate_hotel())
	errors.append_array(_validate_repaired_house_interior())
	errors.append_array(_validate_mines(item_ids))

	var known_area_ids := _known_area_ids()
	errors.append_array(_validate_npcs(known_area_ids))
	errors.append_array(_validate_portals(known_area_ids))
	errors.append_array(_validate_area_connectivity())
	return errors


func _validate_world() -> PackedStringArray:
	var errors := PackedStringArray()
	if world_columns <= 0 or world_rows <= 0 or tile_size <= 0.0:
		errors.append("Las dimensiones del mundo son inválidas.")
	if playable_bounds().size.x <= 0.0 or playable_bounds().size.y <= 0.0:
		errors.append("El margen del mundo deja un área jugable vacía.")
	if grass_texture == null:
		errors.append("Falta la textura del césped.")
	if path_texture == null:
		errors.append("Falta la textura del camino.")
	if not playable_bounds().has_point(player_spawn):
		errors.append("El jugador aparece fuera del área jugable.")
	if lake_size.x <= 0.0 or lake_size.y <= 0.0:
		errors.append("El lago debe tener un tamaño válido.")
	elif not playable_bounds().encloses(
		Rect2(lake_position - lake_size / 2.0, lake_size)
	):
		errors.append("El lago queda fuera del área jugable.")
	if tile_size > 0.0:
		var lake_origin := lake_position - lake_size / 2.0
		if (
			not is_equal_approx(lake_size.x / tile_size, roundf(lake_size.x / tile_size))
			or not is_equal_approx(lake_size.y / tile_size, roundf(lake_size.y / tile_size))
			or not is_equal_approx(lake_origin.x / tile_size, roundf(lake_origin.x / tile_size))
			or not is_equal_approx(lake_origin.y / tile_size, roundf(lake_origin.y / tile_size))
		):
			errors.append("El lago debe alinearse con la cuadricula del terreno.")
	if temperature_maximum < temperature_minimum:
		errors.append("La temperatura maxima no puede ser menor que la minima.")
	if temperature_cycle_duration <= 0.0:
		errors.append("El ciclo de temperatura debe ser positivo.")
	if temperature_thirst_bonus < 0.0:
		errors.append("El modificador de sed por temperatura no puede ser negativo.")
	if player_run_speed < player_walk_speed:
		errors.append("La velocidad al correr no puede ser menor que la de caminar.")
	if player_exhausted_speed >= player_walk_speed:
		errors.append(
			"La velocidad de agotamiento debe ser menor que la de caminar."
		)
	return errors


func _validate_player_stats() -> PackedStringArray:
	var errors := PackedStringArray()
	if player_max_health <= 0.0:
		errors.append("La salud máxima del jugador debe ser positiva.")
	if player_max_stamina <= 0.0:
		errors.append("La estamina máxima del jugador debe ser positiva.")
	if player_max_thirst <= 0.0:
		errors.append("La sed máxima del jugador debe ser positiva.")
	if (
		player_min_stamina_capacity <= 0.0
		or player_min_stamina_capacity > player_max_stamina
	):
		errors.append("La capacidad mínima de estamina no es válida.")
	if stamina_drain_rate <= 0.0:
		errors.append("El consumo de estamina debe ser positivo.")
	if stamina_capacity_drain_rate < 0.0:
		errors.append("El agotamiento de la capacidad de estamina no puede ser negativo.")
	if stamina_capacity_drain_rate >= stamina_drain_rate:
		errors.append("La capacidad de estamina debe agotarse más lentamente que la estamina.")
	if player_max_stamina_cap < player_max_stamina:
		errors.append("El límite de estamina máxima no puede ser menor que la inicial.")
	if stamina_training_interval <= 0.0:
		errors.append("El intervalo de entrenamiento de estamina debe ser positivo.")
	if stamina_recovery_rate <= 0.0:
		errors.append("La recuperación de estamina debe ser positiva.")
	if thirst_drain_rate < 0.0:
		errors.append("El consumo de sed no puede ser negativo.")
	if tree_seed_growth_time <= 0.0:
		errors.append("El tiempo de crecimiento de la semilla debe ser positivo.")
	return errors


func _validate_content_types() -> PackedStringArray:
	var errors := PackedStringArray()
	if house_definitions().size() != houses.size():
		errors.append("El catálogo contiene una definición de casa no válida.")
	if animal_definitions().size() != animals.size():
		errors.append("El catálogo contiene una definición de animal no válida.")
	if route_definitions().size() != path_routes.size():
		errors.append("El catálogo contiene una definición de ruta no válida.")
	if item_definitions().size() != items.size():
		errors.append("El catálogo contiene una definición de objeto no válida.")
	if crop_definitions().size() != crops.size():
		errors.append("El catálogo contiene una definición de cultivo no válida.")
	if tool_definitions().size() != tools.size():
		errors.append("El catálogo contiene una definición de herramienta no válida.")
	if mine_definitions().size() != mines.size():
		errors.append("El catálogo contiene una definición de mina no válida.")
	if portal_definitions().size() != area_portals.size():
		errors.append("El catálogo contiene una definición de portal no válida.")
	if npc_definitions().size() != npcs.size():
		errors.append("El catálogo contiene una definición de NPC no válida.")
	return errors


func _validate_houses() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	for house in house_definitions():
		errors.append_array(house.validate())
		if seen_ids.has(house.id):
			errors.append("El id de casa '%s' está duplicado." % house.id)
		seen_ids[house.id] = true
	return errors


func _validate_animals() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	for animal in animal_definitions():
		errors.append_array(animal.validate())
		if seen_ids.has(animal.id):
			errors.append("El id de animal '%s' está duplicado." % animal.id)
		seen_ids[animal.id] = true
	return errors


func _validate_routes() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	for route in route_definitions():
		errors.append_array(route.validate())
		if seen_ids.has(route.id):
			errors.append("El id de ruta '%s' está duplicado." % route.id)
		seen_ids[route.id] = true
	return errors


func _validate_items(item_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for item in item_definitions():
		errors.append_array(item.validate())
		if item_ids.has(item.id):
			errors.append("El id de objeto '%s' está duplicado." % item.id)
		item_ids[item.id] = true
	return errors


func _validate_crops(item_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	var seen_seed_ids: Dictionary = {}
	for crop in crop_definitions():
		errors.append_array(crop.validate())
		if seen_ids.has(crop.id):
			errors.append("El id de cultivo '%s' está duplicado." % crop.id)
		seen_ids[crop.id] = true
		if seen_seed_ids.has(crop.seed_id):
			errors.append("La semilla '%s' está asignada a más de un cultivo." % crop.seed_id)
		seen_seed_ids[crop.seed_id] = true
		if not item_ids.has(crop.seed_id):
			errors.append(
				"El cultivo '%s' usa una semilla que no está registrada en el catálogo."
				% crop.id
			)
	return errors


func _validate_tools() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	for tool in tool_definitions():
		errors.append_array(tool.validate())
		if seen_ids.has(tool.id):
			errors.append("El id de herramienta '%s' está duplicado." % tool.id)
		seen_ids[tool.id] = true

	if not seen_ids.has(default_tool_id):
		errors.append(
			"La herramienta predeterminada '%s' no está registrada en el catálogo."
			% default_tool_id
		)
	return errors


func _validate_forest(item_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if forest == null:
		errors.append("El catálogo no tiene una definición de bosque.")
		return errors

	errors.append_array(forest.validate())
	if forest.apple_item != null and not item_ids.has(forest.apple_item.id):
		errors.append(
		"La manzana del bosque no está registrada en el catálogo de objetos."
	)
	for tree in forest.tree_definitions():
		if tree.yielded_item != null and not item_ids.has(tree.yielded_item.id):
			errors.append(
				"El árbol '%s' entrega un objeto que no está registrado en el catálogo."
				% tree.id
			)
	return errors


func _validate_hotel() -> PackedStringArray:
	var errors := PackedStringArray()
	if hotel == null:
		errors.append("El catálogo no tiene una definición de hotel.")
		return errors
	errors.append_array(hotel.validate())
	return errors


func _validate_repaired_house_interior() -> PackedStringArray:
	var errors := PackedStringArray()
	if repaired_house_interior == null:
		errors.append("El catÃ¡logo no tiene una definiciÃ³n para la casa reparada.")
		return errors
	errors.append_array(repaired_house_interior.validate())
	return errors


func _validate_mines(item_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if mine_definitions().is_empty():
		errors.append("El catálogo no tiene ninguna definición de mina.")
		return errors

	var seen_ids: Dictionary = {}
	var seen_area_ids: Dictionary = {OVERWORLD_AREA_ID: true}
	if hotel != null:
		seen_area_ids[hotel.area_id] = true
	if repaired_house_interior != null:
		seen_area_ids[repaired_house_interior.area_id] = true
	for mine in mine_definitions():
		errors.append_array(mine.validate())
		if seen_ids.has(mine.id):
			errors.append("El id de mina '%s' está duplicado." % mine.id)
		seen_ids[mine.id] = true
		if seen_area_ids.has(mine.area_id):
			errors.append("El id de área '%s' está duplicado." % mine.area_id)
		seen_area_ids[mine.area_id] = true

		for mineral in mine.mineral_definitions():
			if (
				mineral.yielded_item != null
				and not item_ids.has(mineral.yielded_item.id)
			):
				errors.append(
					"El mineral '%s' de la mina '%s' entrega un objeto no registrado."
					% [mineral.id, mine.id]
				)
	return errors


func _known_area_ids() -> Dictionary:
	var area_ids: Dictionary = {OVERWORLD_AREA_ID: true}
	if hotel != null and not String(hotel.area_id).is_empty():
		area_ids[hotel.area_id] = true
	if (
		repaired_house_interior != null
		and not String(repaired_house_interior.area_id).is_empty()
	):
		area_ids[repaired_house_interior.area_id] = true
	for mine in mine_definitions():
		if not String(mine.area_id).is_empty():
			area_ids[mine.area_id] = true
	return area_ids


func _validate_npcs(known_area_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	for npc in npc_definitions():
		errors.append_array(npc.validate())
		if seen_ids.has(npc.id):
			errors.append("El id de NPC '%s' está duplicado." % npc.id)
		seen_ids[npc.id] = true

		if not known_area_ids.has(npc.area_id):
			errors.append(
				"El NPC '%s' pertenece a un área no registrada." % npc.id
			)
		elif not area_playable_bounds(npc.area_id).has_point(npc.world_position):
			errors.append(
				"El NPC '%s' queda fuera del área jugable." % npc.id
			)
	return errors


func _validate_portals(known_area_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	for portal in portal_definitions():
		errors.append_array(portal.validate())
		if seen_ids.has(portal.id):
			errors.append("El id de portal '%s' está duplicado." % portal.id)
		seen_ids[portal.id] = true

		if not known_area_ids.has(portal.source_area_id):
			errors.append(
				"El portal '%s' parte de un área no registrada." % portal.id
			)
		elif not area_world_rect(portal.source_area_id).has_point(portal.world_position):
			errors.append("El portal '%s' está fuera de su área de origen." % portal.id)

		if not known_area_ids.has(portal.target_area_id):
			errors.append(
				"El portal '%s' apunta a un área no registrada." % portal.id
			)
		elif not area_playable_bounds(portal.target_area_id).has_point(portal.target_position):
			errors.append(
				"El destino del portal '%s' queda fuera del área jugable." % portal.id
			)
	return errors


func _validate_area_connectivity() -> PackedStringArray:
	var errors := PackedStringArray()
	var portals := portal_definitions()
	for mine in mine_definitions():
		if not _can_reach_area(OVERWORLD_AREA_ID, mine.area_id, portals):
			errors.append(
				"No existe una ruta de portales desde la aldea hasta '%s'."
				% mine.label
			)
		if not _can_reach_area(mine.area_id, OVERWORLD_AREA_ID, portals):
			errors.append(
				"No existe una ruta de regreso desde '%s' hasta la aldea."
				% mine.label
			)
	if hotel != null:
		if not _can_reach_area(OVERWORLD_AREA_ID, hotel.area_id, portals):
			errors.append(
				"No existe una ruta de portales desde la aldea hasta '%s'."
				% hotel.label
			)
		if not _can_reach_area(hotel.area_id, OVERWORLD_AREA_ID, portals):
			errors.append(
				"No existe una ruta de regreso desde '%s' hasta la aldea."
				% hotel.label
			)
	if repaired_house_interior != null:
		if not _can_reach_area(
			repaired_house_interior.area_id,
			OVERWORLD_AREA_ID,
			portals
		):
			errors.append(
			"No existe una ruta de regreso desde '%s' hasta la aldea."
			% repaired_house_interior.label
		)
	return errors


func _can_reach_area(
	start_area_id: StringName,
	target_area_id: StringName,
	portals: Array[AreaPortalDefinition]
) -> bool:
	if start_area_id == target_area_id:
		return true

	var pending: Array[StringName] = [start_area_id]
	var visited: Dictionary = {start_area_id: true}
	var cursor := 0
	while cursor < pending.size():
		var current_area_id := pending[cursor]
		cursor += 1
		for portal in portals:
			if portal.source_area_id != current_area_id:
				continue
			if portal.target_area_id == target_area_id:
				return true
			if visited.has(portal.target_area_id):
				continue
			visited[portal.target_area_id] = true
			pending.append(portal.target_area_id)
	return false
