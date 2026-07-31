extends RefCounted
class_name DialogueChoice

var id: StringName = &""
var text := ""
var target_node_id: StringName = &""


func configure(
	choice_id: StringName,
	choice_text: String,
	next_node_id: StringName
) -> DialogueChoice:
	id = choice_id
	text = choice_text
	target_node_id = next_node_id
	return self


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Una elección de diálogo no tiene id.")
	if text.strip_edges().is_empty():
		errors.append("La elección '%s' no tiene texto." % id)
	if String(target_node_id).is_empty():
		errors.append("La elección '%s' no tiene nodo de destino." % id)
	return errors
