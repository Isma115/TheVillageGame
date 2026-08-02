extends Node
class_name NpcDialogueSystem

const ACTION_COOLDOWN_SECONDS := 120.0

signal dialogue_started
signal dialogue_node_presented(
	speaker_name: String,
	speaker_title: String,
	text: String,
	choice_labels: PackedStringArray,
	discovered_choices: int,
	total_choices: int,
	path_depth: int,
	affinity: int
)
signal dialogue_actions_presented(actions: Array)
signal dialogue_action_cooldowns_presented(cooldowns: Dictionary)
signal dialogue_action_performed(
	action_label: String,
	category: StringName,
	affinity_delta: int,
	affinity: int,
	response_text: String
)
signal dialogue_finished
signal merchant_requested(npc_id: StringName, merchant: MerchantDefinition)
signal doctor_requested(npc_id: StringName, doctor: DoctorDefinition)
signal affinity_changed(npc_id: StringName, affinity: int)

@export var npc_scene: PackedScene

var npcs: Array[NpcActor] = []
var _interaction_system: InteractionSystem
var _collision_world: CollisionWorld
var _game_world: GameWorld
var _dialogues_by_npc: Dictionary = {}
var _dialogues_by_id: Dictionary = {}
var _discovered_by_dialogue: Dictionary = {}
var _affinity_by_npc: Dictionary = {}
var _action_cooldowns: Dictionary = {}
var _active_npc: NpcActor
var _active_dialogue: DialogueDefinition
var _active_node: DialogueNode
var _path: Array[StringName] = []
var _choice_transition_active := false


func initialize(
	definitions: Array[NpcDefinition],
	area_id: StringName,
	actor_layer: Node2D,
	collision_world: CollisionWorld,
	interaction_system: InteractionSystem,
	game_world: GameWorld
) -> void:
	_clear_npcs()
	_interaction_system = interaction_system
	_collision_world = collision_world
	_game_world = game_world
	_dialogues_by_npc.clear()
	_dialogues_by_id.clear()
	_affinity_by_npc.clear()
	_action_cooldowns.clear()

	if npc_scene == null:
		push_error("NpcDialogueSystem necesita una escena de NPC.")
		return

	for definition in definitions:
		if definition == null or definition.area_id != area_id:
			continue
		_spawn_npc(definition, actor_layer)


func npc_count(area_id: StringName = &"") -> int:
	if String(area_id).is_empty():
		return npcs.size()

	var count := 0
	for npc in npcs:
		if (
			is_instance_valid(npc)
			and npc.definition != null
			and npc.definition.area_id == area_id
		):
			count += 1
	return count


func dialogue_count() -> int:
	return _dialogues_by_id.size()


func merchant_count() -> int:
	var total := 0
	for npc in npcs:
		if (
			is_instance_valid(npc)
			and npc.definition != null
			and npc.definition.merchant != null
		):
			total += 1
	return total


func doctor_count() -> int:
	var total := 0
	for npc in npcs:
		if (
			is_instance_valid(npc)
			and npc.definition != null
			and npc.definition.doctor != null
		):
			total += 1
	return total


func total_choice_count() -> int:
	var total := 0
	for value in _dialogues_by_id.values():
		var definition := value as DialogueDefinition
		if definition != null:
			total += definition.choice_count()
	return total


func affinity_for_npc(npc_id: StringName) -> int:
	return int(_affinity_by_npc.get(npc_id, 0))


func affinity_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for npc_id in _affinity_by_npc.keys():
		result[String(npc_id)] = affinity_for_npc(npc_id)
	return result


func action_cooldown_remaining(npc_id: StringName, action_id: StringName) -> float:
	var cooldown := _action_cooldowns.get(
		_action_cooldown_key(npc_id, action_id)
	) as ActionCooldown
	return cooldown.remaining_seconds() if cooldown != null else 0.0


func action_cooldown_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for key in _action_cooldowns.keys():
		var cooldown := _action_cooldowns[key] as ActionCooldown
		if cooldown == null:
			continue
		var remaining := cooldown.remaining_seconds()
		if remaining > 0.0:
			result[String(key)] = remaining
	return result


func restore_action_cooldowns(snapshot_data: Dictionary) -> void:
	_action_cooldowns.clear()
	for key_value in snapshot_data.keys():
		var remaining := float(snapshot_data[key_value])
		if remaining <= 0.0:
			continue
		var cooldown := ActionCooldown.new()
		cooldown.try_start(remaining)
		_action_cooldowns[StringName(str(key_value))] = cooldown


func is_dialogue_active() -> bool:
	return _active_dialogue != null and _active_node != null


func active_speaker_name() -> String:
	return _active_dialogue.speaker_name if _active_dialogue != null else ""


