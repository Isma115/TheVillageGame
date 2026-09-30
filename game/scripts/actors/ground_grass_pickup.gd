extends GroundStonePickup
class_name GroundGrassPickup

var yield_amount := 1


func initialize(
	grass_cell: Vector2i,
	world_position: Vector2,
	amount: int = 1
) -> void:
	super.initialize(grass_cell, world_position)
	yield_amount = maxi(amount, 1)


func interaction_label() -> String:
	return "Recoger hierba"
