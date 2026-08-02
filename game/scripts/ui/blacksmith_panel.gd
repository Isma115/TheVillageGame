extends PanelContainer
class_name BlacksmithPanel

signal coin_earned
signal close_requested

const HITS_PER_COIN := 5
const PICKAXE_BARS := 40
const STRIKE_COOLDOWN := 1.0

@onready var meter: BlacksmithMeter = %BlacksmithMeter
@onready var progress_bar: ProgressBar = %BlacksmithProgress
@onready var status_label: Label = %BlacksmithStatus
@onready var close_button: Button = %BlacksmithClose
@onready var bars_label: Label = %BlacksmithBars
@onready var cooldown_bar: ProgressBar = %StrikeCooldownBar

var _successful_hits := 0
var _reward_pause := false
var _strike_cooldown := 0.0
var sound_service: SoundService
var _control_settings
var bars_completed := 0


func _ready() -> void:
	meter.strike_requested.connect(_on_meter_strike)
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func set_control_settings(settings) -> void:
	_control_settings = settings


func _input(event: InputEvent) -> void:
	if not visible or _reward_pause:
		return
	if _is_strike_event(event):
		if event is InputEventMouseButton:
			if close_button.get_global_rect().has_point(event.position):
				return
		elif close_button.has_focus():
			return
		meter.strike_requested.emit()
		accept_event()


func _is_strike_event(event: InputEvent) -> bool:
	if _control_settings != null:
		if not _control_settings.matches_event(&"minigame_action", event):
			return false
		if event is InputEventKey:
			var key_event := event as InputEventKey
			return key_event.pressed and not key_event.echo
		if event is InputEventMouseButton:
			return (event as InputEventMouseButton).pressed
		return false
	return (
		(
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
			and (event as InputEventMouseButton).pressed
		)
		or (
			event is InputEventKey
			and (event as InputEventKey).pressed
			and not (event as InputEventKey).echo
			and (
				(event as InputEventKey).keycode == KEY_SPACE
				or (event as InputEventKey).keycode == KEY_ENTER
			)
		)
	)


func set_bars_completed(value: int) -> void:
	bars_completed = maxi(value, 0)
	if bars_completed >= PICKAXE_BARS:
		bars_label.text = "¡Pico forjado! Barras completadas: %d" % bars_completed
	else:
		bars_label.text = "Barras forjadas: %d/%d" % [bars_completed, PICKAXE_BARS]


func show_minigame() -> void:
	visible = true
	_successful_hits = 0
	_reward_pause = false
	_strike_cooldown = 0.0
	progress_bar.max_value = HITS_PER_COIN
	progress_bar.value = 0
	status_label.text = "Haz clic cuando la marca blanca esté dentro de la zona verde."
	meter.start()


func hide_minigame() -> void:
	visible = false
	_reward_pause = false
	_strike_cooldown = 0.0
	meter.stop()


func _process(delta: float) -> void:
	if _strike_cooldown <= 0.0:
		cooldown_bar.value = 100.0
		return
	_strike_cooldown = maxf(0.0, _strike_cooldown - delta)
	cooldown_bar.value = (1.0 - _strike_cooldown / STRIKE_COOLDOWN) * 100.0


func _on_meter_strike() -> void:
	if not visible or _reward_pause:
		return
	if _strike_cooldown > 0.0:
		status_label.text = "Espera un momento antes del siguiente golpe."
		return

	_strike_cooldown = STRIKE_COOLDOWN
	cooldown_bar.value = 0.0
	if not meter.is_marker_in_green():
		_successful_hits = maxi(0, _successful_hits - 1)
		progress_bar.value = _successful_hits
		status_label.text = "Fallo. La barra baja. Espera a que la marca blanca entre en verde."
		return

	_successful_hits += 1
	progress_bar.value = _successful_hits
	if sound_service != null:
		sound_service.play_anvil_hit()
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
	meter.randomize_speeds()
	status_label.text = "Sigue el ritmo y golpea dentro de la zona verde."


func _on_close_pressed() -> void:
	close_requested.emit()
