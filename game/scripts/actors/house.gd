extends Node2D
class_name HouseActor

var definition: HouseDefinition


func configure(house_definition: HouseDefinition) -> void:
	definition = house_definition
	position = definition.world_position
	queue_redraw()


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
