extends RefCounted
class_name MiningSiteRuntime

var definition: MineDefinition
var actor_layer: Node2D
var collision_world: CollisionWorld
var veins: Array[OreVeinActor] = []
var active_vein_count := 0
var action_cooldown := ActionCooldown.new()


func configure(
	mine_definition: MineDefinition,
	area_actor_layer: Node2D,
	area_collision_world: CollisionWorld
) -> bool:
	if (
		mine_definition == null
		or area_actor_layer == null
		or area_collision_world == null
	):
		return false

	definition = mine_definition
	actor_layer = area_actor_layer
	collision_world = area_collision_world
	veins.clear()
	active_vein_count = 0
	action_cooldown.reset()
	return true


func vein_count() -> int:
	return veins.size()


func depleted_vein_count() -> int:
	return vein_count() - active_vein_count
