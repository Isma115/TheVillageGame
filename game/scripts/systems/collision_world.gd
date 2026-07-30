extends RefCounted
class_name CollisionWorld

const COLLISION_EPSILON := 0.0001
const SPATIAL_CELL_SIZE := 128.0

var bounds := Rect2()
var obstacles: Dictionary = {}
var _obstacle_cells: Dictionary = {}
var _spatial_buckets: Dictionary = {}


func configure(playable_bounds: Rect2, obstacle_rects: Array[Rect2]) -> void:
	bounds = playable_bounds
	set_obstacles(obstacle_rects)


func set_obstacles(obstacle_rects: Array[Rect2]) -> void:
	obstacles.clear()
	_obstacle_cells.clear()
	_spatial_buckets.clear()
	for index in range(obstacle_rects.size()):
		register_obstacle(
			StringName("static:%d" % index),
			obstacle_rects[index]
		)


func register_obstacle(obstacle_id: StringName, rectangle: Rect2) -> void:
	if String(obstacle_id).is_empty() or rectangle.size.x <= 0.0 or rectangle.size.y <= 0.0:
		return
	if obstacles.has(obstacle_id):
		unregister_obstacle(obstacle_id)

	obstacles[obstacle_id] = rectangle
	var occupied_cells := _cells_for_rectangle(rectangle)
	_obstacle_cells[obstacle_id] = occupied_cells
	for cell in occupied_cells:
		var bucket: Array = _spatial_buckets.get(cell, [])
		bucket.append(obstacle_id)
		_spatial_buckets[cell] = bucket


func unregister_obstacle(obstacle_id: StringName) -> void:
	var occupied_cells: Array = _obstacle_cells.get(obstacle_id, [])
	for cell in occupied_cells:
		var bucket: Array = _spatial_buckets.get(cell, [])
		bucket.erase(obstacle_id)
		if bucket.is_empty():
			_spatial_buckets.erase(cell)
		else:
			_spatial_buckets[cell] = bucket
	_obstacle_cells.erase(obstacle_id)
	obstacles.erase(obstacle_id)


func has_obstacle(obstacle_id: StringName) -> bool:
	return obstacles.has(obstacle_id)


func obstacle_count() -> int:
	return obstacles.size()


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

			for obstacle in _obstacles_near_circle(next, radius):
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

		if next.distance_squared_to(before_step) < COLLISION_EPSILON * COLLISION_EPSILON:
			break

	return {
		"position": next,
		"blocked_x": blocked_x,
		"blocked_y": blocked_y
	}


func keep_circle_inside_bounds(current_position: Vector2, radius: float) -> Vector2:
	return Vector2(
		clampf(current_position.x, bounds.position.x + radius, bounds.end.x - radius),
		clampf(current_position.y, bounds.position.y + radius, bounds.end.y - radius)
	)


func _obstacles_near_circle(circle: Vector2, radius: float) -> Array[Rect2]:
	var query_rectangle := Rect2(
		circle - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0
	)
	var nearby: Array[Rect2] = []
	var seen_ids: Dictionary = {}

	for cell in _cells_for_rectangle(query_rectangle):
		var obstacle_ids: Array = _spatial_buckets.get(cell, [])
		for obstacle_id in obstacle_ids:
			if seen_ids.has(obstacle_id):
				continue
			seen_ids[obstacle_id] = true
			if obstacles.has(obstacle_id):
				nearby.append(obstacles[obstacle_id])
	return nearby


func _cells_for_rectangle(rectangle: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var first := Vector2i(
		floori(rectangle.position.x / SPATIAL_CELL_SIZE),
		floori(rectangle.position.y / SPATIAL_CELL_SIZE)
	)
	var safe_end := rectangle.end - Vector2.ONE * COLLISION_EPSILON
	var last := Vector2i(
		floori(safe_end.x / SPATIAL_CELL_SIZE),
		floori(safe_end.y / SPATIAL_CELL_SIZE)
	)

	for cell_y in range(first.y, last.y + 1):
		for cell_x in range(first.x, last.x + 1):
			cells.append(Vector2i(cell_x, cell_y))
	return cells


func _circle_rect_correction(circle: Vector2, radius: float, rectangle: Rect2):
	var closest := Vector2(
		clampf(circle.x, rectangle.position.x, rectangle.end.x),
		clampf(circle.y, rectangle.position.y, rectangle.end.y)
	)
	var delta := circle - closest
	var distance_squared := delta.length_squared()
	var radius_squared := radius * radius

	if distance_squared >= radius_squared:
		return null

	if distance_squared > COLLISION_EPSILON:
		var distance := sqrt(distance_squared)
		return delta / distance * (radius - distance)

	return _correction_from_inside_rectangle(circle, radius, rectangle)


func _correction_from_inside_rectangle(circle: Vector2, radius: float, rectangle: Rect2) -> Vector2:
	var candidates := [
		{
			"distance": circle.x - rectangle.position.x,
			"correction": Vector2(-(circle.x - rectangle.position.x + radius), 0.0)
		},
		{
			"distance": rectangle.end.x - circle.x,
			"correction": Vector2(rectangle.end.x - circle.x + radius, 0.0)
		},
		{
			"distance": circle.y - rectangle.position.y,
			"correction": Vector2(0.0, -(circle.y - rectangle.position.y + radius))
		},
		{
			"distance": rectangle.end.y - circle.y,
			"correction": Vector2(0.0, rectangle.end.y - circle.y + radius)
		}
	]
	var best: Dictionary = candidates[0]

	for candidate in candidates.slice(1):
		if candidate["distance"] < best["distance"]:
			best = candidate

	return best["correction"]
