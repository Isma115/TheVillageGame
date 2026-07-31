extends Control
class_name DialoguePanel

signal choice_selected(choice_index: int)
signal action_selected(action_index: int)
signal close_requested

@onready var speaker_name_label: Label = %SpeakerName
@onready var speaker_title_label: Label = %SpeakerTitle
@onready var progress_label: Label = %ProgressLabel
@onready var affinity_label: Label = %AffinityLabel
@onready var path_label: Label = %PathLabel
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var choice_list: VBoxContainer = %ChoiceList
@onready var action_heading: Label = %ActionHeading
@onready var action_list: HBoxContainer = %ActionList
@onready var action_feedback: Label = %ActionFeedback
@onready var terminal_button: Button = %TerminalButton
@onready var close_button: Button = %CloseButton
@onready var portrait: DialoguePortrait = %Portrait
@onready var hint_label: Label = %DialogueHint

var _choice_buttons: Array[Button] = []
var _choice_style: StyleBoxFlat
var _choice_hover_style: StyleBoxFlat
var _choice_pressed_style: StyleBoxFlat
var _choice_focus_style: StyleBoxFlat
var _action_styles: Dictionary = {}
var _action_buttons: Array[Button] = []
var _action_definitions: Array[NpcActionDefinition] = []
var _action_base_texts: Array[String] = []
var _action_base_tooltips: Array[String] = []
var _action_cooldown_until_msec: Dictionary = {}
var _choice_count := 0
var _action_count := 0
var _choice_locked := false
var _affinity := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_emit_close_requested)
	terminal_button.pressed.connect(_emit_close_requested)
	_choice_style = _make_choice_style(
		Color(0.075, 0.137, 0.094, 0.88),
		Color(0.945, 0.957, 0.867, 0.16)
	)
	_choice_hover_style = _make_choice_style(
		Color("#315f3b"),
		Color(0.851, 0.925, 0.439, 0.78)
	)
	_choice_pressed_style = _make_choice_style(
		Color("#d9ec70"),
		Color("#f1f4dd")
	)
	_choice_focus_style = _make_choice_style(
		Color("#244a30"),
		Color("#d9ec70")
	)
	_action_styles[NpcActionDefinition.POSITIVE] = _make_choice_style(
		Color(0.12, 0.25, 0.16, 0.94),
		Color(0.55, 0.82, 0.43, 0.78)
	)
	_action_styles[NpcActionDefinition.NEUTRAL] = _make_choice_style(
		Color(0.10, 0.18, 0.22, 0.94),
		Color(0.43, 0.72, 0.82, 0.78)
	)
	_action_styles[NpcActionDefinition.NEGATIVE] = _make_choice_style(
		Color(0.28, 0.13, 0.14, 0.94),
		Color(0.91, 0.48, 0.44, 0.78)
	)
	_build_choice_buttons()
	_build_action_buttons()
	visible = false


func _process(_delta: float) -> void:
	if visible and _action_count > 0:
		_refresh_action_cooldowns()


func set_mobile_mode(enabled: bool) -> void:
	hint_label.text = (
		"TOCA UNA RESPUESTA O UNA OPCIÓN SOCIAL"
		if enabled
		else "↑ ↓  ELEGIR   ·   1–4  RESPONDER   ·   OPCIONES SOCIALES   ·   ESC  CERRAR"
	)


func show_node(
	speaker_name: String,
	speaker_title: String,
	text: String,
	choice_labels: PackedStringArray,
	discovered_choices: int,
	total_choices: int,
	path_depth: int,
	affinity: int
) -> void:
	speaker_name_label.text = speaker_name.to_upper()
	speaker_title_label.text = speaker_title
	dialogue_text.text = text
	progress_label.text = "DESCUBIERTAS  %d / %d" % [
		discovered_choices,
		total_choices
	]
	_set_affinity_display(affinity)
	_affinity = affinity
	action_feedback.text = ""
	action_feedback.visible = false
	path_label.text = (
		"INICIO DE RUTA"
		if path_depth == 0
		else "RUTA ACTUAL  ·  %d %s" % [
			path_depth,
			"PASO" if path_depth == 1 else "PASOS"
		]
	)
	portrait.set_speaker(speaker_name)
	_rebuild_choices(choice_labels)
	terminal_button.visible = choice_labels.is_empty()
	_choice_locked = false
	visible = true

	if terminal_button.visible:
		terminal_button.call_deferred("grab_focus")
	elif not _choice_buttons.is_empty():
		_choice_buttons[0].call_deferred("grab_focus")


