extends Node2D
class_name PlantingPlotActor

const SOWN_SOIL_TEXTURE_PATH := "res://assets/crops/soil-sown.png"

var remaining_time := 0.0
var growth_duration := 1.0
var growth_ratio := 0.0
var _sown_soil_texture: Texture2D


func _ready() -> void:
	_sown_soil_texture = ResourceLoader.load(
		SOWN_SOIL_TEXTURE_PATH,
		"Texture2D"
	) as Texture2D


func initialize(
	world_position: Vector2,
	initial_remaining_time: float,
	initial_growth_duration: float
) -> void:
	position = world_position
	growth_duration = maxf(initial_growth_duration, 1.0)
	set_growth(initial_remaining_time, growth_duration)


func set_growth(next_remaining_time: float, next_growth_duration: float) -> void:
	remaining_time = maxf(next_remaining_time, 0.0)
	growth_duration = maxf(next_growth_duration, 1.0)
	growth_ratio = clampf(1.0 - remaining_time / growth_duration, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var soil_rect := Rect2(-24.0, -24.0, 48.0, 48.0)
	if _sown_soil_texture != null:
		draw_texture_rect(_sown_soil_texture, soil_rect, false)
	else:
		draw_rect(soil_rect, Color("#5b402b"))
		draw_circle(
		Vector2(0.0, 1.0),
		2.5 + growth_ratio * 2.0,
		Color("#b6d45b", 0.82)
	)

	var progress_background := Rect2(-16.0, 19.0, 32.0, 3.0)
	draw_rect(progress_background, Color("#1a2119"))
	draw_rect(
		Rect2(progress_background.position, Vector2(progress_background.size.x * growth_ratio, 3.0)),
		Color("#8fcf58")
	)
