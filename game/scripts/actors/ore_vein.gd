extends HarvestableActor
class_name OreVeinActor

var definition: MineralDepositDefinition
var deposit_index := -1
var resource_yield := 0
var _feedback_tween: Tween
var _rock_offsets: Array[Vector2] = []
var _rock_scales := PackedFloat32Array()
var _ore_offsets: Array[Vector2] = []


func initialize(
	deposit_definition: MineralDepositDefinition,
	area_id: StringName,
	variant_seed: int,
	index: int
) -> void:
	definition = deposit_definition
	deposit_index = index
	position = definition.world_position
	initialize_harvestable(definition.mineral.max_health, area_id)

	var random_source := RandomNumberGenerator.new()
	random_source.seed = variant_seed
	resource_yield = random_source.randi_range(
		definition.mineral.yield_min,
		definition.mineral.yield_max
	)
	_rock_offsets.clear()
	_rock_scales.clear()
	_ore_offsets.clear()
	for _rock_index in range(5):
		var angle := random_source.randf_range(0.0, TAU)
		var distance := random_source.randf_range(
			definition.mineral.visual_radius * 0.08,
			definition.mineral.visual_radius * 0.48
		)
		_rock_offsets.append(Vector2.from_angle(angle) * distance)
		_rock_scales.append(random_source.randf_range(0.62, 1.0))
	for _ore_index in range(6):
		var angle := random_source.randf_range(0.0, TAU)
		var distance := random_source.randf_range(
			definition.mineral.visual_radius * 0.12,
			definition.mineral.visual_radius * 0.60
		)
		_ore_offsets.append(Vector2.from_angle(angle) * distance + Vector2.UP * 4.0)
	queue_redraw()


func collision_key() -> StringName:
	return StringName("deposit:%s" % definition.id)


func collision_rectangle() -> Rect2:
	var radius := definition.mineral.collision_radius * definition.visual_scale
	return Rect2(global_position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)


func interaction_anchor() -> Vector2:
	return global_position + Vector2(0.0, -10.0 * definition.visual_scale)


func interaction_distance() -> float:
	return definition.mineral.interaction_distance * definition.visual_scale


func interaction_priority() -> int:
	return 30


func interaction_label() -> String:
	return "Picar %s" % definition.mineral.label


func apply_mining_hit(damage: int) -> bool:
	return apply_harvest_damage(damage)


func _on_harvest_hit() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()

	var tilt := 0.07 if deposit_index % 2 == 0 else -0.07
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_SINE)
	_feedback_tween.set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "rotation", tilt, 0.06)
	_feedback_tween.tween_property(self, "rotation", -tilt * 0.55, 0.07)
	_feedback_tween.tween_property(self, "rotation", 0.0, 0.09)


func _on_harvest_depleted() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()

	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK)
	_feedback_tween.set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2(1.08, 0.76), 0.10)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.18)


func _draw() -> void:
	if definition == null or definition.mineral == null:
		return

	var mineral := definition.mineral
	var radius := mineral.visual_radius
	if is_interaction_focused() and not harvest_depleted:
		draw_arc(
			Vector2.ZERO,
			(radius + 9.0) * definition.visual_scale,
			0.0,
			TAU,
			36,
			Color(1.0, 1.0, 1.0, 0.84),
			2.5,
			true
		)

	draw_set_transform(
		Vector2(4.0, 8.0) * definition.visual_scale,
		0.0,
		Vector2(radius * 0.82, radius * 0.30) * definition.visual_scale
	)
	draw_circle(Vector2.ZERO, 1.0, Color(0.0, 0.0, 0.0, 0.24))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * definition.visual_scale)

	if harvest_depleted:
		_draw_rubble(mineral)
	else:
		_draw_vein(mineral)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_vein(mineral: MineralDefinition) -> void:
	draw_circle(Vector2(0.0, 2.0), mineral.visual_radius * 0.82, mineral.rock_dark_color)
	for index in range(_rock_offsets.size()):
		var color := mineral.rock_color if index % 2 == 0 else mineral.rock_dark_color
		draw_circle(
			_rock_offsets[index],
			mineral.visual_radius * _rock_scales[index] * 0.52,
			color
		)

	for index in range(_ore_offsets.size()):
		var point := _ore_offsets[index]
		var size := mineral.visual_radius * (0.16 if index % 2 == 0 else 0.12)
		var color := mineral.ore_light_color if index < 2 else mineral.ore_color
		draw_colored_polygon(
			PackedVector2Array([
				point + Vector2(0.0, -size),
				point + Vector2(size * 0.62, 0.0),
				point + Vector2(0.0, size),
				point + Vector2(-size * 0.62, 0.0)
			]),
			color
		)


func _draw_rubble(mineral: MineralDefinition) -> void:
	for index in range(_rock_offsets.size()):
		var point := Vector2(
			_rock_offsets[index].x * 1.34,
			absf(_rock_offsets[index].y) * 0.34 + 5.0
		)
		draw_circle(
			point,
			mineral.visual_radius * _rock_scales[index] * 0.26,
			mineral.rock_dark_color.lerp(mineral.rock_color, 0.38)
		)
