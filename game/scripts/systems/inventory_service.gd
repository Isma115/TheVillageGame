extends RefCounted
class_name InventoryService

signal item_changed(item: ItemDefinition, quantity: int)

var _definitions: Dictionary = {}
var _quantities: Dictionary = {}


func register_items(definitions: Array[ItemDefinition]) -> void:
	for definition in definitions:
		if definition == null:
			continue
		_definitions[definition.id] = definition
		if not _quantities.has(definition.id):
			_quantities[definition.id] = 0


func add_item(item: ItemDefinition, amount: int) -> int:
	if item == null or amount <= 0:
		return 0

	if not _definitions.has(item.id):
		_definitions[item.id] = item
		_quantities[item.id] = 0

	var current := quantity_of(item.id)
	var amount_added := mini(amount, maxi(item.max_stack - current, 0))
	if amount_added <= 0:
		return 0

	var next_quantity := current + amount_added
	_quantities[item.id] = next_quantity
	item_changed.emit(item, next_quantity)
	return amount_added


func remove_item(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0

	var current := quantity_of(item_id)
	var removed := mini(current, amount)
	if removed <= 0:
		return 0

	var next_quantity := current - removed
	_quantities[item_id] = next_quantity
	var definition := definition_for(item_id)
	if definition != null:
		item_changed.emit(definition, next_quantity)
	return removed


func has_item(item_id: StringName, amount := 1) -> bool:
	return quantity_of(item_id) >= amount


func quantity_of(item_id: StringName) -> int:
	return int(_quantities.get(item_id, 0))


func space_for(item_id: StringName) -> int:
	var definition := definition_for(item_id)
	if definition == null:
		return 0
	return maxi(definition.max_stack - quantity_of(item_id), 0)


func definition_for(item_id: StringName) -> ItemDefinition:
	return _definitions.get(item_id) as ItemDefinition


func snapshot() -> Dictionary:
	var result := {}
	for item_id in _quantities:
		result[String(item_id)] = int(_quantities[item_id])
	return result


func restore(snapshot_data: Dictionary) -> void:
	for item_id in _definitions:
		var definition := _definitions[item_id] as ItemDefinition
		var saved_quantity: Variant = snapshot_data.get(
			String(item_id),
			snapshot_data.get(item_id, 0)
		)
		var quantity := clampi(
			int(saved_quantity),
			0,
			definition.max_stack
		)
		_quantities[item_id] = quantity
		item_changed.emit(definition, quantity)
