extends RefCounted
class_name SaveGameService

const SAVE_PATH := "user://pradera_save.json"
const SAVE_VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(snapshot: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo abrir la ranura de guardado: %s" % error_string(FileAccess.get_open_error()))
		return false

	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"state": snapshot
	}
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


func load_game() -> Dictionary:
	if not has_save():
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo leer la ranura de guardado: %s" % error_string(FileAccess.get_open_error()))
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("La partida guardada no contiene un documento válido.")
		return {}

	var payload := parsed as Dictionary
	if int(payload.get("version", 0)) != SAVE_VERSION:
		push_error("Versión de guardado no compatible.")
		return {}

	var state: Variant = payload.get("state", {})
	if not state is Dictionary:
		push_error("La partida guardada no contiene un estado válido.")
		return {}
	return state as Dictionary
