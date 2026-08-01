extends Control
class_name GameBootstrap

@export_file("*.tscn") var game_scene_path := "res://scenes/game.tscn"

@onready var status_label: Label = %LoadingStatus
@onready var progress_bar: ProgressBar = %LoadingProgress

var _loading_started := false


func _ready() -> void:
	set_process(false)
	call_deferred("_begin_loading")


func _begin_loading() -> void:
	var error := ResourceLoader.load_threaded_request(game_scene_path, "PackedScene")
	if error != OK:
		_show_error("No se pudo iniciar la carga del juego (%s)." % error_string(error))
		return

	_loading_started = true
	_update_progress(0.0, "Cargando...")
	set_process(true)


func _process(_delta: float) -> void:
	if not _loading_started:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(game_scene_path, progress)
	var amount := float(progress[0]) if not progress.is_empty() else 0.0

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_update_progress(amount, "Cargando...")
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading_started = false
			set_process(false)
			_update_progress(1.0, "Listo")
			call_deferred("_open_game")
		ResourceLoader.THREAD_LOAD_FAILED:
			_show_error("No se pudieron cargar todos los recursos.")
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_show_error("La escena principal no es un recurso válido.")


func _open_game() -> void:
	var packed_scene := ResourceLoader.load_threaded_get(game_scene_path) as PackedScene
	if packed_scene == null:
		_show_error("La escena principal no se pudo preparar.")
		return

	var error := get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		_show_error("No se pudo abrir el juego (%s)." % error_string(error))


func _update_progress(amount: float, message: String) -> void:
	progress_bar.value = roundi(clampf(amount, 0.0, 1.0) * 100.0)
	status_label.text = message


func _show_error(message: String) -> void:
	_loading_started = false
	set_process(false)
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("#db846d"))
	push_error(message)
