extends RefCounted
class_name ControlSettings

signal bindings_changed

const SETTINGS_PATH := "user://pradera_controls.cfg"

const ACTION_ORDER := [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"sprint",
	&"interact",
	&"pause",
	&"inventory",
	&"primary_action",
	&"minigame_action",
	&"terrain_action",
	&"hunting_toggle",
	&"hunting_weapon_1",
	&"hunting_weapon_2",
	&"hunting_weapon_cycle",
	&"tool_slot_1",
	&"tool_slot_2",
	&"tool_slot_3",
	&"tool_slot_4",
	&"tool_slot_5",
	&"tool_slot_6",
	&"tool_slot_7",
	&"tool_slot_8",
	&"tool_slot_9",
]

const ACTION_LABELS := {
	&"move_up": "Mover arriba",
	&"move_down": "Mover abajo",
	&"move_left": "Mover a la izquierda",
	&"move_right": "Mover a la derecha",
	&"sprint": "Correr",
	&"interact": "Interactuar",
	&"pause": "Pausa / cerrar menús",
	&"inventory": "Abrir inventario",
	&"primary_action": "Acción principal (talar, recoger, disparar)",
	&"minigame_action": "Golpear / mantener en minijuegos",
	&"terrain_action": "Acciones del terreno",
	&"hunting_toggle": "Activar / desactivar caza",
	&"hunting_weapon_1": "Seleccionar flechas en caza",
	&"hunting_weapon_2": "Seleccionar piedras en caza",
	&"hunting_weapon_cycle": "Cambiar arma de caza",
	&"tool_slot_1": "Equipar herramienta 1",
	&"tool_slot_2": "Equipar herramienta 2",
	&"tool_slot_3": "Equipar herramienta 3",
	&"tool_slot_4": "Equipar herramienta 4",
	&"tool_slot_5": "Equipar herramienta 5",
	&"tool_slot_6": "Equipar herramienta 6",
	&"tool_slot_7": "Equipar herramienta 7",
	&"tool_slot_8": "Equipar herramienta 8",
	&"tool_slot_9": "Equipar herramienta 9",
}

const DEFAULT_BINDINGS := {
	&"move_up": [
		{"kind": "key", "code": KEY_W},
		{"kind": "key", "code": KEY_UP},
	],
	&"move_down": [
		{"kind": "key", "code": KEY_S},
		{"kind": "key", "code": KEY_DOWN},
	],
	&"move_left": [
		{"kind": "key", "code": KEY_A},
		{"kind": "key", "code": KEY_LEFT},
	],
	&"move_right": [
		{"kind": "key", "code": KEY_D},
		{"kind": "key", "code": KEY_RIGHT},
	],
	&"sprint": [
		{"kind": "key", "code": KEY_SHIFT},
	],
	&"interact": [
		{"kind": "key", "code": KEY_E},
		{"kind": "key", "code": KEY_SPACE},
	],
	&"pause": [
		{"kind": "key", "code": KEY_ESCAPE},
	],
	&"inventory": [
		{"kind": "key", "code": KEY_R},
	],
	&"primary_action": [
		{"kind": "mouse", "code": MOUSE_BUTTON_LEFT},
	],
	&"minigame_action": [
		{"kind": "mouse", "code": MOUSE_BUTTON_LEFT},
		{"kind": "key", "code": KEY_SPACE},
		{"kind": "key", "code": KEY_ENTER},
	],
	&"terrain_action": [
		{"kind": "mouse", "code": MOUSE_BUTTON_RIGHT},
	],
	&"hunting_toggle": [
		{"kind": "key", "code": KEY_TAB},
	],
	&"hunting_weapon_1": [
		{"kind": "key", "code": KEY_1},
	],
	&"hunting_weapon_2": [
		{"kind": "key", "code": KEY_2},
	],
	&"hunting_weapon_cycle": [
		{"kind": "key", "code": KEY_Q},
		{"kind": "mouse", "code": MOUSE_BUTTON_WHEEL_UP},
		{"kind": "mouse", "code": MOUSE_BUTTON_WHEEL_DOWN},
	],
	&"tool_slot_1": [{"kind": "key", "code": KEY_1}],
	&"tool_slot_2": [{"kind": "key", "code": KEY_2}],
	&"tool_slot_3": [{"kind": "key", "code": KEY_3}],
	&"tool_slot_4": [{"kind": "key", "code": KEY_4}],
	&"tool_slot_5": [{"kind": "key", "code": KEY_5}],
	&"tool_slot_6": [{"kind": "key", "code": KEY_6}],
	&"tool_slot_7": [{"kind": "key", "code": KEY_7}],
	&"tool_slot_8": [{"kind": "key", "code": KEY_8}],
	&"tool_slot_9": [{"kind": "key", "code": KEY_9}],
}

var _bindings: Dictionary = {}
var _last_error := ""


func _init() -> void:
	_restore_defaults()
	_load_settings()


func action_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for action_id in ACTION_ORDER:
		result.append(StringName(action_id))
	return result


func action_label(action_id: StringName) -> String:
	return str(ACTION_LABELS.get(action_id, String(action_id)))


func binding_text(action_id: StringName) -> String:
	var labels: Array[String] = []
	var bindings: Array = _bindings.get(action_id, [])
	for binding_variant in bindings:
		var binding := binding_variant as Dictionary
		if binding != null:
			labels.append(_binding_text(binding))
	return " / ".join(labels) if not labels.is_empty() else "Sin asignar"


func is_action_pressed(action_id: StringName) -> bool:
	var bindings: Array = _bindings.get(action_id, [])
	for binding_variant in bindings:
		var binding := binding_variant as Dictionary
		if binding == null or binding.get("kind", "") != "key":
			continue
		if Input.is_key_pressed(int(binding.get("code", KEY_NONE))):
			return true
	return false