func hide_panel() -> void:
	visible = false
	_clear_choices()
	_clear_actions()
	action_feedback.text = ""
	action_feedback.visible = false
	_choice_locked = false
	_affinity = 0


func visible_choice_count() -> int:
	return _choice_count if visible else 0


func affinity() -> int:
	return _affinity if visible else 0


func visible_action_count() -> int:
	return _action_count if visible else 0


func show_actions(actions: Array) -> void:
	_rebuild_actions(actions)
	var has_actions := _action_count > 0
	action_heading.visible = has_actions
	action_list.visible = has_actions
	if not has_actions:
		_action_cooldown_until_msec.clear()
		action_feedback.visible = false


func set_action_cooldowns(cooldowns: Dictionary) -> void:
	_action_cooldown_until_msec.clear()
	var now_msec := Time.get_ticks_msec()
	for action_id in cooldowns.keys():
		var remaining := float(cooldowns[action_id])
		if remaining <= 0.0:
			continue
		_action_cooldown_until_msec[StringName(str(action_id))] = (
			now_msec + roundi(remaining * 1000.0)
		)
	_refresh_action_cooldowns()


func show_action_result(
	action_label: String,
	category: StringName,
	affinity_delta: int,
	affinity: int,
	response_text: String
) -> void:
	var category_text := _category_label(category).to_upper()
	action_feedback.text = "%s: %s  ·  %s afinidad  ·  Total %d\n%s" % [
		action_label,
		category_text,
		_affinity_change_label(affinity_delta),
		affinity,
		response_text
	]
	action_feedback.visible = true
	_set_affinity_display(affinity)
	_affinity = affinity


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		_emit_close_requested()
		get_viewport().set_input_as_handled()
		return

	var shortcut_index := _number_shortcut_index(event)
	if shortcut_index >= 0 and shortcut_index < _choice_count:
		_on_choice_pressed(shortcut_index)
		get_viewport().set_input_as_handled()


