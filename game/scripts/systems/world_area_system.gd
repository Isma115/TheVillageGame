extends Node
class_name WorldAreaSystem

signal area_changed(area_id: StringName, label: String)

@export var portal_scene: PackedScene

var _areas: Dictionary = {}
var _portals: Array[AreaPortalActor] = []
var _player: PlayerActor
var _interaction_system: InteractionSystem
var _active_area_id: StringName = &""


func initialize(player: PlayerActor, interaction_system: InteractionSystem) -> void:
	_clear_portals()
	for value in _areas.values():
		var runtime := value as WorldAreaRuntime
		if runtime != null:
			runtime.set_active(false)
	_areas.clear()
	_active_area_id = &""
	_player = player
	_interaction_system = interaction_system


func register_area(
	area_id: StringName,
	label: String,
	area_root: Node2D,
	actor_layer: Node2D,
	collision_world: CollisionWorld,
	camera_bounds: Rect2
) -> WorldAreaRuntime:
	var runtime := WorldAreaRuntime.new()
	if not runtime.configure(
		area_id,
		label,
		area_root,
		actor_layer,
		collision_world,
		camera_bounds
	):
		push_error("No se puede registrar un área con datos incompletos.")
		return null
	if not register_runtime(runtime):
		return null
	return runtime


func register_runtime(runtime: WorldAreaRuntime) -> bool:
	if runtime == null or not runtime.is_valid():
		push_error("No se puede registrar un runtime de área inválido.")
		return false
	if _areas.has(runtime.id):
		push_error("El área '%s' ya está registrada." % runtime.id)
		return false

	runtime.set_active(false)
	_areas[runtime.id] = runtime
	return true


func area_runtime(area_id: StringName) -> WorldAreaRuntime:
	return _areas.get(area_id) as WorldAreaRuntime


func register_portals(definitions: Array[AreaPortalDefinition]) -> bool:
	if portal_scene == null:
		push_error("WorldAreaSystem necesita una escena de portal.")
		return false
	if _interaction_system == null:
		push_error("WorldAreaSystem no tiene un sistema de interacción.")
		return false

	var success := true
	for definition in definitions:
		if definition == null:
			push_error("No se puede crear un portal sin definición.")
			success = false
			continue

		var runtime := area_runtime(definition.source_area_id)
		if runtime == null:
			push_error(
				"No se puede crear el portal '%s': falta el área '%s'."
				% [definition.id, definition.source_area_id]
			)
			success = false
			continue

		var portal := portal_scene.instantiate() as AreaPortalActor
		if portal == null:
			push_error("La escena de portal no crea un AreaPortalActor.")
			return false

		portal.configure(definition)
		runtime.actor_layer.add_child(portal)
		portal.interaction_requested.connect(_on_portal_interaction_requested)
		_interaction_system.register_interactable(portal)
		if definition.has_collision():
			runtime.collision_world.register_obstacle(
				portal.collision_key(),
				portal.collision_rectangle()
			)
		_portals.append(portal)
	return success


func activate_initial_area(area_id: StringName, spawn_position: Vector2) -> bool:
	return transition_to(area_id, spawn_position)


func transition_to(area_id: StringName, spawn_position: Vector2) -> bool:
	var runtime := area_runtime(area_id)
	if runtime == null or _player == null or _interaction_system == null:
		push_error("No se puede entrar en el área '%s'." % area_id)
		return false

	var previous_runtime := area_runtime(_active_area_id)
	if previous_runtime != null and previous_runtime != runtime:
		previous_runtime.set_active(false)

	runtime.set_active(true)
	if _player.get_parent() != runtime.actor_layer:
		_player.reparent(runtime.actor_layer, false)
	_player.set_world_context(
		runtime.collision_world,
		runtime.camera_bounds,
		spawn_position
	)
	_interaction_system.set_active_area(area_id)
	_active_area_id = area_id
	area_changed.emit(area_id, runtime.label)
	return true


func active_area_id() -> StringName:
	return _active_area_id


func is_area_active(area_id: StringName) -> bool:
	return _active_area_id == area_id


func area_count() -> int:
	return _areas.size()


func area_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for area_id in _areas.keys():
		result.append(StringName(area_id))
	return result


func portal_count(area_id: StringName = &"") -> int:
	if String(area_id).is_empty():
		return _portals.size()

	var count := 0
	for portal in _portals:
		if is_instance_valid(portal) and portal.definition.source_area_id == area_id:
			count += 1
	return count


func portal_collision_count(area_id: StringName) -> int:
	var count := 0
	for portal in _portals:
		if (
			is_instance_valid(portal)
			and portal.definition.source_area_id == area_id
			and portal.definition.has_collision()
		):
			count += 1
	return count


func portal_actors(area_id: StringName = &"") -> Array[AreaPortalActor]:
	var result: Array[AreaPortalActor] = []
	for portal in _portals:
		if (
			is_instance_valid(portal)
			and (
				String(area_id).is_empty()
				or portal.definition.source_area_id == area_id
			)
		):
			result.append(portal)
	return result


func _on_portal_interaction_requested(target: Node2D, _source: Node2D) -> void:
	var portal := target as AreaPortalActor
	if portal == null or portal.definition == null:
		return
	transition_to(
		portal.definition.target_area_id,
		portal.definition.target_position
	)


func _clear_portals() -> void:
	for portal in _portals:
		if not is_instance_valid(portal):
			continue
		if _interaction_system != null:
			_interaction_system.unregister_interactable(portal)
		if portal.definition != null:
			var runtime := area_runtime(portal.definition.source_area_id)
			if runtime != null:
				runtime.collision_world.unregister_obstacle(portal.collision_key())
		portal.queue_free()
	_portals.clear()
