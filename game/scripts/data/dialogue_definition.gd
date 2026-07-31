extends Resource
class_name DialogueDefinition

var id: StringName = &"dialogue"
var speaker_name := "NPC"
var speaker_title := ""
var start_node_id: StringName = &"start"
var _nodes: Dictionary = {}


func add_node(node: DialogueNode) -> void:
	if node != null and not String(node.id).is_empty():
		_nodes[node.id] = node


func clear_nodes() -> void:
	_nodes.clear()


func node_for(node_id: StringName) -> DialogueNode:
	return _nodes.get(node_id) as DialogueNode


func nodes() -> Array[DialogueNode]:
	var result: Array[DialogueNode] = []
	for value in _nodes.values():
		var node := value as DialogueNode
		if node != null:
			result.append(node)
	return result


func node_count() -> int:
	return _nodes.size()


func choice_count() -> int:
	var total := 0
	for node in nodes():
		total += node.choices.size()
	return total


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un diálogo no tiene id.")
	if speaker_name.strip_edges().is_empty():
		errors.append("El diálogo '%s' no tiene interlocutor." % id)
	if _nodes.is_empty():
		errors.append("El diálogo '%s' no contiene nodos." % id)
		return errors
	if node_for(start_node_id) == null:
		errors.append(
			"El diálogo '%s' no contiene su nodo inicial '%s'."
			% [id, start_node_id]
		)

	var seen_choice_ids: Dictionary = {}
	var seen_choice_texts: Dictionary = {}
	var terminal_ids: Dictionary = {}
	for node in nodes():
		errors.append_array(node.validate())
		if node.is_terminal():
			terminal_ids[node.id] = true
		for choice in node.choices:
			if choice == null:
				continue
			if seen_choice_ids.has(choice.id):
				errors.append(
					"El diálogo '%s' repite la elección '%s'." % [id, choice.id]
				)
			seen_choice_ids[choice.id] = true

			var normalized_text := choice.text.strip_edges().to_lower()
			if seen_choice_texts.has(normalized_text):
				errors.append(
					"El diálogo '%s' repite el texto de elección '%s'."
					% [id, choice.text]
				)
			seen_choice_texts[normalized_text] = true

			if node_for(choice.target_node_id) == null:
				errors.append(
					"La elección '%s' apunta al nodo inexistente '%s'."
					% [choice.id, choice.target_node_id]
				)

	if terminal_ids.is_empty():
		errors.append("El diálogo '%s' no tiene ningún desenlace." % id)
		return errors

	errors.append_array(_validate_reachability())
	errors.append_array(_validate_paths_to_end(terminal_ids))
	return errors


func _validate_reachability() -> PackedStringArray:
	var errors := PackedStringArray()
	if node_for(start_node_id) == null:
		return errors

	var visited: Dictionary = {start_node_id: true}
	var pending: Array[StringName] = [start_node_id]
	var cursor := 0
	while cursor < pending.size():
		var current := node_for(pending[cursor])
		cursor += 1
		if current == null:
			continue
		for choice in current.choices:
			if (
				choice == null
				or visited.has(choice.target_node_id)
				or node_for(choice.target_node_id) == null
			):
				continue
			visited[choice.target_node_id] = true
			pending.append(choice.target_node_id)

	for node in nodes():
		if not visited.has(node.id):
			errors.append(
				"El nodo '%s' del diálogo '%s' no es alcanzable."
				% [node.id, id]
			)
	return errors


func _validate_paths_to_end(terminal_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var can_reach_end := terminal_ids.duplicate()
	var changed := true
	while changed:
		changed = false
		for node in nodes():
			if can_reach_end.has(node.id):
				continue
			for choice in node.choices:
				if choice != null and can_reach_end.has(choice.target_node_id):
					can_reach_end[node.id] = true
					changed = true
					break

	for node in nodes():
		if not can_reach_end.has(node.id):
			errors.append(
				"El nodo '%s' del diálogo '%s' no puede llegar a un desenlace."
				% [node.id, id]
			)
	return errors
