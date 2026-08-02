extends PanelContainer
class_name WoodcuttingPanel

signal coin_earned
signal close_requested

const HITS_PER_COIN := 5
const STRIKE_COOLDOWN := 0.5

@onready var meter: WoodcuttingMeter = %WoodcuttingMeter
@onready var progress_bar: ProgressBar = %WoodcuttingProgress
@onready var status_label: Label = %WoodcuttingStatus
@onready var close_button: Button = %WoodcuttingClose
@onready var cooldown_bar: ProgressBar = %StrikeCooldownBar

var _successful_hits := 0
var _reward_pause := false
var _strike_cooldown := 0.0
var sound_service: SoundService


func _ready() -> void:
	meter.start()
	meter.stop()
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func _input(event: InputEvent) -> void:
	if not visible or _reward_pause:
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		if close_button.get_global_rect().has_point(event.position):
			return
		_on_strike_requested()
		accept_event()
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)
	):
		if close_button.has_focus():
			return
		_on_strike_requested()
		accept_event()


func show_minigame() -> void:
	visible = true
	_successful_hits = 0
	_reward_pause = false
	_strike_cooldown = 0.0
	progress_bar.max_value = HITS_PER_COIN
	progress_bar.value = 0
	cooldown_bar.value = 100.0
	status_label.text = "Haz clic cuando el hacha esté sobre el centro del tocón."
	meter.start()


func hide_minigame() -> void:
	visible = false
	_reward_pause = false
	_strike_cooldown = 0.0
	meter.stop()
	cooldown_bar.value = 100.0


func _process(delta: float) -> void:
	if _strike_cooldown <= 0.0:
		cooldown_bar.value = 100.0
		return
	_strike_cooldown = maxf(0.0, _strike_cooldown - delta)
	cooldown_bar.value = (1.0 - _strike_cooldown / STRIKE_COOLDOWN) * 100.0


func _on_strike_requested() -> void:
	if not visible or _reward_pause or not meter.can_strike():
		return
	if _strike_cooldown > 0.0:
		status_label.text = "Espera medio segundo antes del siguiente golpe."
		return

	_strike_cooldown = STRIKE_COOLDOWN
	cooldown_bar.value = 0.0
	var hit := meter.strike()
	if not hit:
		_successful_hits = 0
		progress_bar.value = _successful_hits
		status_label.text = "Fallo. La barra se ha vaciado. Vuelve a empezar."
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
	status_label.text = "¡Tocón cortado! Has ganado 1 moneda."
	_reset_progress_after_reward()


func _reset_progress_after_reward() -> void:
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree() or not visible:
		return
	_successful_hits = 0
	_reward_pause = false
	progress_bar.value = 0
	meter.randomize_motion()
	status_label.text = "Sigue el movimiento y golpea el centro del tocón."


func _on_close_pressed() -> void:
	close_requested.emit()
