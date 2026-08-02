extends PanelContainer
class_name CookingSeedExtractionPanel

signal vegetable_selected(vegetable_id: StringName)
signal extraction_finished(vegetable_id: StringName, success: bool)
signal close_requested

const TARGET_CUT_COVERAGE := 60.0

@onready var tomato_button: Button = %CookingTomatoButton
@onready var carrot_button: Button = %CookingCarrotButton
@onready var selected_label: Label = %CookingSelectedVegetable
@onready var meter: CookingSeedExtractionMeter = %CookingSeedExtractionMeter
@onready var progress_bar: ProgressBar = %CookingProgress
@onready var status_label: Label = %CookingStatus
@onready var close_button: Button = %CookingClose

var _options: Array[Dictionary] = []
var _selected_vegetable: StringName = &""
var _cut_coverage := 0.0
var _finished := false


func _ready() -> void:
	tomato_button.pressed.connect(_on_tomato_pressed)
	carrot_button.pressed.connect(_on_carrot_pressed)
	meter.cut_performed.connect(_on_cut_performed)
	close_button.pressed.connect(_on_close_pressed)
	visible = false
	meter.reset()


func set_control_settings(settings) -> void:
	meter.set_control_settings(settings)


func show_menu(options: Array[Dictionary]) -> void:
	_options = options
	_selected_vegetable = &""
	_cut_coverage = 0.0
	_finished = false
	progress_bar.max_value = TARGET_CUT_COVERAGE
	progress_bar.value = 0
	selected_label.text = "Selecciona tomate o zanahoria"
	status_label.text = "Elige un vegetal para empezar. El centro amarillo debe quedar intacto."
	status_label.modulate = Color("f1f4dd")
	meter.reset()
	_refresh_choices()
	visible = true
	if not tomato_button.disabled:
		tomato_button.grab_focus()
	elif not carrot_button.disabled:
		carrot_button.grab_focus()
	else:
		close_button.grab_focus()


func start_vegetable(vegetable_id: StringName) -> void:
	if _finished or _option_quantity(vegetable_id) <= 0:
		return
	_selected_vegetable = vegetable_id
	_cut_coverage = 0.0
	_finished = false
	progress_bar.value = 0
	selected_label.text = "Vegetal: %s" % _option_label(vegetable_id)
	status_label.text = "Mantén pulsado el clic izquierdo, arrastra y suelta para hacer un corte."
	status_label.modulate = Color("f1f4dd")
	tomato_button.disabled = true
	carrot_button.disabled = true
	meter.configure(vegetable_id)


func show_result(message: String, success: bool) -> void:
	status_label.text = message
	status_label.modulate = Color("9be27a") if success else Color("ff9d8d")
	close_button.grab_focus()


func hide_panel() -> void:
	visible = false
	_finished = false
	_selected_vegetable = &""
	meter.stop()


func _refresh_choices() -> void:
	var tomato_quantity := _option_quantity(&"tomato")
	var carrot_quantity := _option_quantity(&"carrot")
	tomato_button.text = "Tomate  ·  %d" % tomato_quantity
	carrot_button.text = "Zanahoria  ·  %d" % carrot_quantity
	tomato_button.disabled = tomato_quantity <= 0
	carrot_button.disabled = carrot_quantity <= 0


func _option_quantity(vegetable_id: StringName) -> int:
	for option in _options:
		if StringName(str(option.get("id", ""))) == vegetable_id:
			return int(option.get("quantity", 0))
	return 0


func _option_label(vegetable_id: StringName) -> String:
	for option in _options:
		if StringName(str(option.get("id", ""))) == vegetable_id:
			return str(option.get("label", vegetable_id))
	return str(vegetable_id).capitalize()


func _on_tomato_pressed() -> void:
	vegetable_selected.emit(&"tomato")


func _on_carrot_pressed() -> void:
	vegetable_selected.emit(&"carrot")


func _on_cut_performed(
	valid: bool,
	hit_center: bool,
	already_cut: bool,
	coverage_gain: float,
	_start: Vector2,
	_end: Vector2
) -> void:
	if _selected_vegetable == &"" or _finished:
		return
	if hit_center:
		_finished = true
		meter.set_outcome(false)
		status_label.text = "Has cortado el centro. El vegetal no puede dar semillas."
		status_label.modulate = Color("ff9d8d")
		extraction_finished.emit(_selected_vegetable, false)
		return
	if already_cut:
		status_label.text = "Esa zona ya está cortada. Corta otra parte del vegetal."
		status_label.modulate = Color("f1f4dd")
		return
	if not valid:
		status_label.text = "Ese gesto no ha atravesado el vegetal. Corta un poco más cerca del borde."
		status_label.modulate = Color("f1f4dd")
		return

	_cut_coverage = minf(TARGET_CUT_COVERAGE, _cut_coverage + maxf(coverage_gain, 0.0))
	progress_bar.value = _cut_coverage
	if _cut_coverage < TARGET_CUT_COVERAGE:
		status_label.text = "¡Corte válido! Vegetal cortado: %.0f%% / %.0f%%." % [
			_cut_coverage,
			TARGET_CUT_COVERAGE
		]
		return

	_finished = true
	meter.set_outcome(true)
	status_label.text = "¡Centro intacto! Preparando tus semillas..."
	status_label.modulate = Color("9be27a")
	extraction_finished.emit(_selected_vegetable, true)


func _on_close_pressed() -> void:
	close_requested.emit()
