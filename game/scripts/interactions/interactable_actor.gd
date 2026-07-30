extends Node2D
class_name InteractableActor

signal interaction_requested(target: Node2D, source: Node2D)

var interaction_active := true
var _interaction_area_id: StringName = &"overworld"


func interaction_anchor() -> Vector2:
	return global_position


func interaction_area_id() -> StringName:
	return _interaction_area_id


func interaction_distance() -> float:
	return 80.0


func interaction_priority() -> int:
	return 0


func interaction_label() -> String:
	return "Interactuar"


func can_interact(_source: Node2D) -> bool:
	return interaction_active and is_inside_tree()


func interact(source: Node2D) -> void:
	if can_interact(source):
		interaction_requested.emit(self, source)


func set_interaction_focused(_focused: bool) -> void:
	pass


func set_interaction_active(active: bool) -> void:
	interaction_active = active


func set_interaction_area(area_id: StringName) -> void:
	if not String(area_id).is_empty():
		_interaction_area_id = area_id
