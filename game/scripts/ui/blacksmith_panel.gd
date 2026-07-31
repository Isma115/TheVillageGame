extends PanelContainer
class_name BlacksmithPanel

signal coin_earned
signal close_requested

const HITS_PER_COIN := 5

@onready var meter: BlacksmithMeter = %BlacksmithMeter
@onready var progress_bar: ProgressBar = %BlacksmithProgress
@onready var status_label: Label = %BlacksmithStatus
@onready var close_button: Button = %BlacksmithClose

var _successful_hits := 0
var _reward_pause := false


func _ready() -> void:
	meter.strike_requested.connect(_on_meter_strike)
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func show_minigame() -> void:
	visible = true
	_successful_hits = 0
	_reward_pause = false
	progress_bar.max_value = HITS_PER_COIN
	progress_bar.value = 0
	status_label.text = "Haz clic cuando la marca blanca esté dentro de la zona verde."
	meter.start()
	meter.grab_focus()


func hide_minigame() -> void:
	visible = false
	_reward_pause = false
	meter.stop()


func _on_meter_strike() -> void:
	if not visible or _reward_pause:
		return

	if not meter.is_marker_in_green():
		status_label.text = "Fallo. Espera a que la marca blanca entre en verde."
		return

	_successful_hits += 1
	progress_bar.value = _successful_hits
	if _successful_hits < HITS_PER_COIN:
		status_label.text = "¡Acierto! %d/%d golpes para ganar una moneda." % [
			_successful_hits,
			HITS_PER_COIN
		]
		return

	_reward_pause = true
	coin_earned.emit()
	status_label.text = "¡Trabajo perfecto! Has ganado 1 moneda."
	_reset_progress_after_reward()


func _reset_progress_after_reward() -> void:
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree() or not visible:
		return
	_successful_hits = 0
	_reward_pause = false
	progress_bar.value = 0
	status_label.text = "Sigue el ritmo y golpea dentro de la zona verde."


func _on_close_pressed() -> void:
	close_requested.emit()
