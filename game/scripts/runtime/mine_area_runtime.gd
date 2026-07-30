extends WorldAreaRuntime
class_name MineAreaRuntime

var definition: MineDefinition
var world: MineWorld


func configure_mine(
	mine_definition: MineDefinition,
	area_root: Node2D,
	area_world: MineWorld,
	area_actor_layer: Node2D,
	area_collision_world: CollisionWorld
) -> bool:
	if mine_definition == null or area_world == null:
		return false

	definition = mine_definition
	world = area_world
	return configure(
		definition.area_id,
		definition.label,
		area_root,
		area_actor_layer,
		area_collision_world,
		definition.world_rect()
	)
