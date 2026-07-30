extends Node2D
class_name PlayerActor

const RUN_CLOUD_DISTANCE := 27.0

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
	var sprinting := input_state.sprinting() and direction.length_squared() > 0.0
	var speed := catalog.player_run_speed if sprinting else catalog.player_walk_speed
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
		actor_state = &"running" if sprinting else &"walking"
	else:
		velocity = Vector2.ZERO
		animation_time += delta * 2.2
		actor_state = &"idle"

	_update_run_clouds(delta, actor_state == &"running", actual_distance, actual_movement)
	queue_redraw()


func run_cloud_count() -> int:
	return run_clouds.size()


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

	var moving := actor_state != &"idle"
	var stride := sin(animation_time) * (7.0 if actor_state == &"running" else 5.0) if moving else 0.0
	var bob := absf(sin(animation_time)) * -1.6 if moving else sin(animation_time) * 0.6

	draw_set_transform(Vector2(0.0, 12.0), 0.0, Vector2(27.0, 14.0))
	draw_circle(Vector2.ZERO, 1.0, Color(0.086, 0.247, 0.118, 0.23))
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
