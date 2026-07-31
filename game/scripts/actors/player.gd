extends Node2D
class_name PlayerActor

const RUN_CLOUD_DISTANCE := 27.0
const STAMINA_EXHAUSTION_RECOVERY_RATIO := 0.25

signal vitals_changed(
	health: float,
	maximum_health: float,
	stamina: float,
	maximum_stamina: float
)

@export_category("Directional spritesheet")
@export var sprite_texture: Texture2D
@export_range(1, 64, 1) var sprite_columns := 8
@export_range(1, 64, 1) var sprite_rows := 4
@export var sprite_frame_size := Vector2i(192, 256)
@export_range(1.0, 128.0, 0.1) var sprite_render_width := 62.4
@export_range(0.0, 1.0, 0.01) var sprite_foot_anchor := 0.92
@export_range(0.0, 128.0, 0.5) var sprite_ground_y := 40.0

@onready var camera: Camera2D = %PlayerCamera

var catalog: GameCatalog
var collision_world: CollisionWorld
var input_state: InputState
var velocity := Vector2.ZERO
var facing := Vector2.DOWN
var animation_time := 0.0
var distance_travelled := 0.0
var actor_state: StringName = &"idle"
var run_clouds: Array[Dictionary] = []
var run_cloud_distance := 0.0
var run_cloud_side := 1.0
var body_style: StyleBoxFlat
var shirt_style: StyleBoxFlat
var maximum_health := 100.0
var health := 100.0
var maximum_stamina := 100.0
var stamina := 100.0
var _stamina_exhausted := false


func _ready() -> void:
	body_style = _create_round_style(Color("#f1f4dd"), Color("#244a30"), 3, 12)
	shirt_style = _create_round_style(Color("#d9ec70"), Color.TRANSPARENT, 0, 8)


func initialize(
	game_catalog: GameCatalog,
	world_collision: CollisionWorld,
	controls: InputState
) -> void:
	catalog = game_catalog
	input_state = controls
	maximum_health = catalog.player_max_health
	health = maximum_health
	maximum_stamina = catalog.player_max_stamina
	stamina = maximum_stamina
	_stamina_exhausted = false
	_emit_vitals_changed()

	camera.position = Vector2.ZERO
	camera.zoom = catalog.camera_zoom
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = catalog.camera_follow_strength
	set_world_context(world_collision, catalog.world_rect(), catalog.player_spawn)
	queue_redraw()


func set_world_context(
	world_collision: CollisionWorld,
	camera_bounds: Rect2,
	spawn_position: Vector2
) -> void:
	collision_world = world_collision
	position = spawn_position
	velocity = Vector2.ZERO
	actor_state = &"idle"
	run_clouds.clear()
	run_cloud_distance = 0.0

	camera.limit_left = roundi(camera_bounds.position.x)
	camera.limit_top = roundi(camera_bounds.position.y)
	camera.limit_right = roundi(camera_bounds.end.x)
	camera.limit_bottom = roundi(camera_bounds.end.y)
	camera.position = Vector2.ZERO
	camera.reset_smoothing()

	if input_state != null:
		input_state.reset_virtual_controls()
	queue_redraw()


func update_player(delta: float) -> void:
	if catalog == null or collision_world == null or input_state == null:
		return

	var raw_direction := input_state.direction()
	var direction := raw_direction.normalized() if raw_direction.length_squared() > 0.0 else Vector2.ZERO
	_refresh_stamina_exhaustion_state()
	var has_direction := direction.length_squared() > 0.0
	var wants_sprint := input_state.sprinting() and has_direction
	var sprinting := wants_sprint and can_sprint(delta)
	var exhausted := wants_sprint and _stamina_exhausted
	var speed := catalog.player_run_speed if sprinting else catalog.player_walk_speed
	if exhausted:
		speed = catalog.player_exhausted_speed
	var movement := direction * speed * delta
	var collision_result := collision_world.move_circle(position, movement, catalog.player_radius)
	var next_position: Vector2 = collision_result["position"]
	var actual_movement := next_position - position
	var actual_distance := actual_movement.length()

	velocity = actual_movement / delta if delta > 0.0 else Vector2.ZERO
	position = next_position

	if direction.length_squared() > 0.0 and actual_distance > 0.05:
		facing = direction
		distance_travelled += actual_distance
		animation_time += delta * (12.0 if sprinting else 8.0)
		if sprinting:
			actor_state = &"running"
		elif exhausted:
			actor_state = &"exhausted"
		else:
			actor_state = &"walking"
	else:
		velocity = Vector2.ZERO
		animation_time += delta * 2.2
		actor_state = &"idle"

	advance_vitals(delta, actor_state == &"running")
	_update_run_clouds(delta, actor_state == &"running", actual_distance, actual_movement)
	queue_redraw()


