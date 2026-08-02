extends InteractableActor
class_name WoodcuttingStumpActor

@export var stump_texture: Texture2D
@export var render_size := 190.0

var _focused := false


func configure(world_position: Vector2) -> void:
	position = world_position
	set_interaction_area(GameCatalog.OVERWORLD_AREA_ID)
	set_interaction_active(true)
	queue_redraw()


func collision_key() -> StringName:
	return &"woodcutting_stump"


func collision_rectangle() -> Rect2:
	return Rect2(
		global_position + Vector2(-48.0, -34.0),
		Vector2(96.0, 38.0)
	)


func placement_rectangle() -> Rect2:
	return Rect2(
		global_position + Vector2(-104.0, -58.0),
		Vector2(208.0, 92.0)
	)


func visual_rectangle() -> Rect2:
	return Rect2(
		global_position + Vector2(-render_size * 0.5, -render_size),
		Vector2.ONE * render_size
	)


func interaction_anchor() -> Vector2:
	return global_position + Vector2(0.0, -28.0)


func interaction_distance() -> float:
	return 124.0


func interaction_priority() -> int:
	return 70


func interaction_label() -> String:
	return "Cortar madera"


func set_interaction_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	queue_redraw()


func _draw() -> void:
	if stump_texture != null:
		draw_texture_rect(
			stump_texture,
			Rect2(-render_size * 0.5, -render_size, render_size, render_size),
			false
		)
	if not _focused:
		return
	draw_arc(
		Vector2(0.0, 8.0),
		52.0,
		PI + 0.18,
		TAU - 0.18,
		28,
		Color("#f9dd76"),
		4.0
	)
