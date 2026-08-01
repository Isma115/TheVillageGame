extends Node
class_name SoundService

const FOOTSTEP_STEP_DISTANCE := 46.0
const FOOTSTEP_STEP_DISTANCE_RUNNING := 62.0
const SETTINGS_PATH := "user://pradera_settings.cfg"
const SFX_BUS := "SFX"

var _footstep_samples: Array[AudioStream]
var _mining_sample: AudioStream
var _anvil_sample: AudioStream
var _ui_click_sample: AudioStream

var _footsteps_player: AudioStreamPlayer
var _mining_player: AudioStreamPlayer
var _anvil_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _footstep_distance := 0.0
var _master_volume := 1.0
var _sfx_volume := 1.0
var _audio_enabled := true


func _ready() -> void:
	_audio_enabled = DisplayServer.get_name() != "headless"
	if not _audio_enabled:
		return
	_footstep_samples = [
		load("res://assets/sounds/footstep00.ogg"),
		load("res://assets/sounds/footstep01.ogg"),
		load("res://assets/sounds/footstep02.ogg"),
		load("res://assets/sounds/footstep03.ogg"),
	]
	_mining_sample = load("res://assets/sounds/mining_hit.wav")
	_anvil_sample = load("res://assets/sounds/anvil_hit.ogg")
	_ui_click_sample = load("res://assets/sounds/ui_click.ogg")
	_footsteps_player = _create_player()
	_mining_player = _create_player()
	_anvil_player = _create_player()
	_ui_player = _create_player()
	_load_settings()
	_apply_master_volume()
	_apply_sfx_volume()


func _exit_tree() -> void:
	if not _audio_enabled:
		return
	_footsteps_player.stop()
	_mining_player.stop()
	_anvil_player.stop()
	_ui_player.stop()


func _create_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = SFX_BUS
	add_child(player)
	return player


func master_volume() -> float:
	return _master_volume


func sfx_volume() -> float:
	return _sfx_volume


func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume()


func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_sfx_volume()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", _master_volume)
	config.set_value("audio", "sfx", _sfx_volume)
	config.save(SETTINGS_PATH)


func _apply_master_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, _master_volume <= 0.001)
	AudioServer.set_bus_volume_db(
		bus,
		linear_to_db(_master_volume) if _master_volume > 0.001 else -80.0
	)


func _apply_sfx_volume() -> void:
	var bus := AudioServer.get_bus_index(SFX_BUS)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, _sfx_volume <= 0.001)
	AudioServer.set_bus_volume_db(
		bus,
		linear_to_db(_sfx_volume) if _sfx_volume > 0.001 else -80.0
	)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_master_volume = clampf(
		float(config.get_value("audio", "master", 1.0)),
		0.0,
		1.0
	)
	_sfx_volume = clampf(
		float(config.get_value("audio", "sfx", 1.0)),
		0.0,
		1.0
	)


func play_mining_hit() -> void:
	if not _audio_enabled:
		return
	_mining_player.stream = _mining_sample
	_mining_player.pitch_scale = 0.95 + randf() * 0.15
	_mining_player.volume_db = -4.0
	_mining_player.play()


func play_anvil_hit() -> void:
	if not _audio_enabled:
		return
	_anvil_player.stream = _anvil_sample
	_anvil_player.pitch_scale = 1.0 + randf() * 0.08
	_anvil_player.volume_db = -3.0
	_anvil_player.play()


func play_ui_click() -> void:
	if not _audio_enabled:
		return
	_ui_player.stream = _ui_click_sample
	_ui_player.pitch_scale = 1.0
	_ui_player.volume_db = -14.0
	_ui_player.play()


func accumulate_footstep(distance: float, running: bool) -> void:
	if not _audio_enabled:
		return
	_footstep_distance += distance
	var step_distance := (
		FOOTSTEP_STEP_DISTANCE_RUNNING if running else FOOTSTEP_STEP_DISTANCE
	)
	if _footstep_distance < step_distance:
		return
	_footstep_distance = 0.0
	var player := _footsteps_player
	player.stream = _footstep_samples[randi() % _footstep_samples.size()]
	player.pitch_scale = 0.92 + randf() * 0.16
	player.volume_db = -10.0 if running else -8.0
	player.play()
