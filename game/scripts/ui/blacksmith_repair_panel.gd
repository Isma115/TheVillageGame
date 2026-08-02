extends PanelContainer
class_name BlacksmithRepairPanel

signal repair_requested(tool_id: StringName)
signal close_requested

@onready var balance_label: Label = %RepairBalance
@onready var tools_list: VBoxContainer = %RepairTools
@onready var status_label: Label = %RepairStatus
@onready var close_button: Button = %RepairClose

var _options: Array[Dictionary] = []
var _balance := 0


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func show_repair(options: Array[Dictionary], balance: int) -> void:
	_options = options
	_balance = maxi(balance, 0)
	status_label.text = "El coste depende del desgaste. Una herramienta rota cuesta 5 monedas."
	status_label.modulate = Color("#d9ec70")
	visible = true
	_refresh_view()
	close_button.grab_focus()


func refresh(
	options: Array[Dictionary],
	balance: int,
	message: String = "",
	success: bool = true
) -> void:
	if not message.is_empty():
		status_label.text = message
		status_label.modulate = Color("#d9ec70") if success else Color("#ff9d8d")
	_options = options
	_balance = maxi(balance, 0)
	_refresh_view()


func hide_repair() -> void:
	visible = false
	_options.clear()
	_balance = 0


func _refresh_view() -> void:
	balance_label.text = "Monedas: %d" % _balance
	_clear_tools()

	if _options.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No hay herramientas disponibles para reparar."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tools_list.add_child(empty_label)
		return

	for option in _options:
		_add_tool_row(option)


func _add_tool_row(option: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 46.0)
	row.add_theme_constant_override("separation", 10)
	tools_list.add_child(row)

	var description := Label.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 13)

	var tool_id := StringName(str(option.get("id", "")))
	var label := str(option.get("label", "Herramienta"))
	var owned := bool(option.get("owned", false))
	var durability := int(option.get("durability", 0))
	var maximum := maxi(int(option.get("maximum_durability", 1)), 1)
	var broken := bool(option.get("broken", false))
	var cost := int(option.get("repair_cost", 0))

	if not owned:
		description.text = "%s  ·  No obtenida" % label
		description.add_theme_color_override(
			"font_color",
			Color(0.713725, 0.847059, 0.745098, 0.6)
		)
	else:
		var condition := "ROTA" if broken else "%d/%d" % [durability, maximum]
		description.text = "%s  ·  %s" % [label, condition]
		description.add_theme_color_override(
			"font_color",
			Color("#ff9d8d") if broken else Color("#f1f4dd")
		)
	row.add_child(description)

	var repair_button := Button.new()
	repair_button.custom_minimum_size = Vector2(142.0, 36.0)
	if not owned:
		repair_button.text = "No disponible"
		repair_button.disabled = true
	elif cost <= 0:
		repair_button.text = "En buen estado"
		repair_button.disabled = true
	else:
		repair_button.text = "Reparar · %d" % cost
		repair_button.disabled = cost > _balance
		repair_button.tooltip_text = (
		"Necesitas %d monedas" % cost
		if repair_button.disabled
		else "Reparar %s" % label
	)
		repair_button.pressed.connect(_on_repair_pressed.bind(tool_id))
	row.add_child(repair_button)


func _clear_tools() -> void:
	for child in tools_list.get_children():
		tools_list.remove_child(child)
		child.queue_free()


func _on_repair_pressed(tool_id: StringName) -> void:
	repair_requested.emit(tool_id)


func _on_close_pressed() -> void:
	close_requested.emit()
