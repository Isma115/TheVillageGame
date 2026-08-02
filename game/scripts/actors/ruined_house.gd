extends InteractableActor
class_name RuinedHouseActor

const REPAIR_COST := 750

@export var ruined_texture: Texture2D
@export var repaired_texture: Texture2D
@export var render_size := 420.0

var _repaired := false
var _focused := false


func configure(world_position: Vector2, initially_repaired := false) -> void:
	position = world_position
	_repaired = initially_repaired
	set_interaction_area(GameCatalog.OVERWORLD_AREA_ID)
	set_interaction_active(true)
	queue_redraw()


func is_repaired() -> bool:
	return _repaired


func set_repaired(value: bool) -> void:
	_repaired = value
	queue_redraw()


func collision_key() -> StringName:
	return &"ruined_house"


func collision_rectangle() -> Rect2:
	return Rect2(
		global_position + Vector2(-150.0, -108.0),
		Vector2(300.0, 96.0)
	)


func placement_rectangle() -> Rect2:
	return visual_rectangle().grow(18.0)


func visual_rectangle() -> Rect2:
	return Rect2(
		global_position + Vector2(-render_size * 0.5, -render_size * 0.87),
		Vector2.ONE * render_size
	)


func interaction_anchor() -> Vector2:
	return global_position + Vector2(0.0, 46.0)


func interaction_distance() -> float:
	return 160.0


func interaction_priority() -> int:
	return 24


func interaction_label() -> String:
	return "Entrar en la casa" if _repaired else "Reparar casa (750 monedas)"


func set_interaction_focused(value: bool) -> void:
	if _focused == value:
		return
	_focused = value
	queue_redraw()


func _draw() -> void:
	var texture := repaired_texture if _repaired else ruined_texture
	if texture != null:
		draw_texture_rect(
			texture,
			Rect2(
				-render_size * 0.5,
				-render_size * 0.87,
				 render_size,
				 render_size
			),
			false
		)

	if not _focused:
		return
	draw_arc(
		Vector2(0.0, 8.0),
		126.0,
		PI + 0.18,
		TAU - 0.18,
		28,
		Color("#f9dd76"),
		4.0
	)
