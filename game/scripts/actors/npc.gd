extends InteractableActor
class_name NpcActor

var definition: NpcDefinition
var _focused := false
var _idle_time := 0.0
var _look_direction := Vector2.DOWN
var _nameplate_style: StyleBoxFlat
var _speech_style: StyleBoxFlat


func _ready() -> void:
	_nameplate_style = _make_style(
		Color(0.094, 0.173, 0.114, 0.94),
		Color(0.851, 0.925, 0.439, 0.82),
		2,
		8
	)
	_speech_style = _make_style(
		Color("#f1f4dd"),
		Color("#193724"),
		2,
		10
	)


func configure(npc_definition: NpcDefinition) -> void:
	definition = npc_definition
	position = definition.world_position
	set_interaction_area(definition.area_id)
	queue_redraw()


func interaction_anchor() -> Vector2:
	return global_position + Vector2(0.0, -4.0)


func interaction_distance() -> float:
	return definition.interaction_distance if definition != null else 96.0


func interaction_priority() -> int:
	return 40


func interaction_label() -> String:
	if definition == null:
		return "Hablar"
	if definition.doctor != null:
		return "Consultar con %s" % definition.display_name
	if definition.merchant != null:
		return "Comerciar con %s" % definition.display_name
	return "Hablar con %s" % definition.display_name


func collision_key() -> StringName:
	return (
		StringName("npc:%s" % definition.id)
		if definition != null
		else StringName("npc:%d" % get_instance_id())
	)


func collision_rectangle() -> Rect2:
	if definition == null:
		return Rect2(global_position + Vector2(-15.0, 13.0), Vector2(30.0, 20.0))
	return definition.world_collision_rect()


func placement_rectangle() -> Rect2:
	if definition == null:
		return Rect2(global_position + Vector2(-48.0, -58.0), Vector2(96.0, 104.0))
	return definition.world_placement_rect()


func interact(source: Node2D) -> void:
	if source != null:
		var offset := source.global_position - global_position
		if offset.length_squared() > 0.01:
			_look_direction = offset.normalized()
			queue_redraw()
	super.interact(source)


func set_interaction_focused(focused: bool) -> void:
	if _focused == focused:
		return
	_focused = focused
	queue_redraw()


func _process(delta: float) -> void:
	_idle_time += delta
	queue_redraw()


func _draw() -> void:
	if definition == null:
		return

	var bob := sin(_idle_time * 2.1) * 0.65
	var blink := fmod(_idle_time, 4.7) > 4.54
	var eye_height := 0.45 if blink else 1.8
	var eye_offset := Vector2(
		clampf(_look_direction.x * 1.7, -1.7, 1.7),
		clampf(_look_direction.y * 0.8, -0.8, 0.8)
	)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0.0, 28.0), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 18.0, Color(0.067, 0.137, 0.086, 0.30))

	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)

	# Botas y falda de viaje.
	draw_line(Vector2(-7.0, 18.0), Vector2(-8.0, 29.0), Color("#253d31"), 7.0, true)
	draw_line(Vector2(7.0, 18.0), Vector2(8.0, 29.0), Color("#253d31"), 7.0, true)
	draw_line(Vector2(-12.0, 30.0), Vector2(-4.0, 30.0), Color("#193724"), 5.0, true)
	draw_line(Vector2(4.0, 30.0), Vector2(12.0, 30.0), Color("#193724"), 5.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-15.0, -9.0),
			Vector2(15.0, -9.0),
			Vector2(18.0, 20.0),
			Vector2(-18.0, 20.0)
		]),
		definition.clothing_color
	)
	draw_polyline(
		PackedVector2Array([
			Vector2(-15.0, -9.0),
			Vector2(15.0, -9.0),
			Vector2(18.0, 20.0),
			Vector2(-18.0, 20.0),
			Vector2(-15.0, -9.0)
		]),
		Color("#193724"),
		2.5,
		true
	)
	draw_line(Vector2(-13.0, 4.0), Vector2(13.0, 4.0), definition.accent_color, 4.0, true)
	if definition.doctor != null:
		draw_line(Vector2(-6.0, 11.0), Vector2(6.0, 11.0), definition.accent_color, 3.0, true)
		draw_line(Vector2(0.0, 5.0), Vector2(0.0, 17.0), definition.accent_color, 3.0, true)

	# Brazos, cuaderno y tubo de mapas.
	draw_line(Vector2(-14.0, -5.0), Vector2(-23.0, 9.0), definition.skin_color, 6.0, true)
	draw_line(Vector2(14.0, -5.0), Vector2(21.0, 8.0), definition.skin_color, 6.0, true)
	draw_rect(Rect2(-27.0, 7.0, 13.0, 17.0), Color("#e8ddbd"), true)
	draw_rect(Rect2(-27.0, 7.0, 13.0, 17.0), Color("#193724"), false, 2.0)
	draw_line(Vector2(18.0, -4.0), Vector2(25.0, 24.0), definition.accent_color, 6.0, true)
	draw_circle(Vector2(18.0, -4.0), 3.0, Color("#193724"))
	draw_circle(Vector2(25.0, 24.0), 3.0, Color("#193724"))

	# Cabeza, pelo recogido y rostro.
	draw_circle(Vector2(0.0, -27.0), 15.5, definition.skin_color)
	draw_arc(Vector2(0.0, -27.0), 15.5, 0.0, TAU, 32, Color("#193724"), 2.5, true)
	draw_arc(
		Vector2(0.0, -31.0),
		14.0,
		PI,
		TAU,
		24,
		definition.hair_color,
		8.5,
		true
	)
	draw_circle(Vector2(13.5, -31.0), 6.5, definition.hair_color)
	draw_line(
		Vector2(-5.0, -27.0) + eye_offset,
		Vector2(-5.0, -27.0) + eye_offset + Vector2(0.0, eye_height),
		Color("#193724"),
		2.0,
		true
	)
	draw_line(
		Vector2(5.0, -27.0) + eye_offset,
		Vector2(5.0, -27.0) + eye_offset + Vector2(0.0, eye_height),
		Color("#193724"),
		2.0,
		true
	)
	draw_arc(Vector2(0.0, -22.0), 4.0, 0.25, PI - 0.25, 10, Color("#7e493a"), 1.5, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _focused:
		_draw_focus_marker()


func _draw_focus_marker() -> void:
	var name_text := definition.display_name
	draw_style_box(_nameplate_style, Rect2(-55.0, -82.0, 110.0, 24.0))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-49.0, -65.0),
		name_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		98.0,
		12,
		Color("#f1f4dd")
	)
	draw_style_box(_speech_style, Rect2(29.0, -54.0, 33.0, 25.0))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(33.0, -36.0),
		"…",
		HORIZONTAL_ALIGNMENT_CENTER,
		25.0,
		16,
		Color("#193724")
	)


func _make_style(
	fill: Color,
	border: Color,
	border_width: int,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
