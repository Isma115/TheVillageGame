extends InteractableActor
class_name AreaPortalActor

var definition: AreaPortalDefinition
var _focused := false


func configure(portal_definition: AreaPortalDefinition) -> void:
	definition = portal_definition
	position = definition.world_position
	set_interaction_area(definition.source_area_id)
	set_interaction_active(true)
	queue_redraw()


func collision_key() -> StringName:
	return StringName("portal:%s" % definition.id)


func collision_rectangle() -> Rect2:
	return Rect2(global_position + definition.collision_rect.position, definition.collision_rect.size)


func visual_rectangle() -> Rect2:
	return Rect2(global_position + definition.render_rect.position, definition.render_rect.size)


func interaction_anchor() -> Vector2:
	return global_position + definition.interaction_offset


func interaction_distance() -> float:
	return definition.interaction_distance


func interaction_priority() -> int:
	return definition.priority


func interaction_label() -> String:
	return definition.label


func set_interaction_focused(focused: bool) -> void:
	if _focused == focused:
		return
	_focused = focused
	queue_redraw()


func _draw() -> void:
	if definition == null:
		return

	if definition.visual_style == "sprite" and definition.texture != null:
		draw_texture_rect(definition.texture, definition.render_rect, false)
	else:
		_draw_stairs()

	if _focused:
		var radius := minf(definition.render_rect.size.x * 0.28, 54.0)
		draw_arc(
			definition.interaction_offset,
			maxf(radius, 30.0),
			0.0,
			TAU,
			40,
			Color(1.0, 1.0, 1.0, 0.88),
			3.0,
			true
		)


func _draw_stairs() -> void:
	var rectangle := definition.render_rect
	var center_x := rectangle.get_center().x
	var arch_center := Vector2(center_x, rectangle.position.y + rectangle.size.y * 0.43)
	var arch_radius := rectangle.size.x * 0.34
	var dark := Color("#17151a")
	var stone := Color("#514851")
	var stone_light := Color("#71636c")

	draw_circle(arch_center, arch_radius, stone)
	draw_circle(arch_center, arch_radius * 0.76, dark)
	draw_rect(
		Rect2(
			Vector2(arch_center.x - arch_radius, arch_center.y),
			Vector2(arch_radius * 2.0, rectangle.end.y - arch_center.y)
		),
		stone
	)
	draw_rect(
		Rect2(
			Vector2(arch_center.x - arch_radius * 0.76, arch_center.y),
			Vector2(arch_radius * 1.52, rectangle.end.y - arch_center.y)
		),
		dark
	)
	draw_arc(arch_center, arch_radius, PI, TAU, 24, stone_light, 4.0, true)

	var step_width := rectangle.size.x * 0.82
	for step_index in range(3):
		var progress := float(step_index) / 2.0
		var width := step_width * (0.72 + progress * 0.28)
		var step_y := rectangle.end.y - 27.0 + step_index * 10.0
		draw_rect(
			Rect2(Vector2(center_x - width / 2.0, step_y), Vector2(width, 9.0)),
			stone_light.lerp(stone, progress * 0.65)
		)

	draw_circle(
		Vector2(center_x, rectangle.position.y + 16.0),
		5.0,
		Color(definition.accent_color, 0.9)
	)
