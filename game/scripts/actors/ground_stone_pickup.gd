extends InteractableActor
class_name GroundStonePickup

var cell := Vector2i(-1, -1)


func initialize(stone_cell: Vector2i, world_position: Vector2) -> void:
	cell = stone_cell
	position = world_position
	set_interaction_area(GameCatalog.OVERWORLD_AREA_ID)
	set_interaction_active(true)


func interaction_anchor() -> Vector2:
	return global_position + Vector2(0.0, 4.0)


func interaction_distance() -> float:
	return 92.0


func interaction_priority() -> int:
	return 6


func interaction_label() -> String:
	return "Recoger piedra"
