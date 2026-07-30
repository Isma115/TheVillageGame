extends Node
class_name WildlifeManager

@export var animal_scene: PackedScene

var animals: Array[AnimalActor] = []


func initialize(
	definitions: Array[AnimalDefinition],
	actor_layer: Node2D,
	collision_world: CollisionWorld,
	playable_bounds: Rect2
) -> void:
	_clear_animals()
	if animal_scene == null:
		push_error("WildlifeManager necesita una escena de animal.")
		return

	for definition in definitions:
		var animal := animal_scene.instantiate() as AnimalActor
		if animal == null:
			push_error("La escena de animal no crea un AnimalActor.")
			continue

		animal.initialize(definition, collision_world, playable_bounds)
		actor_layer.add_child(animal)
		animals.append(animal)


func update_animals(delta: float) -> void:
	for animal in animals:
		animal.update_animal(delta)


func animal_count() -> int:
	return animals.size()


func _clear_animals() -> void:
	for animal in animals:
		if is_instance_valid(animal):
			animal.queue_free()
	animals.clear()
