extends InteractableActor
class_name ShovelPickupActor

var _focused := false


func configure(world_position: Vector2) -> void:
	position = world_position
	set_interaction_area(GameCatalog.OVERWORLD_AREA_ID)
	set_interaction_active(true)
	queue_redraw()


func interaction_anchor() -> Vector2:
	return global_position + Vector2(0.0, 6.0)


func interaction_distance() -> float:
	return 92.0


func interaction_priority() -> int:
	return 28


func interaction_label() -> String:
	return "Recoger pala"


func set_interaction_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	queue_redraw()


func _draw() -> void:
	_draw_shadow_ellipse(Vector2(0.0, 13.0), Vector2(22.0, 7.0), Color(0.035, 0.08, 0.045, 0.28))
	var handle_start := Vector2(-13.0, -34.0)
	var handle_end := Vector2(4.0, 3.0)
	draw_line(handle_start, handle_end, Color("5d3929"), 7.0, true)
	draw_line(handle_start + Vector2(1.5, 0.0), handle_end + Vector2(1.5, 0.0), Color("a66b3d"), 3.0, true)
	draw_circle(handle_start, 5.0, Color("8b5b35"))

	var blade := PackedVector2Array([
		Vector2(-7.0, -3.0),
		Vector2(10.0, -1.0),
		Vector2(13.0, 14.0),
		Vector2(-11.0, 14.0),
	])
	draw_colored_polygon(blade, Color("a8bdc2"))
	draw_polyline(
		PackedVector2Array([
			Vector2(-7.0, -3.0),
			Vector2(10.0, -1.0),
			Vector2(13.0, 14.0),
			Vector2(-11.0, 14.0),
			Vector2(-7.0, -3.0),
		]),
		Color("516b70"),
		2.0,
		true
	)

	if _focused:
		draw_arc(
			Vector2(0.0, 9.0),
			28.0,
			PI + 0.2,
			TAU - 0.2,
			20,
			Color("f9dd76"),
			3.0
		)


func _draw_shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
