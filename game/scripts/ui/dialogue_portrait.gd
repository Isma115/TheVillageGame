extends Control
class_name DialoguePortrait

var _speaker_name := "Aldara"


func set_speaker(speaker_name: String) -> void:
	_speaker_name = speaker_name
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var rectangle := Rect2(Vector2.ZERO, size)
	var center := rectangle.get_center()

	draw_rect(rectangle, Color("#273f32"))
	for line_index in range(5):
		var y := 16.0 + line_index * 24.0
		draw_line(
			Vector2(10.0, y),
			Vector2(size.x - 10.0, y + sin(float(line_index) * 1.7) * 9.0),
			Color(0.851, 0.925, 0.439, 0.08),
			1.5,
			true
		)
	draw_circle(center + Vector2(0.0, 10.0), minf(size.x, size.y) * 0.38, Color("#315f3b"))
	draw_circle(center + Vector2(0.0, -23.0), 25.0, Color("#d9a06f"))
	draw_arc(center + Vector2(0.0, -27.0), 23.0, PI, TAU, 30, Color("#4b4057"), 13.0, true)
	draw_circle(center + Vector2(20.0, -30.0), 10.0, Color("#4b4057"))
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-34.0, 11.0),
			center + Vector2(34.0, 11.0),
			center + Vector2(43.0, 64.0),
			center + Vector2(-43.0, 64.0)
		]),
		Color("#725c9c")
	)
	draw_line(
		center + Vector2(-31.0, 31.0),
		center + Vector2(31.0, 31.0),
		Color("#e0bd63"),
		5.0,
		true
	)
	draw_circle(center + Vector2(-8.0, -22.0), 2.4, Color("#193724"))
	draw_circle(center + Vector2(8.0, -22.0), 2.4, Color("#193724"))
	draw_arc(center + Vector2(0.0, -13.0), 6.0, 0.2, PI - 0.2, 12, Color("#7e493a"), 2.0, true)

	var initial := _speaker_name.left(1).to_upper()
	draw_circle(Vector2(size.x - 23.0, 23.0), 15.0, Color("#d9ec70"))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(size.x - 34.0, 29.0),
		initial,
		HORIZONTAL_ALIGNMENT_CENTER,
		22.0,
		14,
		Color("#193724")
	)
