extends Node2D
class_name PlayerActor

const RUN_CLOUD_DISTANCE := 27.0

var collision_world: CollisionWorld
var input_state: InputState
var velocity := Vector2.ZERO
var facing := Vector2.DOWN
var animation_time := 0.0
var distance_travelled := 0.0
var actor_state := "idle"
var run_clouds: Array[Dictionary] = []
var run_cloud_distance := 0.0
var run_cloud_side := 1.0

func configure(collision: CollisionWorld, controls: InputState) -> void:
	collision_world = collision
	input_state = controls
	position = GameConfig.PLAYER_SPAWN
	queue_redraw()

func update_player(delta: float) -> void:
	if collision_world == null or input_state == null:
		return

	var raw_direction := input_state.direction()
	var direction := raw_direction.normalized() if raw_direction.length_squared() > 0.0 else Vector2.ZERO
	var sprinting := input_state.sprinting() and direction.length_squared() > 0.0
	var speed := GameConfig.RUN_SPEED if sprinting else GameConfig.WALK_SPEED
	var movement := direction * speed * delta
	var collision_result := collision_world.move_circle(position, movement, GameConfig.PLAYER_RADIUS)
	var next_position: Vector2 = collision_result["position"]
	var actual_movement := next_position - position
	var actual_distance := actual_movement.length()

	velocity = actual_movement / delta if delta > 0.0 else Vector2.ZERO
	position = next_position

	if direction.length_squared() > 0.0 and actual_distance > 0.05:
		facing = direction
		distance_travelled += actual_distance
		animation_time += delta * (12.0 if sprinting else 8.0)
		actor_state = "running" if sprinting else "walking"
	else:
		velocity = Vector2.ZERO
		animation_time += delta * 2.2
		actor_state = "idle"

	_update_run_clouds(delta, actor_state == "running", actual_distance)
	queue_redraw()

func _update_run_clouds(delta: float, running: bool, actual_distance: float) -> void:
	for index in range(run_clouds.size() - 1, -1, -1):
		var cloud: Dictionary = run_clouds[index]
		cloud["age"] += delta
		cloud["x"] += cloud["velocity_x"] * delta
		cloud["y"] += cloud["velocity_y"] * delta
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
		"x": position.x + side.x * side_offset + facing.x * backward_offset,
		"y": position.y + 35.0 + side.y * side_offset + facing.y * backward_offset,
		"age": 0.0,
		"life": randf_range(0.38, 0.50),
		"size": randf_range(5.5, 8.0),
		"velocity_x": -facing.x * drift + side.x * randf_range(-2.5, 2.5),
		"velocity_y": -facing.y * drift + side.y * randf_range(-2.5, 2.5) - 7.0
	})

	run_cloud_side *= -1.0

func _draw() -> void:
	_draw_run_clouds()

	var moving := actor_state != "idle"
	var stride := sin(animation_time) * (7.0 if actor_state == "running" else 5.0) if moving else 0.0
	var bob := absf(sin(animation_time)) * -1.6 if moving else sin(animation_time) * 0.6

	draw_set_transform(Vector2(0.0, 12.0), 0.0, Vector2(27.0, 14.0))
	draw_circle(Vector2.ZERO, 1.0, Color(0.086, 0.247, 0.118, 0.23))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)

	# Piernas y zapatos.
	draw_line(Vector2(-7.0, 25.0), Vector2(-8.0 + stride, 39.0), GameConfig.INK_COLOR, 7.0, true)
	draw_line(Vector2(7.0, 25.0), Vector2(8.0 - stride, 39.0), GameConfig.INK_COLOR, 7.0, true)
	draw_line(Vector2(-10.0 + stride, 40.0), Vector2(-3.0 + stride, 40.0), Color("#274f33"), 5.0, true)
	draw_line(Vector2(3.0 - stride, 40.0), Vector2(10.0 - stride, 40.0), Color("#274f33"), 5.0, true)

	# Cuerpo y brazos.
	_draw_round_rect(Rect2(-16.0, -13.0, 32.0, 42.0), Color("#f1f4dd"), Color("#244a30"), 3, 12)
	_draw_round_rect(Rect2(-14.0, -11.0, 28.0, 18.0), Color("#d9ec70"), Color(0, 0, 0, 0), 0, 8)
	draw_line(Vector2(-14.0, -4.0), Vector2(-24.0 - stride * 0.45, 10.0), Color("#f1f4dd"), 6.0, true)
	draw_line(Vector2(14.0, -4.0), Vector2(24.0 + stride * 0.45, 10.0), Color("#f1f4dd"), 6.0, true)

	# Cabeza, pelo y ojos.
	draw_circle(Vector2(0.0, -30.0), 16.0, Color("#ffd8ad"))
	draw_arc(Vector2(0.0, -30.0), 16.0, PI, TAU, 20, Color("#244a30"), 3.0, true)
	draw_arc(Vector2(0.0, -34.0), 14.0, PI, TAU, 20, Color("#c46b45"), 7.0, true)
	var look := Vector2(facing.x * 2.2, facing.y * 1.2)
	draw_circle(Vector2(-5.0, -31.0) + look, 1.8, GameConfig.INK_COLOR)
	draw_circle(Vector2(5.0, -31.0) + look, 1.8, GameConfig.INK_COLOR)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_run_clouds() -> void:
	for cloud in run_clouds:
		var progress: float = cloud["age"] / cloud["life"]
		var fade_in := minf(1.0, progress * 10.0)
		var alpha := (1.0 - progress) * fade_in * 0.56
		var size: float = cloud["size"] * (0.78 + progress * 0.56)
		var cloud_position := Vector2(cloud["x"], cloud["y"])

		draw_circle(cloud_position + Vector2(-size * 0.52, size * 0.08), size * 0.48, Color(1.0, 1.0, 0.96, alpha))
		draw_circle(cloud_position + Vector2.ZERO, size * 0.70, Color(1.0, 1.0, 0.96, alpha))
		draw_circle(cloud_position + Vector2(size * 0.52, size * 0.08), size * 0.45, Color(1.0, 1.0, 0.96, alpha))

func _draw_round_rect(rectangle: Rect2, fill: Color, border: Color, border_width: int, radius: int) -> void:
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
	draw_style_box(style_box, rectangle)
