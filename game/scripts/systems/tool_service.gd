extends RefCounted
class_name ToolService

signal tool_changed(tool: ToolDefinition, durability: int)

var _definitions: Dictionary = {}
var _durabilities: Dictionary = {}
var _owned: Dictionary = {}
var _equipped_tool_id: StringName = &""
var _default_tool_id: StringName = &""


func initialize(
	definitions: Array[ToolDefinition],
	default_tool_id: StringName
) -> void:
	_definitions.clear()
	_durabilities.clear()
	_owned.clear()
	_equipped_tool_id = &""
	_default_tool_id = default_tool_id

	for definition in definitions:
		if definition == null:
			continue
		_definitions[definition.id] = definition
		_durabilities[definition.id] = 0
		_owned[definition.id] = false

	if _definitions.has(default_tool_id):
		_owned[default_tool_id] = true
		_durabilities[default_tool_id] = (
			_definitions[default_tool_id] as ToolDefinition
		).initial_durability()
		_equipped_tool_id = default_tool_id
	elif not _definitions.is_empty():
		var first_tool_id: StringName = _definitions.keys()[0]
		_owned[first_tool_id] = true
		_durabilities[first_tool_id] = (
			_definitions[first_tool_id] as ToolDefinition
		).initial_durability()
		_equipped_tool_id = first_tool_id


func tool_definitions() -> Array[ToolDefinition]:
	var result: Array[ToolDefinition] = []
	for value in _definitions.values():
		var definition := value as ToolDefinition
		if definition != null:
			result.append(definition)
	return result


func equipped_tool() -> ToolDefinition:
	return _definitions.get(_equipped_tool_id) as ToolDefinition


func equipped_tool_id() -> StringName:
	return _equipped_tool_id


func tool_for(tool_id: StringName) -> ToolDefinition:
	return _definitions.get(tool_id) as ToolDefinition


func has_tool(tool_id: StringName) -> bool:
	return bool(_owned.get(tool_id, false))


func can_acquire_tool(tool_id: StringName) -> bool:
	var definition := _definitions.get(tool_id) as ToolDefinition
	return (
		definition != null
		and (not has_tool(tool_id) or durability_of(tool_id) <= 0)
	)


func acquire_tool(tool_id: StringName) -> bool:
	var definition := _definitions.get(tool_id) as ToolDefinition
	if definition == null or not can_acquire_tool(tool_id):
		return false

	_owned[tool_id] = true
	_durabilities[tool_id] = definition.initial_durability()
	_equipped_tool_id = tool_id
	_emit_tool_changed(tool_id)
	return true


func equip_tool(tool_id: StringName) -> bool:
	if not _definitions.has(tool_id) or not has_tool(tool_id):
		return false
	_equipped_tool_id = tool_id
	_emit_tool_changed(tool_id)
	return true


func equip_tool_slot(slot_index: int) -> bool:
	if slot_index < 0:
		return false

	var current_index := 0
	for value in _definitions.values():
		var definition := value as ToolDefinition
		if definition == null:
			continue
		if current_index == slot_index:
			return equip_tool(definition.id)
		current_index += 1
	return false


func durability_of(tool_id: StringName) -> int:
	return int(_durabilities.get(tool_id, 0))


func durability_ratio_of(tool_id: StringName) -> float:
	var definition := _definitions.get(tool_id) as ToolDefinition
	if definition == null or definition.maximum_durability <= 0:
		return 0.0
	return clampf(
		float(durability_of(tool_id)) / float(definition.maximum_durability),
		0.0,
		1.0
	)


func can_use_capability(capability: StringName) -> bool:
	return can_use_tool_capability(_equipped_tool_id, capability)


func can_use_tool_capability(tool_id: StringName, capability: StringName) -> bool:
	var tool := tool_for(tool_id)
	return (
		tool != null
		and has_tool(tool.id)
		and tool.supports(capability)
		and durability_of(tool.id) >= tool.durability_cost
	)


func try_use_capability(capability: StringName) -> ToolDefinition:
	return try_use_tool_capability(_equipped_tool_id, capability)


func try_use_tool_capability(
	tool_id: StringName,
	capability: StringName
) -> ToolDefinition:
	var tool := tool_for(tool_id)
	if (
		tool == null
		or not has_tool(tool.id)
		or not tool.supports(capability)
		or durability_of(tool.id) < tool.durability_cost
	):
		return null

	if not consume_durability(tool.id, tool.durability_cost):
		return null
	return tool


func consume_durability(tool_id: StringName, amount: int) -> bool:
	if amount <= 0 or not _definitions.has(tool_id):
		return false

	var current := durability_of(tool_id)
	if current < amount:
		return false

	_durabilities[tool_id] = current - amount
	_emit_tool_changed(tool_id)
	return true


func set_durability(tool_id: StringName, value: int) -> bool:
	var definition := _definitions.get(tool_id) as ToolDefinition
	if definition == null:
		return false

	_durabilities[tool_id] = clampi(value, 0, definition.maximum_durability)
	if value > 0:
		_owned[tool_id] = true
	_emit_tool_changed(tool_id)
	return true


func snapshot() -> Dictionary:
	var durability := {}
	var owned := {}
	for tool_id in _definitions:
		durability[String(tool_id)] = durability_of(tool_id)
		owned[String(tool_id)] = has_tool(tool_id)
	return {
		"equipped": String(_equipped_tool_id),
		"durability": durability,
		"owned": owned
	}


func restore(snapshot_data: Dictionary) -> void:
	var saved_durability: Variant = snapshot_data.get("durability", {})
	var durability_data := (
		saved_durability as Dictionary
		if saved_durability is Dictionary
		else {}
	)
	var saved_owned: Variant = snapshot_data.get("owned", {})
	var owned_data := saved_owned as Dictionary if saved_owned is Dictionary else {}
	for tool_id in _definitions:
		var key := String(tool_id)
		var has_saved_durability := (
			durability_data.has(key) or durability_data.has(tool_id)
		)
		var definition := _definitions[tool_id] as ToolDefinition
		if has_saved_durability:
			var saved_value: Variant = durability_data.get(
				key,
				durability_data.get(tool_id, durability_of(tool_id))
			)
			_durabilities[tool_id] = clampi(
				int(saved_value),
				0,
				definition.maximum_durability
			)

		if not owned_data.is_empty():
			_owned[tool_id] = bool(owned_data.get(key, owned_data.get(tool_id, false)))
		elif has_saved_durability:
			# Compatibilidad con las partidas creadas antes de persistir la propiedad.
			_owned[tool_id] = true


	var saved_equipped := StringName(str(snapshot_data.get("equipped", "")))
	if _definitions.has(saved_equipped) and has_tool(saved_equipped):
		_equipped_tool_id = saved_equipped
	elif has_tool(_default_tool_id):
		_equipped_tool_id = _default_tool_id
	else:
		_equipped_tool_id = &""
		for tool_id in _definitions:
			if has_tool(tool_id):
				_equipped_tool_id = tool_id
				break

	_emit_tool_changed(_equipped_tool_id)


func _emit_tool_changed(tool_id: StringName) -> void:
	var definition := _definitions.get(tool_id) as ToolDefinition
	if definition != null and tool_id == _equipped_tool_id:
		tool_changed.emit(definition, durability_of(tool_id))
