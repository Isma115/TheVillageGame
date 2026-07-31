extends PanelContainer
class_name PlantingPanel

signal seed_selected(seed_id: StringName)
signal close_requested

@onready var title_label: Label = %PlantingTitle
@onready var location_label: Label = %PlantingLocation
@onready var options_list: VBoxContainer = %PlantingOptions
@onready var status_label: Label = %PlantingStatus
@onready var close_button: Button = %PlantingClose


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func show_planting(cell: Vector2i, options: Array[Dictionary]) -> void:
	visible = true
	title_label.text = "Plantar"
	location_label.text = "Hueco de césped · casilla %d, %d" % [cell.x, cell.y]
	status_label.text = (
		"Elige una semilla para plantar."
		if not options.is_empty()
		else "No hay semillas registradas en el inventario."
	)
	_clear_options()
	for option in options:
		_add_seed_option(option)
	close_button.grab_focus()


func refresh(message: String) -> void:
	if visible and not message.is_empty():
		status_label.text = message


func hide_panel() -> void:
	visible = false
	_clear_options()


func _add_seed_option(option: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 44.0)
	row.add_theme_constant_override("separation", 8)
	options_list.add_child(row)

	var description := Label.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.text = "%s  ·  disponibles: %d" % [
		str(option.get("label", "Semilla")),
		int(option.get("quantity", 0))
	]
	var option_color: Color = option.get("color", Color("#d9ec70"))
	description.add_theme_color_override(
		"font_color",
		option_color
	)
	description.add_theme_font_size_override("font_size", 14)
	row.add_child(description)

	var plant_button := Button.new()
	plant_button.custom_minimum_size = Vector2(126.0, 36.0)
	plant_button.text = "Plantar"
	plant_button.disabled = int(option.get("quantity", 0)) <= 0
	plant_button.pressed.connect(
		_on_seed_pressed.bind(StringName(str(option.get("id", ""))))
	)
	row.add_child(plant_button)


func _clear_options() -> void:
	for child in options_list.get_children():
		options_list.remove_child(child)
		child.queue_free()


func _on_seed_pressed(seed_id: StringName) -> void:
	seed_selected.emit(seed_id)


func _on_close_pressed() -> void:
	close_requested.emit()
