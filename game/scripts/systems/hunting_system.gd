extends Node
class_name HuntingSystem

signal hunting_mode_changed(active: bool)
signal hunting_weapon_changed(projectile_id: StringName)
signal shot_fired(hit_animal: bool)

const BOW_ID: StringName = &"bow"
const ARROWS_ID: StringName = &"arrows"
const STONE_ID: StringName = &"stone"
const ARROW_DAMAGE := 1.0
const STONE_DAMAGE := 0.5

var _wildlife: WildlifeManager
var _inventory: InventoryService
var _tool_service: ToolService
var _arrow_item: ItemDefinition
var _stone_item: ItemDefinition
var _meat_item: ItemDefinition
var _hunting_mode := false
var _hunting_enabled := false
var _selected_projectile_id: StringName = &""


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
	_stone_item = null
	_meat_item = null
	_selected_projectile_id = &""
	for item in items:
		if item == null:
			continue
		if item.id == ARROWS_ID:
			_arrow_item = item
		elif item.id == STONE_ID:
			_stone_item = item
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


func selected_projectile_id() -> StringName:
	return _selected_projectile_id


func selected_projectile_label() -> String:
	match _selected_projectile_id:
		ARROWS_ID:
			return "Arco / flechas"
		STONE_ID:
			return "Piedra"
		_:
			return "Sin arma"


func select_projectile(projectile_id: StringName) -> bool:
	if not _available_projectiles().has(projectile_id):
		return false
	_set_selected_projectile(projectile_id)
	if projectile_id == ARROWS_ID and _tool_service != null:
		if _tool_service.equipped_tool_id() != BOW_ID:
			_tool_service.equip_tool(BOW_ID)
	return true


func cycle_projectile() -> bool:
	var available := _available_projectiles()
	if available.is_empty():
		_refresh_hunting_mode()
		return false

	var current_index := available.find(_selected_projectile_id)
	var next_index := 0 if current_index < 0 else (current_index + 1) % available.size()
	return select_projectile(available[next_index])


func can_hunt() -> bool:
	return (
		_wildlife != null
		and _inventory != null
		and _tool_service != null
		and (
			(
				_can_use_bow()
				and _inventory.has_item(ARROWS_ID, 1)
			)
			or _inventory.has_item(STONE_ID, 1)
		)
	)


func shoot_at(world_position: Vector2) -> bool:
	_refresh_hunting_mode()
	if not _hunting_mode or _inventory == null or _tool_service == null:
		return false

	var projectile_id := _selected_projectile_to_use()
	if String(projectile_id).is_empty():
		_refresh_hunting_mode()
		return false

	var damage := STONE_DAMAGE
	if projectile_id == ARROWS_ID:
		if not _can_use_bow():
			_refresh_hunting_mode()
			return false
		if _inventory.remove_item(ARROWS_ID, 1) != 1:
			_refresh_hunting_mode()
			return false
		if _tool_service.equipped_tool_id() != BOW_ID:
			_tool_service.equip_tool(BOW_ID)
		if _tool_service.try_use_tool_capability(BOW_ID, &"shoot") == null:
			_inventory.add_item(_arrow_item, 1)
			_refresh_hunting_mode()
			return false
		damage = ARROW_DAMAGE
	else:
		if _inventory.remove_item(STONE_ID, 1) != 1:
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
		if target.take_hunting_damage(damage) and _wildlife.hunt_animal(target):
			if _meat_item != null:
				_inventory.add_item(_meat_item, 1)

	shot_fired.emit(hit_animal)
	_refresh_hunting_mode()
	return true


func _can_use_bow() -> bool:
	return (
		_tool_service != null
		and _tool_service.has_tool(BOW_ID)
		and _tool_service.can_use_tool_capability(BOW_ID, &"shoot")
	)


func _available_projectiles() -> Array[StringName]:
	var available: Array[StringName] = []
	if _inventory == null:
		return available
	if _inventory.has_item(ARROWS_ID, 1) and _can_use_bow():
		available.append(ARROWS_ID)
	if _inventory.has_item(STONE_ID, 1):
		available.append(STONE_ID)
	return available


func _selected_projectile_to_use() -> StringName:
	var available := _available_projectiles()
	if available.has(_selected_projectile_id):
		return _selected_projectile_id
	return available[0] if not available.is_empty() else &""


func _set_selected_projectile(projectile_id: StringName) -> void:
	if _selected_projectile_id == projectile_id:
		return
	_selected_projectile_id = projectile_id
	hunting_weapon_changed.emit(_selected_projectile_id)


func _refresh_hunting_mode() -> void:
	var available_projectiles := _available_projectiles()
	if not available_projectiles.has(_selected_projectile_id):
		_set_selected_projectile(
			available_projectiles[0] if not available_projectiles.is_empty() else &""
		)
	var available := can_hunt()
	if not available:
		_hunting_enabled = false
	var next_mode := _hunting_enabled and available
	if next_mode == _hunting_mode:
		return
	_hunting_mode = next_mode
	hunting_mode_changed.emit(_hunting_mode)