func run_cloud_count() -> int:
	return run_clouds.size()


func stop_movement() -> void:
	velocity = Vector2.ZERO
	actor_state = &"idle"
	run_clouds.clear()
	run_cloud_distance = 0.0
	if input_state != null:
		input_state.reset_virtual_controls()
	queue_redraw()


func rest() -> void:
	if catalog != null:
		maximum_health = catalog.player_max_health
		maximum_stamina = catalog.player_max_stamina
	health = maximum_health
	stamina = maximum_stamina
	_stamina_exhausted = false
	_emit_vitals_changed()


func health_ratio() -> float:
	return clampf(health / maxf(maximum_health, 1.0), 0.0, 1.0)


func stamina_ratio() -> float:
	return clampf(stamina / maxf(maximum_stamina, 1.0), 0.0, 1.0)


func can_sprint(_delta: float) -> bool:
	if catalog == null:
		return stamina > 0.0
	if _stamina_exhausted:
		return false
	return stamina > 0.0


func stamina_exhaustion_threshold() -> float:
	return maximum_stamina * STAMINA_EXHAUSTION_RECOVERY_RATIO


func set_health(value: float) -> void:
	var next_health := clampf(value, 0.0, maximum_health)
	if is_equal_approx(next_health, health):
		return
	health = next_health
	_emit_vitals_changed()


func damage(amount: float) -> float:
	if amount > 0.0:
		set_health(health - amount)
	return health


func heal(amount: float) -> float:
	if amount > 0.0:
		set_health(health + amount)
	return health


func snapshot() -> Dictionary:
	return {
		"health": health,
		"maximum_health": maximum_health,
		"stamina": stamina,
		"maximum_stamina": maximum_stamina,
		"stamina_exhausted": _stamina_exhausted
	}


func restore(snapshot_data: Dictionary) -> void:
	if snapshot_data.is_empty():
		return

	var health_limit := catalog.player_max_health if catalog != null else maximum_health
	var stamina_limit := catalog.player_max_stamina if catalog != null else maximum_stamina
	var stamina_floor := (
		catalog.player_min_stamina_capacity
		if catalog != null
		else 1.0
	)
	maximum_health = clampf(
		float(snapshot_data.get("maximum_health", maximum_health)),
		1.0,
		health_limit
	)
	health = clampf(
		float(snapshot_data.get("health", health)),
		0.0,
		maximum_health
	)
	maximum_stamina = clampf(
		float(snapshot_data.get("maximum_stamina", maximum_stamina)),
		stamina_floor,
		stamina_limit
	)
	stamina = clampf(
		float(snapshot_data.get("stamina", stamina)),
		0.0,
		maximum_stamina
	)
	_stamina_exhausted = bool(
		snapshot_data.get("stamina_exhausted", stamina <= 0.0)
	)
	if stamina <= 0.0:
		_stamina_exhausted = true
	_refresh_stamina_exhaustion_state()
	_emit_vitals_changed()