func begin_dialogue(npc_id: StringName) -> bool:
	if is_dialogue_active():
		return false

	for npc in npcs:
		if (
			is_instance_valid(npc)
			and npc.definition != null
			and npc.definition.id == npc_id
		):
			var definition := (
				_dialogues_by_npc.get(npc.get_instance_id())
				as DialogueDefinition
			)
			return _start_dialogue(npc, definition)
	return false


func choose(choice_index: int) -> void:
	if (
		_choice_transition_active
		or
		not is_dialogue_active()
		or choice_index < 0
		or choice_index >= _active_node.choices.size()
	):
		return

	_choice_transition_active = true
	var choice := _active_node.choices[choice_index]
	if choice == null:
		_choice_transition_active = false
		return

	var discovered := _discovered_for(_active_dialogue)
	var is_new_discovery := not discovered.has(choice.id)
	discovered[choice.id] = true
	_discovered_by_dialogue[_active_dialogue.id] = discovered
	if is_new_discovery and _active_npc != null and _active_npc.definition != null:
		_increment_affinity(_active_npc.definition.id)
	_path.append(choice.id)

	var next_node := _active_dialogue.node_for(choice.target_node_id)
	if next_node == null:
		push_error(
			"El diálogo '%s' no contiene el nodo '%s'."
			% [_active_dialogue.id, choice.target_node_id]
		)
		close_dialogue()
		_choice_transition_active = false
		return

	_active_node = next_node
	_present_active_node()
	_choice_transition_active = false


func perform_action(action_index: int) -> void:
	if (
		_choice_transition_active
		or not is_dialogue_active()
		or action_index < 0
	):
		return

	var actions := _active_actions()
	if action_index >= actions.size():
		return

	var action := actions[action_index]
	if action == null or _active_npc == null or _active_npc.definition == null:
		return

	var npc_id := _active_npc.definition.id
	var cooldown := _action_cooldown_for(npc_id, action.id)
	if not cooldown.try_start(ACTION_COOLDOWN_SECONDS):
		_present_active_node()
		return

	_choice_transition_active = true
	_change_affinity(npc_id, action.affinity_delta)
	_present_active_node()
	dialogue_action_performed.emit(
		action.label,
		action.category,
		action.affinity_delta,
		affinity_for_npc(npc_id),
		action.response_text
	)
	_choice_transition_active = false


func close_dialogue() -> void:
	if not is_dialogue_active():
		return

	dialogue_actions_presented.emit([])
	dialogue_action_cooldowns_presented.emit({})
	_active_npc = null
	_active_dialogue = null
	_active_node = null
	_path.clear()
	_choice_transition_active = false
	dialogue_finished.emit()


func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for dialogue_id in _discovered_by_dialogue.keys():
		var discovered := _discovered_by_dialogue[dialogue_id] as Dictionary
		if discovered == null:
			continue
		var ids: Array[String] = []
		for choice_id in discovered.keys():
			ids.append(String(choice_id))
		ids.sort()
		result[String(dialogue_id)] = ids
	return result


func restore(snapshot_data: Dictionary) -> void:
	_discovered_by_dialogue.clear()
	for dialogue_id_value in snapshot_data.keys():
		var dialogue_id := StringName(dialogue_id_value)
		var definition := _dialogues_by_id.get(dialogue_id) as DialogueDefinition
		var saved_ids: Variant = snapshot_data[dialogue_id_value]
		if definition == null or not (saved_ids is Array):
			continue

		var known_ids := _choice_ids_for(definition)
		var discovered: Dictionary = {}
		for choice_id_value in saved_ids as Array:
			var choice_id := StringName(choice_id_value)
			if known_ids.has(choice_id):
				discovered[choice_id] = true
		_discovered_by_dialogue[dialogue_id] = discovered
	_rebuild_affinity_from_discoveries()


func restore_affinity(snapshot_data: Dictionary) -> void:
	if snapshot_data.is_empty():
		return
	for npc_id_value in snapshot_data.keys():
		var npc_id := StringName(npc_id_value)
		if not _affinity_by_npc.has(npc_id):
			continue
		_affinity_by_npc[npc_id] = int(snapshot_data[npc_id_value])
		affinity_changed.emit(npc_id, affinity_for_npc(npc_id))


func _spawn_npc(definition: NpcDefinition, actor_layer: Node2D) -> void:
	var npc := npc_scene.instantiate() as NpcActor
	if npc == null:
		push_error("La escena de NPC no crea un NpcActor.")
		return

	npc.configure(definition)
	actor_layer.add_child(npc)
	npc.interaction_requested.connect(_on_npc_interaction_requested)
	_interaction_system.register_interactable(npc)
	# Los NPC son atravesables; la reserva solo evita que el bosque los cubra.
	_game_world.register_placement_reservation(
		npc.collision_key(),
		npc.placement_rectangle()
	)
	if definition.dialogue != null:
		_dialogues_by_npc[npc.get_instance_id()] = definition.dialogue
		_dialogues_by_id[definition.dialogue.id] = definition.dialogue
	_affinity_by_npc[definition.id] = int(_affinity_by_npc.get(definition.id, 0))
	npcs.append(npc)


