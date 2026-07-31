extends InteractableActor
class_name RestSpotActor

var _focused := false
var _visual_offset := Vector2(0.0, -110.0)

func configure(area_id: StringName, interaction_position: Vector2, visual_position: Vector2) -> void:
	position = interaction_position
	_visual_offset = visual_position - interaction_position
	set_interaction_area(area_id)
	set_interaction_active(true)
	queue_redraw()

func interaction_distance() -> float:
	return 112.0

func interaction_priority() -> int:
	return 95

func interaction_label() -> String:
	return "Dormir en el hotel"

func set_interaction_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	queue_redraw()

func _draw() -> void:
	var center := _visual_offset
	var bed := Rect2(center + Vector2(-100.0, -65.0), Vector2(200.0, 130.0))
	draw_rect(bed, Color("4d3541"))
	draw_rect(Rect2(bed.position + Vector2(8.0, 8.0), bed.size - Vector2(16.0, 16.0)), Color("c98b9e"))
	draw_rect(Rect2(bed.position + Vector2(14.0, 14.0), Vector2(172.0, 36.0)), Color("f1e7dc"))
	draw_rect(Rect2(bed.position + Vector2(14.0, 55.0), Vector2(172.0, 57.0)), Color("e2b0be"))
	draw_line(Vector2(bed.position.x + 20.0, bed.end.y - 10.0), Vector2(bed.end.x - 20.0, bed.end.y - 10.0), Color("6b4652"), 3.0)
	draw_rect(Rect2(center + Vector2(113.0, -18.0), Vector2(20.0, 36.0)), Color("6a4a3b"))
	draw_circle(center + Vector2(123.0, -25.0), 13.0, Color("ffe09b"))
	if _focused:
		draw_arc(center + Vector2(0.0, 72.0), 62.0, PI + 0.25, TAU - 0.25, 24, Color("f9dd76"), 4.0)