func advance_vitals(delta: float, running: bool) -> void:
	if catalog == null or delta <= 0.0:
		return

	var previous_health := health
	var previous_maximum_health := maximum_health
	var previous_stamina := stamina
	var previous_maximum_stamina := maximum_stamina
	if running:
		maximum_stamina = maxf(
			catalog.player_min_stamina_capacity,
			maximum_stamina - catalog.stamina_capacity_drain_rate * delta
		)
		stamina = maxf(0.0, stamina - catalog.stamina_drain_rate * delta)
	else:
		stamina = minf(
			maximum_stamina,
			stamina + catalog.stamina_recovery_rate * delta
		)
	stamina = minf(stamina, maximum_stamina)
	_refresh_stamina_exhaustion_state()

	if (
		not is_equal_approx(previous_health, health)
		or not is_equal_approx(previous_maximum_health, maximum_health)
		or not is_equal_approx(previous_stamina, stamina)
		or not is_equal_approx(previous_maximum_stamina, maximum_stamina)
	):
		_emit_vitals_changed()


func _refresh_stamina_exhaustion_state() -> void:
	if stamina <= 0.0:
		_stamina_exhausted = true
	elif (
		_stamina_exhausted
		and stamina >= stamina_exhaustion_threshold()
	):
		_stamina_exhausted = false


func _emit_vitals_changed() -> void:
	vitals_changed.emit(health, maximum_health, stamina, maximum_stamina)


func _update_run_clouds(
	delta: float,
	running: bool,
	actual_distance: float,
	actual_movement: Vector2
) -> void:
	for index in range(run_clouds.size() - 1, -1, -1):
		var cloud: Dictionary = run_clouds[index]
		var cloud_position: Vector2 = cloud["position"]
		var cloud_velocity: Vector2 = cloud["velocity"]
		cloud["age"] += delta
		cloud["position"] = (
			cloud_position
			- actual_movement
			+ cloud_velocity * delta
		)
		if cloud["age"] >= cloud["life"]:
			run_clouds.remove_at(index)

	if not running:
		run_cloud_distance = 0.0
		return

	run_cloud_distance += actual_distance
	while run_cloud_distance >= RUN_CLOUD_DISTANCE:
		run_cloud_distance -= RUN_CLOUD_DISTANCE
		_spawn_run_cloud()


func _spawn_run_cloud() -> void:
	var side := Vector2(-facing.y, facing.x)
	var side_offset := run_cloud_side * 5.5
	var backward_offset := -3.0
	var drift := randf_range(8.0, 14.0)

	run_clouds.append({
		"position": (
			Vector2(0.0, 35.0)
			+ side * side_offset
			+ facing * backward_offset
		),
		"age": 0.0,
		"life": randf_range(0.38, 0.50),
		"size": randf_range(5.5, 8.0),
		"velocity": (
			-facing * drift
			+ side * randf_range(-2.5, 2.5)
			+ Vector2.UP * 7.0
		)
	})

	run_cloud_side *= -1.0


func _draw() -> void:
	if catalog == null:
		return

	_draw_run_clouds()
	if _has_directional_sprite():
		_draw_directional_sprite()
	else:
		_draw_procedural()


func _has_directional_sprite() -> bool:
	var texture_size := sprite_texture.get_size() if sprite_texture != null else Vector2.ZERO
	return (
		sprite_texture != null
		and sprite_columns > 0
		and sprite_rows > 0
		and sprite_frame_size.x > 0
		and sprite_frame_size.y > 0
		and texture_size.x >= sprite_columns * sprite_frame_size.x
		and texture_size.y >= sprite_rows * sprite_frame_size.y
	)


func _draw_directional_sprite() -> void:
	var frame_row := clampi(_direction_row(), 0, sprite_rows - 1)
	var frame_index := _sprite_frame()
	var source_rect := Rect2(
		Vector2(
			frame_index * sprite_frame_size.x,
			frame_row * sprite_frame_size.y
		),
		Vector2(sprite_frame_size.x, sprite_frame_size.y)
	)
	var draw_width := sprite_render_width
	var draw_height := draw_width * float(sprite_frame_size.y) / float(sprite_frame_size.x)
	var destination := Rect2(
		Vector2(-draw_width * 0.5, sprite_ground_y - draw_height * sprite_foot_anchor),
		Vector2(draw_width, draw_height)
	)
	draw_texture_rect_region(sprite_texture, destination, source_rect, Color.WHITE, false, true)


