extends Control
class_name GameHud

signal mobile_controls_toggled(enabled: bool)
signal pause_state_changed(paused: bool)
signal save_confirmed(exit_after_save: bool)
signal save_cancelled(exit_after_save: bool)
signal dialogue_choice_selected(choice_index: int)
signal dialogue_action_selected(action_index: int)
signal dialogue_close_requested
signal merchant_buy_requested(offer_id: StringName)
signal merchant_sell_requested(offer_id: StringName)
signal merchant_close_requested
signal doctor_close_requested
signal doctor_diagnosis_requested
signal planting_seed_selected(seed_id: StringName)
signal planting_close_requested
signal planting_context_plant_requested
signal water_context_drink_requested
signal inventory_close_requested
signal blacksmith_coin_earned
signal blacksmith_close_requested
signal volume_changed(master_volume: float, sfx_volume: float)
signal volume_preview_requested
signal options_closed

@onready var debug_panel: PanelContainer = %DebugPanel
@onready var debug_fps: Label = %DebugFps
@onready var debug_fps_value: Label = %DebugFpsValue
@onready var debug_cpu_value: Label = %DebugCpuValue
@onready var debug_gpu_value: Label = %DebugGpuValue
@onready var debug_memory_value: Label = %DebugMemoryValue
@onready var debug_entities_value: Label = %DebugEntitiesValue
@onready var debug_objects_value: Label = %DebugObjectsValue
@onready var debug_detail: Label = %DebugDetail
@onready var debug_particles: Label = %DebugParticles
@onready var mobile_toggle: CheckButton = %MobileToggle
@onready var location_label: Label = %LocationLabel
@onready var interaction_prompt: PanelContainer = %InteractionPrompt
@onready var interaction_label: Label = %InteractionLabel
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var notification_label: Label = %NotificationLabel
@onready var vitals_panel: PanelContainer = %VitalsPanel
@onready var stamina_bars_container: Control = %StaminaBars
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_maximum_bar: ProgressBar = %StaminaMaximumBar
@onready var stamina_empty_bar: ProgressBar = %StaminaEmptyBar
@onready var stamina_value: Label = %StaminaValue
@onready var thirst_bar: ProgressBar = %ThirstBar
@onready var thirst_value: Label = %ThirstValue
@onready var temperature_value: Label = %TemperatureValue
@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var inventory_wallet_label: Label = %InventoryWalletLabel
@onready var inventory_list: VBoxContainer = %InventoryList
@onready var inventory_tools_list: VBoxContainer = %InventoryToolsList
@onready var inventory_close_button: Button = %InventoryClose
@onready var pause_overlay: Control = %PauseOverlay
@onready var pause_menu: PanelContainer = %PauseMenu
@onready var save_dialog: PanelContainer = %SaveDialog
@onready var save_heading: Label = %SaveHeading
@onready var save_question: Label = %SaveQuestion
@onready var pause_status: Label = %PauseStatus
@onready var continue_button: Button = %ContinueButton
@onready var save_button: Button = %SaveButton
@onready var exit_button: Button = %ExitButton
@onready var options_button: Button = %OptionsButton
@onready var options_dialog: PanelContainer = %OptionsDialog
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var options_back_button: Button = %OptionsBackButton
@onready var save_accept_button: Button = %SaveAcceptButton
@onready var save_cancel_button: Button = %SaveCancelButton
@onready var dialogue_panel: DialoguePanel = %DialoguePanel
@onready var merchant_panel: MerchantPanel = %MerchantPanel
@onready var doctor_panel: DoctorPanel = %DoctorPanel
@onready var planting_panel: PlantingPanel = %PlantingPanel
@onready var planting_context_menu: PanelContainer = %PlantingContextMenu
@onready var planting_context_button: Button = %PlantingContextButton
@onready var blacksmith_panel: BlacksmithPanel = %BlacksmithPanel
@onready var hunting_cursor: HuntingCursor = %HuntingCursor
@onready var hunting_hint: PanelContainer = %HuntingHint
@onready var sleep_fade: ColorRect = %SleepFade

