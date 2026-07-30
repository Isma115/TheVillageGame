extends Control
class_name GameHud

signal mobile_controls_toggled(enabled: bool)

@onready var debug_panel: PanelContainer = %DebugPanel
@onready var debug_fps: Label = %DebugFps
@onready var debug_fps_value: Label = %DebugFpsValue
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

var _mobile_build := false
var _inventory_labels: Dictionary = {}


func _ready() -> void:
	mobile_toggle.toggled.connect(_on_mobile_toggle_changed)


func initialize(mobile_build: bool) -> void:
	_mobile_build = mobile_build
	debug_panel.visible = not mobile_build
	interaction_prompt.visible = false
	mobile_toggle.set_pressed_no_signal(false)


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

	var memory_bytes := float(info.get("memory_bytes", 0.0))
	debug_memory_value.text = (
		"%.1f MB" % (memory_bytes / 1048576.0)
		if memory_bytes > 0.0
		else "N/D"
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
