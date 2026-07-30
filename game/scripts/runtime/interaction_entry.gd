extends RefCounted
class_name InteractionEntry

var instance_id := 0
var target_reference: WeakRef
var cell := Vector2i.ZERO


func configure(target: InteractableActor, spatial_cell: Vector2i) -> void:
	instance_id = target.get_instance_id()
	target_reference = weakref(target)
	cell = spatial_cell


func target() -> InteractableActor:
	if target_reference == null:
		return null
	var value: Object = target_reference.get_ref()
	if not is_instance_valid(value):
		return null
	return value as InteractableActor