var _mobile_build := false
var _inventory_labels: Dictionary = {}
var _inventory_tool_labels: Dictionary = {}
var _pause_open := false
var _save_for_exit := false
var _stamina_capacity_limit := 100.0
var _stamina_bar_base_width := 108.0
var _vitals_panel_base_right := 258.0
var _context_action: StringName = &""
var _notification_tween: Tween
var _sleep_fade_tween: Tween

const SLEEP_FADE_DURATION := 0.65


func _ready() -> void:
	mobile_toggle.toggled.connect(_on_mobile_toggle_changed)
	continue_button.pressed.connect(resume_game)
	save_button.pressed.connect(_open_save_confirmation)
	exit_button.pressed.connect(_open_exit_confirmation)
	options_button.pressed.connect(open_options)
	options_back_button.pressed.connect(close_options)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	master_volume_slider.drag_ended.connect(_on_volume_drag_ended)
	sfx_volume_slider.drag_ended.connect(_on_volume_drag_ended)
	save_accept_button.pressed.connect(_on_save_accept_pressed)
	save_cancel_button.pressed.connect(_on_save_cancel_pressed)
	dialogue_panel.choice_selected.connect(_on_dialogue_choice_selected)
	dialogue_panel.action_selected.connect(_on_dialogue_action_selected)
	dialogue_panel.close_requested.connect(_on_dialogue_close_requested)
	merchant_panel.buy_requested.connect(_on_merchant_buy_requested)
	merchant_panel.sell_requested.connect(_on_merchant_sell_requested)
	merchant_panel.close_requested.connect(_on_merchant_close_requested)
	doctor_panel.close_requested.connect(_on_doctor_close_requested)
	doctor_panel.diagnosis_requested.connect(_on_doctor_diagnosis_requested)
	planting_panel.seed_selected.connect(_on_planting_seed_selected)
	planting_panel.close_requested.connect(_on_planting_close_requested)
	planting_context_button.pressed.connect(_on_context_button_pressed)
	planting_context_menu.gui_input.connect(_on_planting_context_menu_gui_input)
	blacksmith_panel.coin_earned.connect(_on_blacksmith_coin_earned)
	blacksmith_panel.close_requested.connect(_on_blacksmith_close_requested)
	inventory_close_button.pressed.connect(_on_inventory_close_requested)


func initialize(
	mobile_build: bool,
	maximum_stamina_limit: float = 100.0
) -> void:
	_mobile_build = mobile_build
	_stamina_capacity_limit = maxf(maximum_stamina_limit, 1.0)
	_stamina_bar_base_width = stamina_bars_container.custom_minimum_size.x
	_vitals_panel_base_right = vitals_panel.offset_right
	debug_panel.visible = not mobile_build
	_pause_open = false
	_save_for_exit = false
	pause_overlay.visible = false
	pause_menu.visible = true
	save_dialog.visible = false
	options_dialog.visible = false
	pause_status.text = ""
	interaction_prompt.visible = false
	notification_panel.visible = false
	sleep_fade.visible = false
	sleep_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	mobile_toggle.set_pressed_no_signal(false)
	dialogue_panel.set_mobile_mode(mobile_build)
	dialogue_panel.hide_panel()
	merchant_panel.hide_shop()
	doctor_panel.hide_consultation()
	planting_panel.hide_panel()
	blacksmith_panel.hide_minigame()
	hide_inventory()
	set_hunting_mode(false)


func open_pause_menu() -> void:
	if (
		_pause_open
		or dialogue_panel.visible
		or merchant_panel.visible
		or doctor_panel.visible
		or planting_panel.visible
		or blacksmith_panel.visible
		or inventory_panel.visible
	):
		return
	_pause_open = true
	pause_overlay.visible = true
	pause_menu.visible = true
	save_dialog.visible = false
	options_dialog.visible = false
	_save_for_exit = false
	pause_status.text = ""
	pause_state_changed.emit(true)
	continue_button.grab_focus()


