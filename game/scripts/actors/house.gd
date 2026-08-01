extends InteractableActor
class_name HouseActor

var definition: HouseDefinition


func configure(house_definition: HouseDefinition) -> void:
	definition = house_definition
	position = definition.world_position
	set_interaction_area(GameCatalog.OVERWORLD_AREA_ID)
	set_interaction_active(true)
	queue_redraw()


func interaction_anchor() -> Vector2:
	return global_position + Vector2(0.0, 42.0)


func interaction_distance() -> float:
	return 112.0


func interaction_priority() -> int:
	return 20


func interaction_label() -> String:
	return "Entrar en %s" % definition.label if definition != null else "Entrar en la casa"


func _draw() -> void:
	if definition == null or definition.texture == null:
		return

	draw_texture_rect(
		definition.texture,
		Rect2(
			-definition.render_size / 2.0,
			-definition.render_size * 0.87,
			definition.render_size,
			definition.render_size
		),
		false
	)
