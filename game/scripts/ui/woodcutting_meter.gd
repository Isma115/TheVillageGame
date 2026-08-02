extends Control
class_name WoodcuttingMeter

@export var axe_texture: Texture2D
@export var stump_texture: Texture2D
@export_range(0.20, 1.80, 0.01) var axe_speed := 1.20
@export_range(0.04, 0.24, 0.01) var target_half_width := 0.12

const AXE_MIN_PROGRESS := 0.01
const AXE_MAX_PROGRESS := 0.89
const STUMP_SIZE := 190.0
const AXE_SIZE := 166.0
const AXE_ROTATION := -PI * 0.5
const AXE_HEAD_OFFSET_X := -AXE_SIZE * 0.24
const AXE_HEAD_COLLISION_SIZE := Vector2(58.0, 104.0)
const STRIKE_DISTANCE := 162.0
const STRIKE_DOWN_DURATION := 0.07
const STRIKE_RETURN_DURATION := 0.13

var _active := false
var _striking := false
var _axe_progress := 0.18
var _axe_velocity := 0.64
var _strike_offset := 0.0
var _strike_tween: Tween
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_random.randomize()
	set_process(false)
	resized.connect(_on_resized)


func _on_resized() -> void:
	queue_redraw()


func start() -> void:
	_active = true
	_striking = false
	_axe_progress = 0.18
	_strike_offset = 0.0
	_randomize_motion()
	set_process(true)
	queue_redraw()


func stop() -> void:
	_active = false
	_striking = false
	if _strike_tween != null and _strike_tween.is_valid():
		_strike_tween.kill()
	_strike_offset = 0.0
	set_process(false)
	queue_redraw()


func can_strike() -> bool:
	return _active and not _striking


func is_axe_over_target() -> bool:
	var head_collision := _axe_head_collision_rect(STRIKE_DISTANCE)
	return head_collision.intersects(_stump_hit_rect())


func strike() -> bool:
	if not can_strike():
		return false

	var hit := is_axe_over_target()
	_striking = true
	if _strike_tween != null and _strike_tween.is_valid():
		_strike_tween.kill()
	_strike_tween = create_tween()
	_strike_tween.set_trans(Tween.TRANS_QUAD)
	_strike_tween.set_ease(Tween.EASE_IN)
	_strike_tween.tween_property(
		self,
		"_strike_offset",
		STRIKE_DISTANCE,
		STRIKE_DOWN_DURATION
	)
	_strike_tween.set_ease(Tween.EASE_OUT)
	_strike_tween.tween_property(
		self,
		"_strike_offset",
		0.0,
		STRIKE_RETURN_DURATION
	)
	_strike_tween.tween_callback(_finish_strike)
	return hit


func randomize_motion() -> void:
	_randomize_motion()


func _randomize_motion() -> void:
	var speed_multiplier := _random.randf_range(0.88, 1.28)
	_axe_velocity = axe_speed * speed_multiplier
	if _random.randf() < 0.5:
		_axe_velocity *= -1.0


func _finish_strike() -> void:
	_striking = false
	queue_redraw()


func _process(delta: float) -> void:
	if not _active or _striking or delta <= 0.0:
		queue_redraw()
		return

	_axe_progress += _axe_velocity * delta
	if _axe_progress <= AXE_MIN_PROGRESS:
		_axe_progress = AXE_MIN_PROGRESS
		_axe_velocity = absf(_axe_velocity)
	elif _axe_progress >= AXE_MAX_PROGRESS:
		_axe_progress = AXE_MAX_PROGRESS
		_axe_velocity = -absf(_axe_velocity)
	queue_redraw()


func _draw() -> void:
	var panel_rect := Rect2(Vector2(6.0, 8.0), Vector2(maxf(size.x - 12.0, 40.0), maxf(size.y - 16.0, 80.0)))
	draw_rect(panel_rect, Color("#142018"))
	draw_rect(panel_rect.grow(-2.0), Color("#1d3022"))

	var center_x := size.x * 0.5
	var target_width := maxf(size.x * target_half_width * 2.0, 34.0)
	draw_rect(
		Rect2(
			Vector2(center_x - target_width * 0.5, 18.0),
			Vector2(target_width, maxf(size.y - 36.0, 48.0))
		),
		Color(0.94, 0.77, 0.34, 0.10)
	)
	draw_line(
		Vector2(center_x, 18.0),
		Vector2(center_x, maxf(size.y - 24.0, 52.0)),
		Color(0.98, 0.88, 0.52, 0.48),
		2.0
	)

	var stump_rect := Rect2(
		Vector2(center_x - STUMP_SIZE * 0.5, size.y - STUMP_SIZE + 2.0),
		Vector2.ONE * STUMP_SIZE
	)
	if stump_texture != null:
		draw_texture_rect(stump_texture, stump_rect, false)

	var head_x := lerpf(
		AXE_MIN_PROGRESS * size.x,
		AXE_MAX_PROGRESS * size.x,
		(_axe_progress - AXE_MIN_PROGRESS) / (AXE_MAX_PROGRESS - AXE_MIN_PROGRESS)
	)
	if axe_texture != null:
		var axe_center := Vector2(
			head_x - AXE_HEAD_OFFSET_X,
			10.0 + _strike_offset + AXE_SIZE * 0.5
		)
		# La cabeza queda abajo para que sea la primera parte que golpea el tocón.
		draw_set_transform(axe_center, AXE_ROTATION, Vector2.ONE)
		draw_texture_rect(
			axe_texture,
			Rect2(-AXE_SIZE * 0.5, -AXE_SIZE * 0.5, AXE_SIZE, AXE_SIZE),
			false
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _axe_head_collision_rect(strike_offset: float) -> Rect2:
	var head_x := lerpf(
		AXE_MIN_PROGRESS * size.x,
		AXE_MAX_PROGRESS * size.x,
		(_axe_progress - AXE_MIN_PROGRESS) / (AXE_MAX_PROGRESS - AXE_MIN_PROGRESS)
	)
	var head_center := Vector2(
		head_x,
		10.0 + strike_offset + AXE_SIZE * 0.5
	)
	return Rect2(
		head_center - AXE_HEAD_COLLISION_SIZE * 0.5,
		AXE_HEAD_COLLISION_SIZE
	)


func _stump_hit_rect() -> Rect2:
	var center_x := size.x * 0.5
	var target_width := maxf(size.x * target_half_width * 2.0, 34.0)
	return Rect2(
		Vector2(
			center_x - target_width * 0.5,
			size.y - STUMP_SIZE + 16.0
		),
		Vector2(target_width, 80.0)
	)