func resume_game() -> void:
	if not _pause_open:
		return
	_pause_open = false
	pause_overlay.visible = false
	pause_menu.visible = true
	save_dialog.visible = false
	options_dialog.visible = false
	_save_for_exit = false
	pause_status.text = ""
	pause_state_changed.emit(false)


func open_options() -> void:
	if not _pause_open or options_dialog.visible:
		return
	pause_menu.visible = false
	options_dialog.visible = true
	options_back_button.grab_focus()


func close_options() -> void:
	if not _pause_open or not options_dialog.visible:
		return
	options_dialog.visible = false
	pause_menu.visible = true
	options_button.grab_focus()
	options_closed.emit()


func is_options_visible() -> bool:
	return options_dialog.visible


func set_volume_values(master_volume: float, sfx_volume: float) -> void:
	master_volume_slider.set_value_no_signal(clampf(master_volume, 0.0, 1.0))
	sfx_volume_slider.set_value_no_signal(clampf(sfx_volume, 0.0, 1.0))


func _on_master_volume_changed(value: float) -> void:
	volume_changed.emit(value, sfx_volume_slider.value)


func _on_sfx_volume_changed(value: float) -> void:
	volume_changed.emit(master_volume_slider.value, value)


func _on_volume_drag_ended(_value_changed: bool) -> void:
	volume_preview_requested.emit()


func is_save_confirmation_visible() -> bool:
	return save_dialog.visible


func cancel_save_confirmation() -> void:
	if not _pause_open:
		return
	save_dialog.visible = false
	pause_menu.visible = true
	options_dialog.visible = false
	_save_for_exit = false
	pause_status.text = ""
	save_button.grab_focus()


func show_save_result(success: bool, message: String) -> void:
	if not _pause_open:
		return
	save_dialog.visible = false
	pause_menu.visible = true
	options_dialog.visible = false
	_save_for_exit = false
	pause_status.text = message
	pause_status.modulate = Color("#d9ec70" if success else "#ff9d8d")
	continue_button.grab_focus()


func _open_save_confirmation() -> void:
	if not _pause_open:
		return
	_show_save_confirmation(false)


func _open_exit_confirmation() -> void:
	if not _pause_open:
		return
	_show_save_confirmation(true)


func _show_save_confirmation(exit_after_save: bool) -> void:
	_save_for_exit = exit_after_save
	pause_menu.visible = false
	save_dialog.visible = true
	pause_status.text = ""
	save_heading.text = "Salir del juego" if exit_after_save else "Guardar partida"
	save_question.text = (
		"¿Quieres guardar la partida antes de salir?"
		if exit_after_save
		else "¿Quieres guardar la partida actual?"
	)
	save_accept_button.grab_focus()


func _on_save_accept_pressed() -> void:
	save_confirmed.emit(_save_for_exit)


func _on_save_cancel_pressed() -> void:
	var exit_after_save := _save_for_exit
	if exit_after_save:
		save_cancelled.emit(true)
		return
	cancel_save_confirmation()


func set_interaction_prompt(label: String, available: bool) -> void:
	interaction_prompt.visible = available
	if not available:
		interaction_label.text = ""
		return

	interaction_label.text = (
		label
		if _mobile_build
		else "E / ESPACIO  ·  %s" % label
	)


func set_location(label: String) -> void:
	location_label.text = label.to_upper()


func set_tool(_tool: ToolDefinition, _durability: int) -> void:
	pass


func set_wallet(balance: int) -> void:
	inventory_wallet_label.text = "Monedas  %d" % balance


func set_hunting_mode(active: bool) -> void:
	hunting_cursor.set_active(active)
	hunting_hint.visible = active


func show_notification(message: String) -> void:
	if _notification_tween != null and _notification_tween.is_valid():
		_notification_tween.kill()
	notification_label.text = message
	notification_panel.visible = true
	_notification_tween = create_tween()
	_notification_tween.tween_interval(2.5)
	_notification_tween.tween_callback(notification_panel.hide)


