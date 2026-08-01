extends InteractableActor
class_name CropActor

var definition: CropDefinition
var crop_cell := Vector2i(-1, -1)
var _focused := false


func initialize(crop_definition: CropDefinition, world_position: Vector2) -> void:
	definition = crop_definition
	position = world_position
	set_interaction_area(GameCatalog.OVERWORLD_AREA_ID)
	set_interaction_active(true)
	queue_redraw()


func interaction_distance() -> float:
	return 96.0


func interaction_priority() -> int:
	return 20


func interaction_label() -> String:
	if definition == null:
		return "Recoger"
	return "Recoger %s" % definition.label


func set_interaction_focused(focused: bool) -> void:
	if _focused == focused:
		return
	_focused = focused
	queue_redraw()


func _draw() -> void:
	if definition == null or definition.grown_texture == null:
		return

	var render_size := definition.sprite_render_size
	draw_texture_rect(
		definition.grown_texture,
		Rect2(-render_size * 0.5, -render_size + 5.0, render_size, render_size),
		false
	)

	if _focused:
		draw_arc(
			Vector2(0.0, -render_size * 0.45),
			render_size * 0.58,
			PI + 0.22,
			TAU - 0.22,
			24,
			Color("#f9dd76"),
			3.0
		)
