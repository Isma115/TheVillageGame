extends Resource
class_name NpcActionDefinition

const POSITIVE: StringName = &"positive"
const NEUTRAL: StringName = &"neutral"
const NEGATIVE: StringName = &"negative"
const VALID_CATEGORIES: Array[StringName] = [POSITIVE, NEUTRAL, NEGATIVE]

@export var id: StringName = &"action"
@export var label := "Acción"
@export var category: StringName = NEUTRAL
@export var affinity_delta := 0
@export_multiline var response_text := ""


func category_label() -> String:
	match category:
		POSITIVE:
			return "Positiva"
		NEGATIVE:
			return "Negativa"
		_:
			return "Neutral"


func affinity_change_label() -> String:
	if affinity_delta > 0:
		return "+%d" % affinity_delta
	if affinity_delta < 0:
		return "%d" % affinity_delta
	return "±0"


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).strip_edges().is_empty():
		errors.append("Una acción de NPC no tiene id.")
	if label.strip_edges().is_empty():
		errors.append("La acción '%s' no tiene texto visible." % id)
	if category not in VALID_CATEGORIES:
		errors.append(
			"La acción '%s' tiene una categoría inválida: '%s'."
			% [id, category]
		)
	if response_text.strip_edges().is_empty():
		errors.append("La acción '%s' no tiene respuesta." % id)
	return errors