func play_sleep_transition(black_duration: float = 3.0) -> void:
	if _sleep_fade_tween != null and _sleep_fade_tween.is_valid():
		_sleep_fade_tween.kill()
	sleep_fade.visible = true
	sleep_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_sleep_fade_tween = create_tween()
	_sleep_fade_tween.tween_property(
		sleep_fade,
		"color",
		Color(0.0, 0.0, 0.0, 1.0),
		SLEEP_FADE_DURATION
	)
	await _sleep_fade_tween.finished
	await get_tree().create_timer(maxf(black_duration, 0.0)).timeout
	_sleep_fade_tween = create_tween()
	_sleep_fade_tween.tween_property(
		sleep_fade,
		"color",
		Color(0.0, 0.0, 0.0, 0.0),
		SLEEP_FADE_DURATION
	)
	await _sleep_fade_tween.finished
	sleep_fade.visible = false


func set_vitals(
	_health: float,
	_maximum_health: float,
	stamina: float,
	maximum_stamina: float,
	stamina_cap: float,
	thirst: float,
	maximum_thirst: float
) -> void:
	var safe_maximum_stamina := maxf(maximum_stamina, 1.0)
	var safe_stamina_cap := maxf(stamina_cap, safe_maximum_stamina)
	stamina_empty_bar.max_value = safe_stamina_cap
	stamina_empty_bar.value = safe_stamina_cap
	stamina_maximum_bar.max_value = safe_stamina_cap
	stamina_maximum_bar.value = safe_maximum_stamina
	stamina_bar.max_value = safe_stamina_cap
	stamina_bar.value = clampf(stamina, 0.0, safe_stamina_cap)
	stamina_value.text = "%d/%d" % [roundi(stamina), roundi(safe_maximum_stamina)]
	var safe_maximum_thirst := maxf(maximum_thirst, 1.0)
	thirst_bar.max_value = safe_maximum_thirst
	thirst_bar.value = clampf(thirst, 0.0, safe_maximum_thirst)
	thirst_value.text = "%d/%d" % [roundi(thirst), roundi(safe_maximum_thirst)]

	var grow_ratio := maxf(safe_stamina_cap / _stamina_capacity_limit, 1.0)
	var bar_width := _stamina_bar_base_width * grow_ratio
	if not is_equal_approx(stamina_bars_container.custom_minimum_size.x, bar_width):
		stamina_bars_container.custom_minimum_size.x = bar_width
		vitals_panel.offset_right = (
			_vitals_panel_base_right
			+ bar_width
			- _stamina_bar_base_width
		)


func set_temperature(temperature: float) -> void:
	temperature_value.text = "%.1f C" % temperature


func show_merchant(
	merchant: MerchantDefinition,
	merchant_service: MerchantService
) -> void:
	merchant_panel.show_shop(merchant, merchant_service)


func refresh_merchant(message: String) -> void:
	merchant_panel.refresh(message)


func hide_merchant() -> void:
	merchant_panel.hide_shop()


func is_merchant_visible() -> bool:
	return merchant_panel.visible


func show_doctor(doctor: DoctorDefinition) -> void:
	doctor_panel.show_doctor_menu(doctor)


func show_doctor_report(doctor: DoctorDefinition, report: Dictionary) -> void:
	doctor_panel.show_consultation(doctor, report)


func hide_doctor() -> void:
	doctor_panel.hide_consultation()


func is_doctor_visible() -> bool:
	return doctor_panel.visible


func show_planting_context_menu() -> void:
	_show_context_menu(&"plant", "Plantar")


func show_water_context_menu() -> void:
	_show_context_menu(&"drink", "Beber")


func _show_context_menu(action: StringName, label: String) -> void:
	_context_action = action
	planting_context_button.text = label
	var viewport_size := get_viewport_rect().size
	var pointer := get_viewport().get_mouse_position()
	var menu_size := planting_context_menu.get_combined_minimum_size()
	planting_context_menu.position = Vector2(
		clampf(pointer.x + 12.0, 0.0, maxf(viewport_size.x - menu_size.x, 0.0)),
		clampf(pointer.y + 12.0, 0.0, maxf(viewport_size.y - menu_size.y, 0.0))
	)
	planting_context_menu.visible = true
	planting_context_button.grab_focus()


