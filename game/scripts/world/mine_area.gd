extends Node2D
class_name MineArea

@onready var world: MineWorld = $MineWorld
@onready var actor_layer: Node2D = $MineActorLayer


func initialize(definition: MineDefinition) -> void:
	world.initialize(definition)
