extends Node2D
class_name CropActor

var definition: CropDefinition


func initialize(crop_definition: CropDefinition, world_position: Vector2) -> void:
	definition = crop_definition
	position = world_position
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