func _direction_row() -> int:
	# The sheet keeps all four cardinal directions explicit, so diagonal movement
	# chooses its dominant axis without mirroring a side-facing frame.
	if absf(facing.y) >= absf(facing.x):
		return 0 if facing.y >= 0.0 else 3 # down/front, up/back
	return 2 if facing.x >= 0.0 else 1 # right, left


func _sprite_frame() -> int:
	if actor_state == &"idle":
		return 0
	return posmod(floori(animation_time), sprite_columns)


func _draw_procedural() -> void:

	var moving := actor_state != &"idle"
	var stride := sin(animation_time) * (7.0 if actor_state == &"running" else 5.0) if moving else 0.0
	var bob := absf(sin(animation_time)) * -1.6 if moving else sin(animation_time) * 0.6

	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)

	# Piernas y zapatos.
	draw_line(Vector2(-7.0, 25.0), Vector2(-8.0 + stride, 39.0), catalog.ink_color, 7.0, true)
	draw_line(Vector2(7.0, 25.0), Vector2(8.0 - stride, 39.0), catalog.ink_color, 7.0, true)
	draw_line(Vector2(-10.0 + stride, 40.0), Vector2(-3.0 + stride, 40.0), Color("#274f33"), 5.0, true)
	draw_line(Vector2(3.0 - stride, 40.0), Vector2(10.0 - stride, 40.0), Color("#274f33"), 5.0, true)

	# Cuerpo y brazos.
	draw_style_box(body_style, Rect2(-16.0, -13.0, 32.0, 42.0))
	draw_style_box(shirt_style, Rect2(-14.0, -11.0, 28.0, 18.0))
	draw_line(Vector2(-14.0, -4.0), Vector2(-24.0 - stride * 0.45, 10.0), Color("#f1f4dd"), 6.0, true)
	draw_line(Vector2(14.0, -4.0), Vector2(24.0 + stride * 0.45, 10.0), Color("#f1f4dd"), 6.0, true)

	# Cabeza, pelo y ojos.
	draw_circle(Vector2(0.0, -30.0), 16.0, Color("#ffd8ad"))
	draw_arc(Vector2(0.0, -30.0), 16.0, 0.0, TAU, 32, Color("#244a30"), 3.0, true)
	draw_arc(Vector2(0.0, -34.0), 14.0, PI, TAU, 20, Color("#c46b45"), 7.0, true)
	var look := Vector2(facing.x * 2.2, facing.y * 1.2)
	draw_circle(Vector2(-5.0, -31.0) + look, 1.8, catalog.ink_color)
	draw_circle(Vector2(5.0, -31.0) + look, 1.8, catalog.ink_color)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_run_clouds() -> void:
	for cloud in run_clouds:
		var progress: float = cloud["age"] / cloud["life"]
		var fade_in := minf(1.0, progress * 10.0)
		var alpha := (1.0 - progress) * fade_in * 0.56
		var size: float = cloud["size"] * (0.78 + progress * 0.56)
		var cloud_position: Vector2 = cloud["position"]
		var color := Color(1.0, 1.0, 0.96, alpha)

		draw_circle(cloud_position + Vector2(-size * 0.52, size * 0.08), size * 0.48, color)
		draw_circle(cloud_position + Vector2(0.0, -size * 0.18), size * 0.70, color)
		draw_circle(cloud_position + Vector2(size * 0.52, size * 0.08), size * 0.45, color)
		draw_set_transform(
			cloud_position + Vector2(0.0, size * 0.18),
			0.0,
			Vector2(size * 0.90, size * 0.42)
		)
		draw_circle(Vector2.ZERO, 1.0, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _create_round_style(
	fill: Color,
	border: Color,
	border_width: int,
	radius: int
) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = fill
	style_box.border_color = border
	style_box.border_width_left = border_width
	style_box.border_width_top = border_width
	style_box.border_width_right = border_width
	style_box.border_width_bottom = border_width
	style_box.corner_radius_top_left = radius
	style_box.corner_radius_top_right = radius
	style_box.corner_radius_bottom_left = radius
	style_box.corner_radius_bottom_right = radius
	return style_box
