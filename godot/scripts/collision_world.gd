extends RefCounted
class_name CollisionWorld

const COLLISION_EPSILON := 0.0001

var bounds_left := GameConfig.EDGE_PADDING
var bounds_top := GameConfig.EDGE_PADDING
var bounds_right := GameConfig.WORLD_WIDTH - GameConfig.EDGE_PADDING
var bounds_bottom := GameConfig.WORLD_HEIGHT - GameConfig.EDGE_PADDING
var obstacles: Array[Dictionary] = []

func _init() -> void:
	for house in GameConfig.houses():
		obstacles.append(_create_house_obstacle(house))

func move_circle(current_position: Vector2, movement: Vector2, radius: float) -> Dictionary:
	var next := current_position
	var distance := movement.length()
	var step_size := maxf(6.0, radius * 0.65)
	var steps := maxi(1, ceili(distance / step_size))
	var step := movement / float(steps)
	var blocked_x := false
	var blocked_y := false

	for _step_index in range(steps):
		var before_step := next
		next += step

		var bounded := keep_circle_inside_bounds(next, radius)
		blocked_x = blocked_x or absf(bounded.x - next.x) > COLLISION_EPSILON
		blocked_y = blocked_y or absf(bounded.y - next.y) > COLLISION_EPSILON
		next = bounded

		for _pass in range(4):
			var corrected := false

			for obstacle in obstacles:
				var correction = _circle_rect_correction(next, radius, obstacle)
				if correction == null:
					continue

				next += correction
				blocked_x = blocked_x or absf(correction.x) > COLLISION_EPSILON
				blocked_y = blocked_y or absf(correction.y) > COLLISION_EPSILON
				corrected = true

			var corrected_bounds := keep_circle_inside_bounds(next, radius)
			blocked_x = blocked_x or absf(corrected_bounds.x - next.x) > COLLISION_EPSILON
			blocked_y = blocked_y or absf(corrected_bounds.y - next.y) > COLLISION_EPSILON
			next = corrected_bounds

			if not corrected:
				break

		if absf(next.x - before_step.x) < COLLISION_EPSILON and absf(next.y - before_step.y) < COLLISION_EPSILON:
			break

	return {
		"position": next,
		"blocked_x": blocked_x,
		"blocked_y": blocked_y
	}

func keep_circle_inside_bounds(current_position: Vector2, radius: float) -> Vector2:
	return Vector2(
		clampf(current_position.x, bounds_left + radius, bounds_right - radius),
		clampf(current_position.y, bounds_top + radius, bounds_bottom - radius)
	)

func _create_house_obstacle(house: Dictionary) -> Dictionary:
	var collision: Dictionary = house["collision"]
	var center_x: float = house["position"].x
	var left := center_x - float(collision["width"]) / 2.0

	return {
		"left": left,
		"top": house["position"].y + float(collision["top"]),
		"right": left + float(collision["width"]),
		"bottom": house["position"].y + float(collision["bottom"])
	}

func _circle_rect_correction(circle: Vector2, radius: float, rectangle: Dictionary):
	var closest_x := clampf(circle.x, rectangle["left"], rectangle["right"])
	var closest_y := clampf(circle.y, rectangle["top"], rectangle["bottom"])
	var delta := circle - Vector2(closest_x, closest_y)
	var distance_squared := delta.length_squared()
	var radius_squared := radius * radius

	if distance_squared >= radius_squared:
		return null

	if distance_squared > COLLISION_EPSILON:
		var distance := sqrt(distance_squared)
		var penetration := radius - distance
		return delta / distance * penetration

	return _correction_from_inside_rectangle(circle, radius, rectangle)

func _correction_from_inside_rectangle(circle: Vector2, radius: float, rectangle: Dictionary) -> Vector2:
	var candidates := [
		{"distance": circle.x - rectangle["left"], "correction": Vector2(-(circle.x - rectangle["left"] + radius), 0.0)},
		{"distance": rectangle["right"] - circle.x, "correction": Vector2(rectangle["right"] - circle.x + radius, 0.0)},
		{"distance": circle.y - rectangle["top"], "correction": Vector2(0.0, -(circle.y - rectangle["top"] + radius))},
		{"distance": rectangle["bottom"] - circle.y, "correction": Vector2(0.0, rectangle["bottom"] - circle.y + radius)}
	]
	var best: Dictionary = candidates[0]

	for candidate in candidates.slice(1):
		if candidate["distance"] < best["distance"]:
			best = candidate

	return best["correction"]
