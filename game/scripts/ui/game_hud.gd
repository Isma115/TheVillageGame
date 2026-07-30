extends Control
class_name GameHud

signal mobile_controls_toggled(enabled: bool)
signal pause_state_changed(paused: bool)
signal save_confirmed(exit_after_save: bool)
signal save_cancelled(exit_after_save: bool)

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
@onready var inventory_list: VBoxContainer = %InventoryList
@onready var pause_overlay: Control = %PauseOverlay
@onready var pause_menu: PanelContainer = %PauseMenu
@onready var save_dialog: PanelContainer = %SaveDialog
@onready var save_heading: Label = %SaveHeading
@onready var save_question: Label = %SaveQuestion
@onready var pause_status: Label = %PauseStatus
@onready var continue_button: Button = %ContinueButton
@onready var save_button: Button = %SaveButton
@onready var exit_button: Button = %ExitButton
@onready var save_accept_button: Button = %SaveAcceptButton
@onready var save_cancel_button: Button = %SaveCancelButton

var _mobile_build := false
var _inventory_labels: Dictionary = {}
var _pause_open := false
var _save_for_exit := false


func _ready() -> void:
	mobile_toggle.toggled.connect(_on_mobile_toggle_changed)
	continue_button.pressed.connect(resume_game)
	save_button.pressed.connect(_open_save_confirmation)
	exit_button.pressed.connect(_open_exit_confirmation)
	save_accept_button.pressed.connect(_on_save_accept_pressed)
	save_cancel_button.pressed.connect(_on_save_cancel_pressed)


func initialize(mobile_build: bool) -> void:
	_mobile_build = mobile_build
	debug_panel.visible = not mobile_build
	_pause_open = false
	_save_for_exit = false
	pause_overlay.visible = false
	pause_menu.visible = true
	save_dialog.visible = false
	pause_status.text = ""
	interaction_prompt.visible = false
	mobile_toggle.set_pressed_no_signal(false)


func open_pause_menu() -> void:
	if _pause_open:
		return
	_pause_open = true
	pause_overlay.visible = true
	pause_menu.visible = true
	save_dialog.visible = false
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
	_save_for_exit = false
	pause_status.text = ""
	pause_state_changed.emit(false)


func is_save_confirmation_visible() -> bool:
	return save_dialog.visible


func cancel_save_confirmation() -> void:
	if not _pause_open:
		return
	save_dialog.visible = false
	pause_menu.visible = true
	_save_for_exit = false
	pause_status.text = ""
	save_button.grab_focus()


func show_save_result(success: bool, message: String) -> void:
	if not _pause_open:
		return
	save_dialog.visible = false
	pause_menu.visible = true
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


func set_inventory_item(item: ItemDefinition, quantity: int) -> void:
	if item == null:
		return

	var item_label := _inventory_labels.get(item.id) as Label
	if item_label == null:
		item_label = Label.new()
		item_label.add_theme_color_override("font_color", item.display_color)
		item_label.add_theme_font_size_override("font_size", 13)
		inventory_list.add_child(item_label)
		_inventory_labels[item.id] = item_label

	item_label.text = "%s  %d" % [item.label, quantity]


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
	debug_detail.text = "%s · %d casas · %d animales\n%d árboles · %d vetas · %d camino" % [
		area_label,
		int(info.get("houses", 0)),
		int(info.get("animals", 0)),
		int(info.get("trees", 0)),
		int(info.get("veins", 0)),
		int(info.get("path_tiles", 0))
	]
	debug_particles.text = "%d partículas" % int(info.get("particles", 0))


func _on_mobile_toggle_changed(enabled: bool) -> void:
	mobile_controls_toggled.emit(enabled)
