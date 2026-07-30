extends Node2D
class_name HouseActor

var texture: Texture2D
var house_size := 350.0

func configure(data: Dictionary) -> void:
	texture = data["texture"]
	house_size = data["size"]
	position = data["position"]
	queue_redraw()

func _draw() -> void:
	if texture == null:
		return

	draw_texture_rect(
		texture,
		Rect2(-house_size / 2.0, -house_size * 0.87, house_size, house_size),
		false
	)