func hide_planting_context_menu() -> void:
	planting_context_menu.visible = false
	_context_action = &""
	planting_context_button.text = "Plantar"


func is_planting_context_visible() -> bool:
	return planting_context_menu.visible


func _on_context_button_pressed() -> void:
	if _context_action == &"drink":
		water_context_drink_requested.emit()
	else:
		planting_context_plant_requested.emit()


func _on_planting_context_menu_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		hide_planting_context_menu()


func show_planting(cell: Vector2i, options: Array[Dictionary]) -> void:
	planting_panel.show_planting(cell, options)


func refresh_planting(message: String) -> void:
	planting_panel.refresh(message)


func hide_planting() -> void:
	planting_panel.hide_panel()


func is_planting_visible() -> bool:
	return planting_panel.visible


func show_blacksmith() -> void:
	blacksmith_panel.show_minigame()


func hide_blacksmith() -> void:
	blacksmith_panel.hide_minigame()


func is_blacksmith_visible() -> bool:
	return blacksmith_panel.visible


func show_inventory() -> void:
	inventory_panel.visible = true
	inventory_close_button.grab_focus()


func hide_inventory() -> void:
	inventory_panel.visible = false


func is_inventory_visible() -> bool:
	return inventory_panel.visible


func show_dialogue_node(
	speaker_name: String,
	speaker_title: String,
	text: String,
	choice_labels: PackedStringArray,
	discovered_choices: int,
	total_choices: int,
	path_depth: int,
	affinity: int
) -> void:
	dialogue_panel.show_node(
		speaker_name,
		speaker_title,
		text,
		choice_labels,
		discovered_choices,
		total_choices,
		path_depth,
		affinity
	)


func show_dialogue_actions(actions: Array) -> void:
	dialogue_panel.show_actions(actions)


func set_dialogue_action_cooldowns(cooldowns: Dictionary) -> void:
	dialogue_panel.set_action_cooldowns(cooldowns)


func show_dialogue_action_result(
	action_label: String,
	category: StringName,
	affinity_delta: int,
	affinity: int,
	response_text: String
) -> void:
	dialogue_panel.show_action_result(
		action_label,
		category,
		affinity_delta,
		affinity,
		response_text
	)


func hide_dialogue() -> void:
	dialogue_panel.hide_panel()


func is_dialogue_visible() -> bool:
	return dialogue_panel.visible


func dialogue_visible_choice_count() -> int:
	return dialogue_panel.visible_choice_count()


func dialogue_visible_action_count() -> int:
	return dialogue_panel.visible_action_count()


func dialogue_visible_affinity() -> int:
	return dialogue_panel.affinity()


func set_inventory_item(item: ItemDefinition, quantity: int) -> void:
	if item == null:
		return

	var item_label := _inventory_labels.get(item.id) as Label
	if quantity <= 0:
		if item_label != null:
			item_label.visible = false
		return

	if item_label == null:
		item_label = Label.new()
		item_label.add_theme_color_override("font_color", item.display_color)
		item_label.add_theme_font_size_override("font_size", 13)
		inventory_list.add_child(item_label)
		_inventory_labels[item.id] = item_label

	item_label.visible = true
	item_label.text = "%s  %d" % [item.label, quantity]


func set_inventory_tool(
	tool: ToolDefinition,
	durability: int,
	owned: bool,
	equipped: bool
) -> void:
	if tool == null:
		return

	var tool_label_in_inventory := _inventory_tool_labels.get(tool.id) as Label
	if tool_label_in_inventory == null:
		tool_label_in_inventory = Label.new()
		tool_label_in_inventory.add_theme_font_size_override("font_size", 13)
		inventory_tools_list.add_child(tool_label_in_inventory)
		_inventory_tool_labels[tool.id] = tool_label_in_inventory

	if not owned:
		tool_label_in_inventory.text = "%s  — no obtenida" % tool.label
		tool_label_in_inventory.add_theme_color_override(
			"font_color",
			Color(0.713725, 0.847059, 0.745098, 0.6)
		)
		return

	var ratio := float(durability) / float(maxi(tool.maximum_durability, 1))
	var equipped_label := "  · equipada" if equipped else ""
	tool_label_in_inventory.text = "%s  %d/%d%s" % [
		tool.label,
		durability,
		tool.maximum_durability,
		equipped_label
	]
	tool_label_in_inventory.add_theme_color_override(
		"font_color",
		Color("#ff9d8d") if ratio <= 0.2 else tool.display_color
	)


