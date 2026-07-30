extends Control
class_name GameBootstrap

@export_file("*.tscn") var game_scene_path := "res://scenes/game.tscn"

@onready var status_label: Label = %LoadingStatus
@onready var progress_bar: ProgressBar = %LoadingProgress
@onready var percent_label: Label = %LoadingPercent
@onready var loading_panel: PanelContainer = %LoadingPanel

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
	_update_progress(0.0, "Preparando recursos")
	set_process(true)


func _process(_delta: float) -> void:
	if not _loading_started:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(game_scene_path, progress)
	var amount := float(progress[0]) if not progress.is_empty() else 0.0

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_update_progress(amount, "Cargando la villa")
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading_started = false
			set_process(false)
			_update_progress(1.0, "Todo listo")
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
	var normalized := clampf(amount, 0.0, 1.0)
	var percentage := roundi(normalized * 100.0)
	progress_bar.value = percentage
	percent_label.text = "%d%%" % percentage
	status_label.text = message


func _show_error(message: String) -> void:
	_loading_started = false
	set_process(false)
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("#db846d"))
	var fill_style := progress_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		var error_fill := fill_style.duplicate() as StyleBoxFlat
		error_fill.bg_color = Color("#db846d")
		progress_bar.add_theme_stylebox_override("fill", error_fill)
	var panel_style := loading_panel.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var error_panel := panel_style.duplicate() as StyleBoxFlat
		error_panel.border_color = Color("#db846d")
		loading_panel.add_theme_stylebox_override("panel", error_panel)
	push_error(message)
