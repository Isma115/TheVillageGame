extends InteractableActor
class_name HarvestableActor

var maximum_health := 1
var current_health := 0
var harvest_depleted := false
var _interaction_focused := false


func initialize_harvestable(
	max_health: int,
	area_id: StringName = &"overworld"
) -> void:
	maximum_health = maxi(max_health, 1)
	current_health = maximum_health
	harvest_depleted = false
	_interaction_focused = false
	set_interaction_area(area_id)
	set_interaction_active(true)
	queue_redraw()


func can_interact(source: Node2D) -> bool:
	return (
		not harvest_depleted
		and current_health > 0
		and super.can_interact(source)
	)


func set_interaction_focused(focused: bool) -> void:
	if _interaction_focused == focused:
		return
	_interaction_focused = focused
	_on_harvest_focus_changed(focused)
	queue_redraw()


func is_interaction_focused() -> bool:
	return _interaction_focused


func apply_harvest_damage(damage: int) -> bool:
	if harvest_depleted or current_health <= 0 or damage <= 0:
		return false

	current_health = maxi(0, current_health - damage)
	if current_health > 0:
		_on_harvest_hit()
		queue_redraw()
		return false

	harvest_depleted = true
	_interaction_focused = false
	set_interaction_active(false)
	_on_harvest_depleted()
	queue_redraw()
	return true


func health_ratio() -> float:
	if harvest_depleted:
		return 0.0
	return clampf(float(current_health) / float(maximum_health), 0.0, 1.0)


func _on_harvest_focus_changed(_focused: bool) -> void:
	pass


func _on_harvest_hit() -> void:
	pass


func _on_harvest_depleted() -> void:
	pass