func update_debug(info: Dictionary) -> void:
	if not debug_panel.visible:
		return

	debug_fps.text = "FPS"
	debug_fps.tooltip_text = "Fotogramas por segundo"
	debug_fps_value.text = str(int(info.get("fps", 0)))
	var cpu_process_ms := float(info.get("cpu_process_ms", 0.0))
	var cpu_frame_percent := float(info.get("cpu_frame_percent", 0.0))
	debug_cpu_value.text = (
		"%.1f ms · %.0f%%" % [cpu_process_ms, cpu_frame_percent]
		if cpu_process_ms > 0.0
		else "N/D"
	)

	var memory_bytes := float(info.get("memory_bytes", 0.0))
	debug_memory_value.text = (
		"%.1f MB" % (memory_bytes / 1048576.0)
		if memory_bytes > 0.0
		else "N/D"
	)
	var gpu_memory_bytes := float(info.get("gpu_memory_bytes", 0.0))
	var gpu_draw_calls := int(info.get("gpu_draw_calls", 0))
	debug_gpu_value.text = (
		"%.1f MB · %d draws" % [gpu_memory_bytes / 1048576.0, gpu_draw_calls]
		if gpu_memory_bytes > 0.0
		else "%d draws" % gpu_draw_calls
	)
	debug_entities_value.text = str(int(info.get("entities", 0)))
	debug_objects_value.text = str(int(info.get("objects", 0)))
	var area_label := (
		"MINA"
		if info.get("area", &"overworld") != &"overworld"
		else "ALDEA"
	)
	debug_detail.text = "%s · %d casas · %d NPC · %d animales\n%d árboles · %d vetas · %d camino" % [
		area_label,
		int(info.get("houses", 0)),
		int(info.get("npcs", 0)),
		int(info.get("animals", 0)),
		int(info.get("trees", 0)),
		int(info.get("veins", 0)),
		int(info.get("path_tiles", 0))
	]
	debug_particles.text = "%d partículas" % int(info.get("particles", 0))


func _on_mobile_toggle_changed(enabled: bool) -> void:
	mobile_controls_toggled.emit(enabled)


func _on_dialogue_choice_selected(choice_index: int) -> void:
	dialogue_choice_selected.emit(choice_index)


func _on_dialogue_action_selected(action_index: int) -> void:
	dialogue_action_selected.emit(action_index)


func _on_dialogue_close_requested() -> void:
	dialogue_close_requested.emit()


func _on_merchant_buy_requested(offer_id: StringName) -> void:
	merchant_buy_requested.emit(offer_id)


func _on_merchant_sell_requested(offer_id: StringName) -> void:
	merchant_sell_requested.emit(offer_id)


func _on_merchant_close_requested() -> void:
	merchant_close_requested.emit()


func _on_doctor_close_requested() -> void:
	doctor_close_requested.emit()


func _on_doctor_diagnosis_requested() -> void:
	doctor_diagnosis_requested.emit()


func _on_planting_seed_selected(seed_id: StringName) -> void:
	planting_seed_selected.emit(seed_id)


func _on_planting_close_requested() -> void:
	planting_close_requested.emit()


func _on_blacksmith_coin_earned() -> void:
	blacksmith_coin_earned.emit()


func _on_blacksmith_close_requested() -> void:
	blacksmith_close_requested.emit()


func _on_inventory_close_requested() -> void:
	inventory_close_requested.emit()
