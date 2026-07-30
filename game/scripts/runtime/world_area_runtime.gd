extends RefCounted
class_name WorldAreaRuntime

var id: StringName = &""
var label := ""
var root: Node2D
var actor_layer: Node2D
var collision_world: CollisionWorld
var camera_bounds := Rect2()


func configure(
	area_id: StringName,
	display_label: String,
	area_root: Node2D,
	area_actor_layer: Node2D,
	area_collision_world: CollisionWorld,
	area_camera_bounds: Rect2
) -> bool:
	if (
		String(area_id).is_empty()
		or area_root == null
		or area_actor_layer == null
		or area_collision_world == null
		or area_camera_bounds.size.x <= 0.0
		or area_camera_bounds.size.y <= 0.0
	):
		return false
	if (
		area_actor_layer != area_root
		and not area_root.is_ancestor_of(area_actor_layer)
	):
		return false

	id = area_id
	label = display_label if not display_label.strip_edges().is_empty() else String(area_id)
	root = area_root
	actor_layer = area_actor_layer
	collision_world = area_collision_world
	camera_bounds = area_camera_bounds
	set_active(false)
	return true


func set_active(active: bool) -> void:
	if root == null:
		return
	root.visible = active
	root.process_mode = (
		Node.PROCESS_MODE_INHERIT
		if active
		else Node.PROCESS_MODE_DISABLED
	)


func is_valid() -> bool:
	return (
		not String(id).is_empty()
		and is_instance_valid(root)
		and is_instance_valid(actor_layer)
		and collision_world != null
		and camera_bounds.size.x > 0.0
		and camera_bounds.size.y > 0.0
	)
