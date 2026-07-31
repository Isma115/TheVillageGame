extends Node
class_name InteractionSystem

signal prompt_changed(label: String, available: bool)

const SPATIAL_CELL_SIZE := 128.0

@export_range(16.0, 1024.0, 1.0) var maximum_query_distance := 128.0
@export_range(0.01, 1.0, 0.01) var refresh_interval := 0.08

var _source: Node2D
var _input_state: InputState
var _entries: Dictionary = {}
var _buckets: Dictionary = {}
var _current: InteractableActor
var _refresh_elapsed := 0.0
var _last_prompt := ""
var _last_prompt_available := false
var _active_area_id: StringName = &"overworld"
var _enabled := true


func initialize(source: Node2D, controls: InputState) -> void:
	_source = source
	_input_state = controls
	_enabled = true
	_refresh_elapsed = refresh_interval
	_refresh_target()


func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	_refresh_elapsed = refresh_interval
	if _enabled:
		_refresh_target()
	else:
		_set_current(null)


func is_enabled() -> bool:
	return _enabled


func set_active_area(area_id: StringName) -> void:
	if String(area_id).is_empty():
		return

	_active_area_id = area_id
	_refresh_elapsed = refresh_interval
	_set_current(null)
	_refresh_target()


func active_area_id() -> StringName:
	return _active_area_id


func update_interactions(delta: float) -> void:
	if not _enabled or _source == null or _input_state == null:
		return

	_refresh_elapsed += delta
	if _refresh_elapsed >= refresh_interval or not _is_current_valid():
		_refresh_elapsed = 0.0
		_refresh_target()

	if not _input_state.consume_interaction_request():
		return

	if _is_current_valid():
		_current.interact(_source)
		_refresh_target()


func register_interactable(target: InteractableActor) -> void:
	if target == null:
		return

	var instance_id := target.get_instance_id()
	if _entries.has(instance_id):
		refresh_interactable(target)
		return

	var cell := _cell_for(target.interaction_anchor())
	var entry := InteractionEntry.new()
	entry.configure(target, cell)
	_entries[instance_id] = entry
	_add_to_bucket(cell, instance_id)
	target.tree_exiting.connect(
		_on_interactable_tree_exiting.bind(instance_id),
		CONNECT_ONE_SHOT
	)
	_refresh_elapsed = refresh_interval


func unregister_interactable(target: InteractableActor) -> void:
	if target != null:
		_unregister_by_id(target.get_instance_id())


func refresh_interactable(target: InteractableActor) -> void:
	if target == null:
		return

	var instance_id := target.get_instance_id()
	if not _entries.has(instance_id):
		register_interactable(target)
		return

	var entry := _entries[instance_id] as InteractionEntry
	if entry == null:
		_unregister_by_id(instance_id)
		register_interactable(target)
		return

	var previous_cell := entry.cell
	var next_cell := _cell_for(target.interaction_anchor())
	if previous_cell == next_cell:
		return

	_remove_from_bucket(previous_cell, instance_id)
	entry.cell = next_cell
	_add_to_bucket(next_cell, instance_id)


func registered_count(area_id: StringName = &"") -> int:
	if String(area_id).is_empty():
		return _entries.size()

	var count := 0
	for instance_id in _entries.keys():
		var target := _resolve_entry(int(instance_id))
		if target != null and target.interaction_area_id() == area_id:
			count += 1
	return count


func _refresh_target() -> void:
	_set_current(_find_best_candidate())


func _find_best_candidate() -> InteractableActor:
	if not _enabled or _source == null:
		return null

	var origin := _source.global_position
	var origin_cell := _cell_for(origin)
	var cell_radius := maxi(1, ceili(maximum_query_distance / SPATIAL_CELL_SIZE))
	var best: InteractableActor
	var best_priority := -2147483648
	var best_distance := INF

	for offset_y in range(-cell_radius, cell_radius + 1):
		for offset_x in range(-cell_radius, cell_radius + 1):
			var cell := origin_cell + Vector2i(offset_x, offset_y)
			var instance_ids: Array = _buckets.get(cell, [])
			for instance_id in instance_ids:
				var candidate := _resolve_entry(int(instance_id))
				if (
					candidate == null
					or candidate.interaction_area_id() != _active_area_id
					or not candidate.can_interact(_source)
				):
					continue

				var distance := origin.distance_to(candidate.interaction_anchor())
				if distance > minf(maximum_query_distance, candidate.interaction_distance()):
					continue

				var priority := candidate.interaction_priority()
				if priority > best_priority or (priority == best_priority and distance < best_distance):
					best = candidate
					best_priority = priority
					best_distance = distance

	return best


func _resolve_entry(instance_id: int) -> InteractableActor:
	var entry := _entries.get(instance_id) as InteractionEntry
	if entry == null:
		return null

	var target := entry.target()
	if target != null:
		return target

	_unregister_by_id(instance_id)
	return null


func _set_current(next: InteractableActor) -> void:
	if next == _current:
		_emit_prompt_for_current()
		return

	if is_instance_valid(_current):
		_current.set_interaction_focused(false)

	_current = next
	if is_instance_valid(_current):
		_current.set_interaction_focused(true)
	_emit_prompt_for_current()


func _emit_prompt_for_current() -> void:
	var available := _is_current_valid()
	var label := _current.interaction_label() if available else ""
	if label == _last_prompt and available == _last_prompt_available:
		return

	_last_prompt = label
	_last_prompt_available = available
	prompt_changed.emit(label, available)


func _is_current_valid() -> bool:
	return (
		_enabled
		and
		is_instance_valid(_current)
		and _source != null
		and _current.interaction_area_id() == _active_area_id
		and _current.can_interact(_source)
		and _source.global_position.distance_to(_current.interaction_anchor())
		<= minf(maximum_query_distance, _current.interaction_distance())
	)


func _cell_for(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / SPATIAL_CELL_SIZE),
		floori(world_position.y / SPATIAL_CELL_SIZE)
	)


func _add_to_bucket(cell: Vector2i, instance_id: int) -> void:
	var bucket: Array = _buckets.get(cell, [])
	bucket.append(instance_id)
	_buckets[cell] = bucket


func _remove_from_bucket(cell: Vector2i, instance_id: int) -> void:
	var bucket: Array = _buckets.get(cell, [])
	bucket.erase(instance_id)
	if bucket.is_empty():
		_buckets.erase(cell)
	else:
		_buckets[cell] = bucket


func _unregister_by_id(instance_id: int) -> void:
	if not _entries.has(instance_id):
		return

	var entry := _entries[instance_id] as InteractionEntry
	if entry != null:
		_remove_from_bucket(entry.cell, instance_id)
	_entries.erase(instance_id)

	if is_instance_valid(_current) and _current.get_instance_id() == instance_id:
		_set_current(null)


func _on_interactable_tree_exiting(instance_id: int) -> void:
	_unregister_by_id(instance_id)
