extends RefCounted
class_name DialogueNode

var id: StringName = &""
var text := ""
var choices: Array[DialogueChoice] = []


func configure(
	node_id: StringName,
	node_text: String,
	node_choices: Array[DialogueChoice] = []
) -> DialogueNode:
	id = node_id
	text = node_text
	choices.assign(node_choices)
	return self


func is_terminal() -> bool:
	return choices.is_empty()


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un nodo de diálogo no tiene id.")
	if text.strip_edges().is_empty():
		errors.append("El nodo de diálogo '%s' no tiene texto." % id)
	if choices.size() > 4:
		errors.append(
			"El nodo de diálogo '%s' supera las cuatro respuestas visibles." % id
		)
	for choice in choices:
		if choice == null:
			errors.append("El nodo de diálogo '%s' contiene una elección nula." % id)
		else:
			errors.append_array(choice.validate())
	return errors
