extends Node
class_name HuntingSystem

signal hunting_mode_changed(active: bool)
signal shot_fired(hit_animal: bool)

const BOW_ID: StringName = &"bow"
const ARROWS_ID: StringName = &"arrows"

var _wildlife: WildlifeManager
var _inventory: InventoryService
var _tool_service: ToolService
var _arrow_item: ItemDefinition
var _meat_item: ItemDefinition
var _hunting_mode := false
var _hunting_enabled := false


func initialize(
	wildlife: WildlifeManager,
	inventory: InventoryService,
	tool_service: ToolService,
	items: Array[ItemDefinition]
) -> void:
	_wildlife = wildlife
	_inventory = inventory
	_tool_service = tool_service
	_hunting_enabled = false
	_hunting_mode = false
	_arrow_item = null
	_meat_item = null
	for item in items:
		if item == null:
			continue
		if item.id == ARROWS_ID:
			_arrow_item = item
		elif item.id == &"meat":
			_meat_item = item
	_refresh_hunting_mode()


func is_hunting_mode() -> bool:
	return _hunting_mode


func refresh_mode() -> void:
	_refresh_hunting_mode()


func toggle_mode() -> bool:
	if not can_hunt():
		_hunting_enabled = false
		_refresh_hunting_mode()
		return false
	_hunting_enabled = not _hunting_enabled
	_refresh_hunting_mode()
	return _hunting_mode


func disable_mode() -> void:
	_hunting_enabled = false
	_refresh_hunting_mode()


func can_hunt() -> bool:
	return (
		_wildlife != null
		and _inventory != null
		and _tool_service != null
		and _tool_service.has_tool(BOW_ID)
		and _tool_service.can_use_tool_capability(BOW_ID, &"shoot")
		and _inventory.has_item(ARROWS_ID, 1)
	)


func shoot_at(world_position: Vector2) -> bool:
	_refresh_hunting_mode()
	if not _hunting_mode or _inventory == null or _tool_service == null:
		return false

	var arrows_removed := _inventory.remove_item(ARROWS_ID, 1)
	if arrows_removed != 1:
		_refresh_hunting_mode()
		return false

	if _tool_service.equipped_tool_id() != BOW_ID:
		_tool_service.equip_tool(BOW_ID)
	if _tool_service.try_use_tool_capability(BOW_ID, &"shoot") == null:
		_inventory.add_item(_arrow_item, 1)
		_refresh_hunting_mode()
		return false

	var target := (
		_wildlife.animal_at_world_position(world_position)
		if _wildlife != null
		else null
	)
	var hit_animal := false
	if target != null:
		hit_animal = true
		if target.take_hunting_damage(1) and _wildlife.hunt_animal(target):
			if _meat_item != null:
				_inventory.add_item(_meat_item, 1)

	shot_fired.emit(hit_animal)
	_refresh_hunting_mode()
	return true


func _refresh_hunting_mode() -> void:
	var available := can_hunt()
	if not available:
		_hunting_enabled = false
	var next_mode := _hunting_enabled and available
	if next_mode == _hunting_mode:
		return
	_hunting_mode = next_mode
	hunting_mode_changed.emit(_hunting_mode)
