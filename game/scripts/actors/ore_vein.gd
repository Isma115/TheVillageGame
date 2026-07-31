extends HarvestableActor
class_name OreVeinActor

const MINERAL_TEXTURE_ATLAS_PATH := "res://assets/mining/mineral-mounds-atlas.png"

var definition: MineralDepositDefinition
var deposit_index := -1
var resource_yield := 0
var _tool_service: ToolService
var _feedback_tween: Tween
var _mineral_texture_atlas: Texture2D


func _ready() -> void:
	_mineral_texture_atlas = ResourceLoader.load(
		MINERAL_TEXTURE_ATLAS_PATH,
		"Texture2D"
	) as Texture2D


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


func set_tool_service(tool_service: ToolService) -> void:
	_tool_service = tool_service


func can_interact(source: Node2D) -> bool:
	return (
		super.can_interact(source)
		and _tool_service != null
		and _tool_service.can_use_capability(&"mine")
	)


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
	var texture_size := Vector2.ONE * mineral.visual_radius * 1.72
	if _mineral_texture_atlas == null:
		draw_circle(Vector2(0.0, 2.0), mineral.visual_radius, mineral.ore_color)
		return
	draw_texture_rect_region(
		_mineral_texture_atlas,
		Rect2(
			Vector2(-texture_size.x * 0.5, -texture_size.y * 0.5 + 3.0),
			texture_size
		),
		_mineral_texture_region(mineral.id),
		Color(1.0, 1.0, 1.0, 1.0),
		false,
		true
	)


func _draw_rubble(mineral: MineralDefinition) -> void:
	var texture_size := Vector2.ONE * mineral.visual_radius * 1.08
	if _mineral_texture_atlas == null:
		draw_circle(Vector2(0.0, 4.0), mineral.visual_radius * 0.82, Color("#6d6470", 0.82))
		return
	draw_texture_rect_region(
		_mineral_texture_atlas,
		Rect2(
			Vector2(-texture_size.x * 0.5, -texture_size.y * 0.5 + 4.0),
			texture_size
		),
		Rect2(1024.0, 512.0, 512.0, 512.0),
		Color(0.72, 0.68, 0.78, 0.82),
		false,
		true
	)


func _mineral_texture_region(mineral_id: StringName) -> Rect2:
	match mineral_id:
		&"coal":
			return Rect2(0.0, 0.0, 512.0, 512.0)
		&"copper":
			return Rect2(512.0, 0.0, 512.0, 512.0)
		&"iron":
			return Rect2(1024.0, 0.0, 512.0, 512.0)
		&"gold":
			return Rect2(0.0, 512.0, 512.0, 512.0)
		&"silver":
			return Rect2(512.0, 512.0, 512.0, 512.0)
		_:
			return Rect2(1024.0, 512.0, 512.0, 512.0)