func matches_event(action_id: StringName, event: InputEvent) -> bool:
	var bindings: Array = _bindings.get(action_id, [])
	for binding_variant in bindings:
		var binding := binding_variant as Dictionary
		if binding == null:
			continue
		var kind := str(binding.get("kind", ""))
		if kind == "key" and event is InputEventKey:
			var key_event := event as InputEventKey
			var code := int(binding.get("code", KEY_NONE))
			if key_event.keycode == code or key_event.physical_keycode == code:
				return true
		elif kind == "mouse" and event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			if int(mouse_event.button_index) == int(binding.get("code", -1)):
				return true
	return false


func binding_from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := int(key_event.keycode)
		if code == KEY_NONE:
			code = int(key_event.physical_keycode)
		if code == KEY_NONE:
			return {}
		return {"kind": "key", "code": code}
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return {"kind": "mouse", "code": int(mouse_event.button_index)}
	return {}


func set_binding(action_id: StringName, binding: Dictionary) -> bool:
	_last_error = ""
	if not ACTION_ORDER.has(action_id) or not _is_valid_binding(binding):
		_last_error = "Ese control no se puede asignar."
		return false

	if _has_binding(action_id, binding):
		return true

	var conflicts := _conflicting_action_labels(action_id, binding)
	if not conflicts.is_empty():
		_last_error = "Ese control ya está asignado a: %s." % ", ".join(conflicts)
		return false

	_bindings[action_id] = [binding.duplicate()]
	_save_settings()
	bindings_changed.emit()
	return true


func last_error() -> String:
	return _last_error


func reset_to_defaults() -> void:
	_restore_defaults()
	_save_settings()
	bindings_changed.emit()


func save_settings() -> void:
	_save_settings()


func _restore_defaults() -> void:
	_bindings.clear()
	for action_id in ACTION_ORDER:
		var defaults: Array = DEFAULT_BINDINGS.get(action_id, [])
		var copied: Array = []
		for binding_variant in defaults:
			var binding := binding_variant as Dictionary
			if binding != null:
				copied.append(binding.duplicate())
		_bindings[action_id] = copied


func _has_binding(action_id: StringName, binding: Dictionary) -> bool:
	var current: Array = _bindings.get(action_id, [])
	for current_variant in current:
		var current_binding := current_variant as Dictionary
		if current_binding != null and _bindings_equal(current_binding, binding):
			return true
	return false


func _conflicting_action_labels(
	action_id: StringName,
	binding: Dictionary
) -> Array[String]:
	var conflicts: Array[String] = []
	for other_action in ACTION_ORDER:
		if other_action == action_id:
			continue
		if _has_binding(StringName(other_action), binding):
			conflicts.append(action_label(StringName(other_action)))
	return conflicts


func _is_valid_binding(binding: Dictionary) -> bool:
	var kind := str(binding.get("kind", ""))
	var code := int(binding.get("code", -1))
	return (
		(kind == "key" and code != KEY_NONE)
		or (kind == "mouse" and code >= MOUSE_BUTTON_LEFT)
	)


func _bindings_equal(first: Dictionary, second: Dictionary) -> bool:
	return (
		str(first.get("kind", "")) == str(second.get("kind", ""))
		and int(first.get("code", -1)) == int(second.get("code", -1))
	)


func _binding_text(binding: Dictionary) -> String:
	var kind := str(binding.get("kind", ""))
	var code := int(binding.get("code", -1))
	if kind == "mouse":
		match code:
			MOUSE_BUTTON_LEFT:
				return "Clic izquierdo"
			MOUSE_BUTTON_RIGHT:
				return "Clic derecho"
			MOUSE_BUTTON_MIDDLE:
				return "Clic central"
			MOUSE_BUTTON_WHEEL_UP:
				return "Rueda arriba"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Rueda abajo"
			_:
				return "Botón %d" % code

	match code:
		KEY_ESCAPE:
			return "Esc"
		KEY_SPACE:
			return "Espacio"
		KEY_SHIFT:
			return "Shift"
		KEY_TAB:
			return "Tabulador"
		KEY_ENTER:
			return "Enter"
		KEY_UP:
			return "Flecha arriba"
		KEY_DOWN:
			return "Flecha abajo"
		KEY_LEFT:
			return "Flecha izquierda"
		KEY_RIGHT:
			return "Flecha derecha"
		_:
			var key_label := OS.get_keycode_string(code)
			return key_label if not key_label.is_empty() else "Tecla %d" % code


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	for action_id in ACTION_ORDER:
		var raw: Variant = config.get_value("bindings", String(action_id), null)
		var parsed: Variant = raw
		if raw is String:
			parsed = JSON.parse_string(raw as String)
		if not parsed is Array or not _is_valid_binding_array(parsed as Array):
			continue
		var restored: Array = []
		for binding_variant in parsed as Array:
			var binding := binding_variant as Dictionary
			if binding != null:
				restored.append({
					"kind": str(binding.get("kind", "")),
					"code": int(binding.get("code", -1))
				})
		_bindings[StringName(action_id)] = restored


func _is_valid_binding_array(bindings: Array) -> bool:
	if bindings.is_empty():
		return false
	for binding_variant in bindings:
		if not binding_variant is Dictionary:
			return false
		if not _is_valid_binding(binding_variant as Dictionary):
			return false
	return true


func _save_settings() -> void:
	var config := ConfigFile.new()
	for action_id in ACTION_ORDER:
		config.set_value(
			"bindings",
			String(action_id),
			JSON.stringify(_bindings.get(action_id, []))
		)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("No se pudieron guardar los controles: %s" % error_string(error))
