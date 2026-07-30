extends Resource
class_name GameCatalog

const OVERWORLD_AREA_ID: StringName = &"overworld"

@export_category("Mundo")
@export_range(1, 4096, 1) var world_columns := 35
@export_range(1, 4096, 1) var world_rows := 35
@export_range(1.0, 1024.0, 1.0) var tile_size := 48.0
@export_range(0.0, 4096.0, 1.0) var edge_padding := 54.0
@export var grass_color := Color("#5d934f")
@export var ink_color := Color("#193724")
@export var grass_texture: Texture2D
@export var path_texture: Texture2D

@export_category("Contenido")
@export var plaza := Vector2.ZERO
@export var path_routes: Array[PathRouteDefinition] = []
@export var houses: Array[HouseDefinition] = []
@export var animals: Array[AnimalDefinition] = []
@export var items: Array[ItemDefinition] = []
@export var forest: ForestDefinition
@export var mines: Array[MineDefinition] = []
@export var area_portals: Array[AreaPortalDefinition] = []

@export_category("Jugador")
@export_range(1.0, 256.0, 1.0) var player_radius := 19.0
@export_range(0.0, 2048.0, 1.0) var player_walk_speed := 170.0
@export_range(0.0, 2048.0, 1.0) var player_run_speed := 270.0
@export var player_spawn := Vector2.ZERO

@export_category("Cámara")
@export_range(0.1, 100.0, 0.1) var camera_follow_strength := 7.2
@export var camera_zoom := Vector2(1.35, 1.35)


func world_size() -> Vector2:
	return Vector2(world_columns * tile_size, world_rows * tile_size)


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, world_size())


func playable_bounds() -> Rect2:
	var inset := Vector2(edge_padding, edge_padding)
	return Rect2(inset, world_size() - inset * 2.0)


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


func mine_for_area(area_id: StringName) -> MineDefinition:
	for mine in mine_definitions():
		if mine.area_id == area_id:
			return mine
	return null


func area_world_rect(area_id: StringName) -> Rect2:
	if area_id == OVERWORLD_AREA_ID:
		return world_rect()
	var mine := mine_for_area(area_id)
	return mine.world_rect() if mine != null else Rect2()


func area_playable_bounds(area_id: StringName) -> Rect2:
	if area_id == OVERWORLD_AREA_ID:
		return playable_bounds()
	var mine := mine_for_area(area_id)
	return mine.playable_bounds() if mine != null else Rect2()


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(_validate_world())
	errors.append_array(_validate_content_types())
	errors.append_array(_validate_houses())
	errors.append_array(_validate_animals())
	errors.append_array(_validate_routes())

	var item_ids: Dictionary = {}
	errors.append_array(_validate_items(item_ids))
	errors.append_array(_validate_forest(item_ids))
	errors.append_array(_validate_mines(item_ids))

	var known_area_ids := _known_area_ids()
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
	if player_run_speed < player_walk_speed:
		errors.append("La velocidad al correr no puede ser menor que la de caminar.")
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
	if mine_definitions().size() != mines.size():
		errors.append("El catálogo contiene una definición de mina no válida.")
	if portal_definitions().size() != area_portals.size():
		errors.append("El catálogo contiene una definición de portal no válida.")
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


func _validate_forest(item_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if forest == null:
		errors.append("El catálogo no tiene una definición de bosque.")
		return errors

	errors.append_array(forest.validate())
	for tree in forest.tree_definitions():
		if tree.yielded_item != null and not item_ids.has(tree.yielded_item.id):
			errors.append(
				"El árbol '%s' entrega un objeto que no está registrado en el catálogo."
				% tree.id
			)
	return errors


func _validate_mines(item_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if mine_definitions().is_empty():
		errors.append("El catálogo no tiene ninguna definición de mina.")
		return errors

	var seen_ids: Dictionary = {}
	var seen_area_ids: Dictionary = {OVERWORLD_AREA_ID: true}
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
	for mine in mine_definitions():
		if not String(mine.area_id).is_empty():
			area_ids[mine.area_id] = true
	return area_ids


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
