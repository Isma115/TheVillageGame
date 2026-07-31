extends Node2D
class_name AnimalActor

const IDLE := &"idle"

var definition: AnimalDefinition
var collision_world: CollisionWorld
var playable_bounds := Rect2()
var home_position := Vector2.ZERO
var target_position := Vector2.ZERO
var facing := Vector2.RIGHT
var state: StringName = IDLE
var animation_time := 0.15
var behavior_time := 0.0
var behavior_duration := 3.0
var random_source := RandomNumberGenerator.new()
var hunting_health := 1


func initialize(
	 animal_definition: AnimalDefinition,
	 world_collision: CollisionWorld,
	 world_bounds: Rect2,
	 spawn_position: Vector2
) -> void:
	definition = animal_definition
	collision_world = world_collision
	playable_bounds = world_bounds
	position = spawn_position
	home_position = position
	target_position = position
	facing = definition.initial_direction.normalized()
	if facing.is_zero_approx():
		facing = Vector2.RIGHT
	hunting_health = definition.hunting_health
	random_source.seed = definition.random_seed
	_choose_behavior()
	queue_redraw()


func hunting_target_position() -> Vector2:
	if definition == null:
		return global_position
	var frame_size := Vector2(definition.frame_size)
	var draw_height := definition.render_width * frame_size.y / maxf(frame_size.x, 1.0)
	return global_position + Vector2(0.0, -draw_height * 0.36)


func hunting_hit_radius() -> float:
	if definition == null:
		return 16.0
	return maxf(
		definition.collision_radius * 1.25,
		definition.render_width * 0.42
	)


func contains_hunting_point(world_point: Vector2) -> bool:
	return world_point.distance_to(hunting_target_position()) <= hunting_hit_radius()


func take_hunting_damage(damage: int = 1) -> bool:
	if definition == null or damage <= 0 or hunting_health <= 0:
		return false
	hunting_health = maxi(0, hunting_health - damage)
	return hunting_health <= 0


func update_animal(delta: float) -> void:
	if definition == null or definition.texture == null or delta <= 0.0:
		return

	animation_time += delta
	behavior_time += delta
	if behavior_time >= behavior_duration:
		_choose_behavior()

	if state != IDLE:
		_move(delta)
	queue_redraw()


func _choose_behavior() -> void:
	var weights := definition.behavior_weights()
	var total := 0.0
	for weight in weights.values():
		total += maxf(0.0, float(weight))

	var cursor := random_source.randf() * maxf(total, 1.0)
	var next_state: StringName = IDLE
	for behavior in weights.keys():
		cursor -= maxf(0.0, float(weights[behavior]))
		if cursor <= 0.0:
			next_state = StringName(behavior)
			break

	state = next_state
	behavior_time = 0.0
	var duration_range := definition.duration_for_state(state)
	behavior_duration = random_source.randf_range(duration_range.x, duration_range.y)
	if state != IDLE:
		target_position = _random_target()


func _move(delta: float) -> void:
	var to_target := target_position - position
	if to_target.length() < 14.0 or behavior_time > behavior_duration * 0.88:
		target_position = _random_target()
		to_target = target_position - position

	if to_target.length_squared() <= 0.0001:
		return

	var direction := to_target.normalized()
	var movement := direction * definition.speed_for_state(state) * delta
	var next_position: Vector2

	if definition.collides_with_world:
		var collision_result := collision_world.move_circle(position, movement, definition.collision_radius)
		next_position = collision_result["position"]
	else:
		next_position = _keep_inside_world(position + movement, definition.collision_radius)

	var actual_movement := next_position - position
	position = next_position
	if actual_movement.length() > 0.05:
		facing = actual_movement.normalized()


func _random_target() -> Vector2:
	var angle := random_source.randf_range(0.0, TAU)
	var distance := definition.wander_radius * random_source.randf_range(0.35, 1.0)
	return _keep_inside_world(
		home_position + Vector2.from_angle(angle) * distance,
		definition.collision_radius
	)


func _keep_inside_world(candidate: Vector2, radius: float) -> Vector2:
	return Vector2(
		clampf(candidate.x, playable_bounds.position.x + radius, playable_bounds.end.x - radius),
		clampf(candidate.y, playable_bounds.position.y + radius, playable_bounds.end.y - radius)
	)


func _draw() -> void:
	if definition == null or definition.texture == null:
		return

	var row := definition.animation_row_for_state(state)
	var fps := definition.animation_fps_for_state(state)
	var frame := posmod(floori(animation_time * fps), definition.sprite_columns)
	var frame_size := Vector2(definition.frame_size)
	var source_rect := Rect2(
		Vector2(frame * definition.frame_size.x, row * definition.frame_size.y),
		frame_size
	)
	var draw_width := definition.render_width
	var draw_height := draw_width * frame_size.y / frame_size.x
	var progress := minf(1.0, behavior_time / maxf(behavior_duration, 0.001))
	var jump_offset := (
		-sin(progress * PI) * definition.jump_height
		if state == &"jumping"
		else 0.0
	)
	var hover_offset := (
		sin(animation_time * 2.1) * definition.hover_height
		if not definition.grounded
		else 0.0
	)

	if definition.casts_shadow:
		draw_set_transform(Vector2(0.0, 5.0), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, draw_width * 0.23, Color(0.086, 0.247, 0.118, 0.18))

	var flip := -1.0 if facing.x < -0.05 else 1.0
	draw_set_transform(Vector2(0.0, jump_offset + hover_offset), 0.0, Vector2(flip, 1.0))
	draw_texture_rect_region(
		definition.texture,
		Rect2(
			-draw_width / 2.0,
			-draw_height * definition.anchor_y,
			draw_width,
			draw_height
		),
		source_rect
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