func _build_choice_buttons() -> void:
	for choice_index in range(4):
		var button := Button.new()
		button.name = "Choice%d" % (choice_index + 1)
		button.custom_minimum_size = Vector2(0.0, 43.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_color_override("font_color", Color("#f1f4dd"))
		button.add_theme_color_override("font_hover_color", Color("#f1f4dd"))
		button.add_theme_color_override("font_focus_color", Color("#f1f4dd"))
		button.add_theme_color_override("font_pressed_color", Color("#193724"))
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_stylebox_override("normal", _choice_style)
		button.add_theme_stylebox_override("hover", _choice_hover_style)
		button.add_theme_stylebox_override("pressed", _choice_pressed_style)
		button.add_theme_stylebox_override("focus", _choice_focus_style)
		button.pressed.connect(_on_choice_pressed.bind(choice_index))
		button.visible = false
		choice_list.add_child(button)
		_choice_buttons.append(button)


func _build_action_buttons() -> void:
	for action_index in range(4):
		var button := Button.new()
		button.name = "Action%d" % (action_index + 1)
		button.custom_minimum_size = Vector2(0.0, 39.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_color_override("font_color", Color("#f1f4dd"))
		button.add_theme_color_override("font_hover_color", Color("#f1f4dd"))
		button.add_theme_color_override("font_focus_color", Color("#f1f4dd"))
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_stylebox_override(
			"normal",
			_action_styles[NpcActionDefinition.NEUTRAL]
		)
		button.add_theme_stylebox_override(
			"hover",
			_action_styles[NpcActionDefinition.POSITIVE]
		)
		button.add_theme_stylebox_override(
			"pressed",
			_action_styles[NpcActionDefinition.POSITIVE]
		)
		button.pressed.connect(_on_action_pressed.bind(action_index))
		button.visible = false
		button.disabled = true
		action_list.add_child(button)
		_action_buttons.append(button)


func _rebuild_choices(choice_labels: PackedStringArray) -> void:
	_choice_count = mini(choice_labels.size(), _choice_buttons.size())
	for choice_index in range(_choice_buttons.size()):
		var button := _choice_buttons[choice_index]
		var active := choice_index < _choice_count
		button.visible = active
		button.disabled = not active
		if active:
			button.text = "%d.  %s" % [choice_index + 1, choice_labels[choice_index]]
			button.tooltip_text = choice_labels[choice_index]
		else:
			button.text = ""
			button.tooltip_text = ""


func _clear_choices() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.visible = false
			button.disabled = true
	_choice_count = 0


func _rebuild_actions(actions: Array) -> void:
	_action_count = mini(actions.size(), _action_buttons.size())
	_action_definitions.clear()
	_action_definitions.resize(_action_buttons.size())
	_action_base_texts.clear()
	_action_base_texts.resize(_action_buttons.size())
	_action_base_tooltips.clear()
	_action_base_tooltips.resize(_action_buttons.size())
	for action_index in range(_action_buttons.size()):
		var button := _action_buttons[action_index]
		var active := action_index < _action_count
		button.visible = active
		button.disabled = not active
		if not active:
			button.text = ""
			button.tooltip_text = ""
			continue

		var action := actions[action_index] as NpcActionDefinition
		if action == null:
			button.visible = false
			button.disabled = true
			continue
		var base_text := "%s  %s  [%s]" % [
			action.category_label().to_upper(),
			action.label,
			action.affinity_change_label()
		]
		_action_definitions[action_index] = action
		_action_base_texts[action_index] = base_text
		_action_base_tooltips[action_index] = action.response_text
		button.text = base_text
		button.tooltip_text = action.response_text
		var style := _action_styles.get(
			action.category,
			_action_styles[NpcActionDefinition.NEUTRAL]
		) as StyleBoxFlat
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
	_refresh_action_cooldowns()


func _refresh_action_cooldowns() -> void:
	var now_msec := Time.get_ticks_msec()
	for action_index in range(_action_buttons.size()):
		var button := _action_buttons[action_index]
		if not button.visible:
			continue

		var action := _action_definitions[action_index]
		if action == null:
			button.disabled = true
			continue

		var ready_at_msec := int(
			_action_cooldown_until_msec.get(action.id, 0)
		)
		var remaining := maxf(
			0.0,
			float(ready_at_msec - now_msec) / 1000.0
		)
		button.disabled = remaining > 0.0
		var button_text := _action_base_texts[action_index]
		var tooltip := _action_base_tooltips[action_index]
		if remaining > 0.0:
			var formatted_remaining := _format_cooldown(remaining)
			button_text += "  ·  En %s" % formatted_remaining
			tooltip += "\nDisponible en %s." % formatted_remaining
		button.text = button_text
		button.tooltip_text = tooltip


func _format_cooldown(seconds: float) -> String:
	var total_seconds := maxi(1, ceili(seconds))
	var minutes := floori(float(total_seconds) / 60.0)
	var remaining_seconds := total_seconds % 60
	return "%d:%02d" % [minutes, remaining_seconds]


func _clear_actions() -> void:
	for button in _action_buttons:
		if is_instance_valid(button):
			button.visible = false
			button.disabled = true
	_action_count = 0
	action_heading.visible = false
	action_list.visible = false
	_action_definitions.clear()
	_action_base_texts.clear()
	_action_base_tooltips.clear()
	_action_cooldown_until_msec.clear()


func _on_action_pressed(action_index: int) -> void:
	if (
		action_index < 0
		or action_index >= _action_count
		or _action_buttons[action_index].disabled
	):
		return
	action_selected.emit(action_index)


func _on_choice_pressed(choice_index: int) -> void:
	if _choice_locked or choice_index < 0 or choice_index >= _choice_count:
		return
	_choice_locked = true
	choice_selected.emit(choice_index)


func _emit_close_requested() -> void:
	close_requested.emit()


func _category_label(category: StringName) -> String:
	match category:
		NpcActionDefinition.POSITIVE:
			return "Positiva"
		NpcActionDefinition.NEGATIVE:
			return "Negativa"
		_:
			return "Neutral"


func _affinity_change_label(delta: int) -> String:
	if delta > 0:
		return "+%d" % delta
	if delta < 0:
		return "%d" % delta
	return "±0"


func _set_affinity_display(value: int) -> void:
	affinity_label.text = "AFINIDAD  %d" % value
	affinity_label.add_theme_color_override(
		"font_color",
		Color("#ff9d8d") if value < 0 else Color("#d9ec70")
	)


func _number_shortcut_index(event: InputEventKey) -> int:
	var key := event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	match key:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		KEY_4, KEY_KP_4:
			return 3
	return -1


func _make_choice_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14.0
	style.content_margin_top = 8.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 8.0
	return style
