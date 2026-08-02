extends Node2D
class_name HotelArea

@onready var world: HotelWorld = $HotelWorld
@onready var actor_layer: Node2D = $HotelActorLayer
@onready var rest_spot: RestSpotActor = $HotelActorLayer/RestSpot

var definition: HotelDefinition

func initialize(next_definition: HotelDefinition) -> void:
	definition = next_definition
	world.initialize(definition)
	rest_spot.configure(
		definition.area_id,
		definition.rest_position,
		definition.bed_position,
		definition.rest_label
	)

func world_rect() -> Rect2:
	return definition.world_rect() if definition != null else Rect2()

func playable_bounds() -> Rect2:
	return definition.playable_bounds() if definition != null else Rect2()

func collision_obstacles() -> Array[Rect2]:
	return world.collision_obstacles()
