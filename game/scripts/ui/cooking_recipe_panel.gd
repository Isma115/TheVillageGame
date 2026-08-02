extends PanelContainer
class_name CookingRecipePanel

signal recipe_selected(recipe_id: StringName)
signal cooking_finished(recipe_id: StringName, outcome: StringName)
signal close_requested

@onready var salad_button: Button = %CookingSaladButton
@onready var recipe_requirements: Label = %CookingRecipeRequirements
@onready var selected_recipe: Label = %CookingSelectedRecipe
@onready var meter: CookingMeter = %CookingMeter
@onready var status_label: Label = %CookingRecipeStatus
@onready var close_button: Button = %CookingRecipeClose

var _options: Array[Dictionary] = []
var _selected_recipe: StringName = &""
var _finished := false


func _ready() -> void:
	salad_button.pressed.connect(_on_salad_pressed)
	meter.released_in_zone.connect(_on_meter_released)
	close_button.pressed.connect(_on_close_pressed)
	visible = false
	meter.reset()


func set_control_settings(settings) -> void:
	meter.set_control_settings(settings)


func show_menu(options: Array[Dictionary]) -> void:
	_options = options
	_selected_recipe = &""
	_finished = false
	selected_recipe.text = "Selecciona una receta"
	status_label.text = "Mantén pulsado el clic para llenar el medidor. Suelta en amarillo o azul."
	status_label.modulate = Color("f1f4dd")
	meter.reset()
	_refresh_recipe()
	visible = true
	if not salad_button.disabled:
		salad_button.grab_focus()
	else:
		close_button.grab_focus()


func start_recipe(recipe_id: StringName) -> void:
	if _finished or not _recipe_available(recipe_id):
		return
	_selected_recipe = recipe_id
	_finished = false
	selected_recipe.text = "Receta: Ensalada"
	status_label.text = "Carga la barra y suelta en amarillo para una ensalada o en azul para una ensalada perfecta."
	status_label.modulate = Color("f1f4dd")
	salad_button.disabled = true
	meter.configure()


func show_result(message: String, success: bool) -> void:
	status_label.text = message
	status_label.modulate = Color("9be27a") if success else Color("ff9d8d")
	close_button.grab_focus()


func hide_panel() -> void:
	visible = false
	_selected_recipe = &""
	_finished = false
	meter.stop()


func _refresh_recipe() -> void:
	var tomato_quantity := 0
	var carrot_quantity := 0
	var available := false
	for option in _options:
		if StringName(str(option.get("id", ""))) != &"salad":
			continue
		tomato_quantity = int(option.get("tomato", 0))
		carrot_quantity = int(option.get("carrot", 0))
		available = bool(option.get("available", false))
		break

	recipe_requirements.text = (
		"Requiere: 1 tomate  ·  1 zanahoria\nDisponibles: %d tomates  ·  %d zanahorias"
		% [tomato_quantity, carrot_quantity]
	)
	salad_button.text = "Ensalada  ·  tomate + zanahoria"
	salad_button.disabled = not available
	if not available:
		status_label.text = "Necesitas un tomate y una zanahoria para cocinar."


func _recipe_available(recipe_id: StringName) -> bool:
	for option in _options:
		if (
			StringName(str(option.get("id", ""))) == recipe_id
			and bool(option.get("available", false))
		):
			return true
	return false


func _on_salad_pressed() -> void:
	recipe_selected.emit(&"salad")


func _on_meter_released(zone: StringName) -> void:
	if _selected_recipe == &"" or _finished:
		return
	if zone == &"green":
		status_label.text = "Sigues en la zona verde. Continúa cargando y vuelve a soltar."
		status_label.modulate = Color("9be27a")
		return

	_finished = true
	var outcome: StringName = &"perfect"
	if zone == &"yellow":
		outcome = &"normal"
	elif zone == &"red":
		outcome = &"burned"
	meter.set_outcome(outcome)
	if zone == &"blue":
		status_label.text = "¡Punto perfecto! Preparando una ensalada perfecta..."
		status_label.modulate = Color("b8e7ff")
		cooking_finished.emit(_selected_recipe, &"perfect")
	elif zone == &"yellow":
		status_label.text = "¡Bien! Preparando una ensalada..."
		status_label.modulate = Color("fff0a8")
		cooking_finished.emit(_selected_recipe, &"normal")
	else:
		status_label.text = "Se ha quemado. Los ingredientes se han perdido."
		status_label.modulate = Color("ff9d8d")
		cooking_finished.emit(_selected_recipe, &"burned")


func _on_close_pressed() -> void:
	close_requested.emit()
