extends HarvestableActor
class_name TreeActor

var definition: TreeDefinition
var tree_index := -1
var visual_scale := 1.0
var wood_yield := 0
var is_stump := false
var _feedback_tween: Tween
var _canopy_offsets: Array[Vector2] = []
var _canopy_scales := PackedFloat32Array()


func initialize(
	tree_definition: TreeDefinition,
	world_position: Vector2,
	scale_value: float,
	variant_seed: int,
	index: int
) -> void:
	definition = tree_definition
	position = world_position
	visual_scale = scale_value
	tree_index = index
	is_stump = false
	initialize_harvestable(definition.max_health)

	var random_source := RandomNumberGenerator.new()
	random_source.seed = variant_seed
	wood_yield = random_source.randi_range(definition.yield_min, definition.yield_max)
	_canopy_offsets.clear()
	_canopy_scales.clear()
	for _offset_index in range(6):
		var angle := random_source.randf_range(0.0, TAU)
		var distance := random_source.randf_range(
			definition.canopy_radius * 0.08,
			definition.canopy_radius * 0.42
		)
		_canopy_offsets.append(Vector2.from_angle(angle) * distance)
		_canopy_scales.append(random_source.randf_range(0.72, 1.02))
	queue_redraw()


func collision_key() -> StringName:
	return StringName("tree:%d" % tree_index)


func collision_rectangle() -> Rect2:
	var radius := definition.collision_radius * visual_scale
	var center := global_position + Vector2(0.0, -radius * 0.45)
	return Rect2(center - Vector2(radius, radius), Vector2.ONE * radius * 2.0)


func interaction_anchor() -> Vector2:
	return global_position + Vector2(0.0, -18.0 * visual_scale)


func interaction_distance() -> float:
	return definition.interaction_distance * visual_scale


func interaction_priority() -> int:
	return 10


func interaction_label() -> String:
	return "Talar %s" % definition.label


func can_interact(source: Node2D) -> bool:
	return not is_stump and super.can_interact(source)


func apply_chop(damage: int) -> bool:
	if is_stump:
		return false
	return apply_harvest_damage(damage)


func play_fall(source_position: Vector2) -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()

	var fall_direction := 1.0 if source_position.x < global_position.x else -1.0
	rotation = 0.0
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_QUAD)
	_feedback_tween.set_ease(Tween.EASE_IN)
	_feedback_tween.tween_property(self, "rotation", fall_direction * PI * 0.46, 0.48)
	_feedback_tween.tween_interval(0.10)
	_feedback_tween.tween_callback(_become_stump)


func _on_harvest_hit() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()

	var tilt := 0.055 if tree_index % 2 == 0 else -0.055
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_SINE)
	_feedback_tween.set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "rotation", tilt, 0.06)
	_feedback_tween.tween_property(self, "rotation", -tilt * 0.55, 0.07)
	_feedback_tween.tween_property(self, "rotation", 0.0, 0.09)


func _become_stump() -> void:
	is_stump = true
	rotation = 0.0
	queue_redraw()


func _draw() -> void:
	if definition == null:
		return

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * visual_scale)
	if is_stump:
		_draw_stump()
	elif definition.texture != null:
		_draw_sprite()
	elif definition.visual_style == "pine":
		_draw_pine()
	else:
		_draw_broadleaf()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sprite() -> void:
	var render_size := definition.sprite_render_size
	draw_texture_rect(
		definition.texture,
		Rect2(-render_size * 0.5, -render_size, render_size, render_size),
		false
	)
func _draw_broadleaf() -> void:
	_draw_trunk()
	var canopy_center := Vector2(0.0, -definition.trunk_size.y - definition.canopy_radius * 0.34)
	draw_circle(
		canopy_center + Vector2(0.0, 5.0),
		definition.canopy_radius,
		definition.canopy_dark_color
	)

	for index in range(_canopy_offsets.size()):
		var color := (
			definition.canopy_light_color
			if index < 2
			else definition.canopy_color
		)
		draw_circle(
			canopy_center + _canopy_offsets[index],
			definition.canopy_radius * _canopy_scales[index] * 0.64,
			color
		)

	draw_circle(
		canopy_center + Vector2(-definition.canopy_radius * 0.18, -definition.canopy_radius * 0.30),
		definition.canopy_radius * 0.38,
		Color(definition.canopy_light_color, 0.78)
	)


func _draw_pine() -> void:
	_draw_trunk()
	var radius := definition.canopy_radius
	var top_y := -definition.trunk_size.y - radius * 1.05
	var layers := [
		{
			"top": top_y,
			"bottom": top_y + radius * 1.20,
			"half_width": radius * 0.66,
			"color": definition.canopy_light_color
		},
		{
			"top": top_y + radius * 0.48,
			"bottom": top_y + radius * 1.78,
			"half_width": radius * 0.88,
			"color": definition.canopy_color
		},
		{
			"top": top_y + radius * 0.94,
			"bottom": top_y + radius * 2.18,
			"half_width": radius,
			"color": definition.canopy_dark_color
		}
	]

	for layer in layers:
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(0.0, layer["top"]),
				Vector2(-layer["half_width"], layer["bottom"]),
				Vector2(layer["half_width"], layer["bottom"])
			]),
			layer["color"]
		)


func _draw_trunk() -> void:
	var trunk_rect := Rect2(
		-definition.trunk_size.x / 2.0,
		-definition.trunk_size.y,
		definition.trunk_size.x,
		definition.trunk_size.y
	)
	draw_rect(trunk_rect, definition.trunk_color)
	draw_rect(
		Rect2(
			trunk_rect.position + Vector2(definition.trunk_size.x * 0.56, 3.0),
			Vector2(definition.trunk_size.x * 0.18, definition.trunk_size.y - 6.0)
		),
		definition.trunk_light_color
	)


func _draw_stump() -> void:
	var width := definition.trunk_size.x * 1.08
	var height := 12.0
	draw_rect(Rect2(-width / 2.0, -height, width, height), definition.trunk_color)
	draw_set_transform(Vector2(0.0, -height), 0.0, Vector2(width * 0.50, width * 0.19))
	draw_circle(Vector2.ZERO, 1.0, definition.trunk_light_color)
	draw_circle(Vector2.ZERO, 0.48, definition.trunk_color, false, 0.10)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
