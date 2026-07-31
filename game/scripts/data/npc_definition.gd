extends Resource
class_name NpcDefinition

@export_group("Identidad")
@export var id: StringName = &"npc"
@export var display_name := "NPC"
@export var title := ""
@export var dialogue: DialogueDefinition
@export_range(0, 10000, 1) var expected_choice_count := 0
@export var interaction_actions: Array[NpcActionDefinition] = []
@export var merchant: MerchantDefinition
@export var doctor: DoctorDefinition

@export_group("Mundo")
@export var area_id: StringName = &"overworld"
@export var world_position := Vector2.ZERO
@export_range(24.0, 256.0, 1.0) var interaction_distance := 96.0
@export var collision_rect := Rect2(-15.0, 13.0, 30.0, 20.0)
@export var placement_rect := Rect2(-48.0, -58.0, 96.0, 104.0)

@export_group("Aspecto")
@export var skin_color := Color("#d9a06f")
@export var hair_color := Color("#4b4057")
@export var clothing_color := Color("#725c9c")
@export var accent_color := Color("#e0bd63")


func world_collision_rect() -> Rect2:
	return Rect2(world_position + collision_rect.position, collision_rect.size)


func world_placement_rect() -> Rect2:
	return Rect2(world_position + placement_rect.position, placement_rect.size)


func action_definitions() -> Array[NpcActionDefinition]:
	var definitions: Array[NpcActionDefinition] = []
	for action in interaction_actions:
		if action != null:
			definitions.append(action)
	return definitions


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un NPC no tiene id.")
	if display_name.strip_edges().is_empty():
		errors.append("El NPC '%s' no tiene nombre." % id)
	if String(area_id).is_empty():
		errors.append("El NPC '%s' no tiene área." % id)
	if interaction_distance <= 0.0:
		errors.append("El NPC '%s' tiene una distancia de interacción inválida." % id)
	if collision_rect.size.x <= 0.0 or collision_rect.size.y <= 0.0:
		errors.append("El NPC '%s' tiene una colisión inválida." % id)
	if placement_rect.size.x <= 0.0 or placement_rect.size.y <= 0.0:
		errors.append("El NPC '%s' tiene una reserva de espacio inválida." % id)
	if interaction_actions.size() > 4:
		errors.append(
			"El NPC '%s' tiene más de cuatro acciones visibles."
			% id
		)
	var action_ids: Dictionary = {}
	for action in action_definitions():
		errors.append_array(action.validate())
		if action_ids.has(action.id):
			errors.append(
				"El NPC '%s' repite la acción '%s'." % [id, action.id]
			)
		action_ids[action.id] = true
	if dialogue == null and merchant == null and doctor == null:
		errors.append("El NPC '%s' no tiene diálogo ni servicio interactivo." % id)
	if dialogue != null:
		errors.append_array(dialogue.validate())
		if (
			expected_choice_count > 0
			and dialogue.choice_count() != expected_choice_count
		):
			errors.append(
				"El diálogo de '%s' contiene %d elecciones; se esperaban %d."
				% [
					display_name,
					dialogue.choice_count(),
					expected_choice_count
				]
			)
	if merchant != null:
		errors.append_array(merchant.validate())
	if doctor != null:
		errors.append_array(doctor.validate())
	return errors
