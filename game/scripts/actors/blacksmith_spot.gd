extends InteractableActor
class_name BlacksmithSpotActor

var _focused := false


func configure(world_position: Vector2) -> void:
	position = world_position
	set_interaction_area(GameCatalog.OVERWORLD_AREA_ID)
	set_interaction_active(true)
	queue_redraw()


func interaction_distance() -> float:
	return 112.0


func interaction_priority() -> int:
	return 80


func interaction_label() -> String:
	return "Trabajar en el yunque"


func set_interaction_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	queue_redraw()


func _draw() -> void:
	if not _focused:
		return
	draw_arc(
		Vector2(0.0, 8.0),
		48.0,
		PI + 0.18,
		TAU - 0.18,
		26,
		Color("#f9dd76"),
		4.0
	)