func _on_npc_interaction_requested(target: Node2D, _source: Node2D) -> void:
	var npc := target as NpcActor
	if npc == null or is_dialogue_active():
		return
	if npc.definition != null and npc.definition.doctor != null:
		doctor_requested.emit(npc.definition.id, npc.definition.doctor)
		return
	if npc.definition != null and npc.definition.merchant != null:
		merchant_requested.emit(npc.definition.id, npc.definition.merchant)
		return

	var definition := _dialogues_by_npc.get(npc.get_instance_id()) as DialogueDefinition
	_start_dialogue(npc, definition)


func _start_dialogue(
	npc: NpcActor,
	definition: DialogueDefinition
) -> bool:
	if npc == null or definition == null or is_dialogue_active():
		return false
	var first_node := definition.node_for(definition.start_node_id)
	if first_node == null:
		push_error(
			"El diálogo '%s' no puede comenzar: falta el nodo '%s'."
			% [definition.id, definition.start_node_id]
		)
		return false

	_active_npc = npc
	_active_dialogue = definition
	_active_node = first_node
	_path.clear()
	dialogue_started.emit()
	_present_active_node()
	return true


func _present_active_node() -> void:
	if not is_dialogue_active():
		return

	var labels := PackedStringArray()
	for choice in _active_node.choices:
		labels.append(choice.text)
	dialogue_node_presented.emit(
		_active_dialogue.speaker_name,
		_active_dialogue.speaker_title,
		_active_node.text,
		labels,
		_discovered_for(_active_dialogue).size(),
		_active_dialogue.choice_count(),
		_path.size(),
		affinity_for_npc(_active_npc.definition.id)
	)
	dialogue_actions_presented.emit(_active_actions())
	dialogue_action_cooldowns_presented.emit(_active_action_cooldowns())


func _discovered_for(definition: DialogueDefinition) -> Dictionary:
	return _discovered_by_dialogue.get(definition.id, {}) as Dictionary


func _active_actions() -> Array[NpcActionDefinition]:
	if _active_npc == null or _active_npc.definition == null:
		var empty_actions: Array[NpcActionDefinition] = []
		return empty_actions
	return _active_npc.definition.action_definitions()


func _active_action_cooldowns() -> Dictionary:
	var result: Dictionary = {}
	if _active_npc == null or _active_npc.definition == null:
		return result

	var npc_id := _active_npc.definition.id
	for action in _active_actions():
		if action == null:
			continue
		var remaining := action_cooldown_remaining(npc_id, action.id)
		if remaining > 0.0:
			result[String(action.id)] = remaining
	return result


func _action_cooldown_for(
	npc_id: StringName,
	action_id: StringName
) -> ActionCooldown:
	var key := _action_cooldown_key(npc_id, action_id)
	var cooldown := _action_cooldowns.get(key) as ActionCooldown
	if cooldown == null:
		cooldown = ActionCooldown.new()
		_action_cooldowns[key] = cooldown
	return cooldown


func _action_cooldown_key(npc_id: StringName, action_id: StringName) -> StringName:
	return StringName("%s:%s" % [npc_id, action_id])


func _choice_ids_for(definition: DialogueDefinition) -> Dictionary:
	var ids: Dictionary = {}
	for node in definition.nodes():
		for choice in node.choices:
			if choice != null:
				ids[choice.id] = true
	return ids


func _increment_affinity(npc_id: StringName) -> void:
	_change_affinity(npc_id, 1)


func _change_affinity(npc_id: StringName, delta: int) -> void:
	var next_affinity := affinity_for_npc(npc_id) + delta
	_affinity_by_npc[npc_id] = next_affinity
	affinity_changed.emit(npc_id, next_affinity)


func _rebuild_affinity_from_discoveries() -> void:
	for npc in npcs:
		if (
			not is_instance_valid(npc)
			or npc.definition == null
			or npc.definition.dialogue == null
		):
			continue
		var discovered := _discovered_by_dialogue.get(
			npc.definition.dialogue.id,
		{}
		) as Dictionary
		_affinity_by_npc[npc.definition.id] = discovered.size()


func _clear_npcs() -> void:
	close_dialogue()
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		if _interaction_system != null:
			_interaction_system.unregister_interactable(npc)
		if _game_world != null:
			_game_world.unregister_placement_reservation(npc.collision_key())
		npc.queue_free()
	npcs.clear()
