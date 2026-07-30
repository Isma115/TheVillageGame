extends Node2D

const GameWorld = preload("res://scripts/world.gd")
const HouseActor = preload("res://scripts/house.gd")
const PlayerActor = preload("res://scripts/player.gd")
const CollisionWorld = preload("res://scripts/collision_world.gd")
const InputState = preload("res://scripts/input_state.gd")
const MobileControls = preload("res://scripts/mobile_controls.gd")

var game_world: GameWorld
var actor_layer: Node2D
var player: PlayerActor
var collision_world: CollisionWorld
var input_state: InputState
var mobile_controls: MobileControls

var debug_fps: Label
var debug_memory: Label
var debug_entities: Label
var debug_objects: Label
var debug_detail: Label
var debug_particles: Label
var mobile_toggle: CheckButton
var loading_overlay: ColorRect
var debug_elapsed := 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(GameConfig.GRASS_COLOR)
	input_state = InputState.new()
	collision_world = CollisionWorld.new()

	game_world = GameWorld.new()
	add_child(game_world)

	actor_layer = Node2D.new()
	actor_layer.y_sort_enabled = true
	add_child(actor_layer)

	for house_data in game_world.houses:
		var house_actor := HouseActor.new()
		house_actor.configure(house_data)
		actor_layer.add_child(house_actor)

	player = PlayerActor.new()
	player.configure(collision_world, input_state)
	actor_layer.add_child(player)

	var camera := Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = GameConfig.CAMERA_FOLLOW_STRENGTH
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(GameConfig.WORLD_WIDTH)
	camera.limit_bottom = int(GameConfig.WORLD_HEIGHT)
	player.add_child(camera)

	_create_interface()
	_update_debug()

func _process(delta: float) -> void:
	player.update_player(delta)
	debug_elapsed += delta
	if debug_elapsed >= 0.25:
		_update_debug()
		debug_elapsed = 0.0

func _create_interface() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)
	_create_debug_overlay(ui_layer)

	mobile_controls = MobileControls.new()
	ui_layer.add_child(mobile_controls)
	mobile_controls.direction_changed.connect(input_state.set_virtual_direction)
	mobile_controls.sprint_changed.connect(input_state.set_virtual_sprinting)

	_create_loading_overlay(ui_layer)

func _create_debug_overlay(ui_layer: CanvasLayer) -> void:
	var debug_panel := PanelContainer.new()
	debug_panel.position = Vector2(12.0, 12.0)
	debug_panel.size = Vector2(238.0, 210.0)
	debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(debug_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	debug_panel.add_child(box)

	var heading := Label.new()
	heading.text = "DEBUG"
	heading.add_theme_color_override("font_color", Color("#d9ec70"))
	heading.add_theme_font_size_override("font_size", 12)
	box.add_child(heading)

	debug_fps = _add_debug_label(box, "FPS --")
	debug_memory = _add_debug_label(box, "RAM --")
	debug_entities = _add_debug_label(box, "Entidades --")
	debug_objects = _add_debug_label(box, "Objetos --")
	debug_detail = _add_debug_label(box, "3 casas · 0 camino")
	debug_particles = _add_debug_label(box, "0 partículas")

	mobile_toggle = CheckButton.new()
	mobile_toggle.text = "Controles móviles"
	mobile_toggle.button_pressed = false
	mobile_toggle.toggled.connect(_on_mobile_controls_toggled)
	box.add_child(mobile_toggle)

func _add_debug_label(parent: VBoxContainer, text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", Color("#f1f4dd"))
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)
	return label

func _create_loading_overlay(ui_layer: CanvasLayer) -> void:
	loading_overlay = ColorRect.new()
	loading_overlay.color = Color("#18241d")
	loading_overlay.position = Vector2.ZERO
	loading_overlay.size = get_viewport_rect().size
	loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(loading_overlay)

	var title := Label.new()
	title.text = "PRADERA\n\nPreparando la villa"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = Vector2(get_viewport_rect().size.x / 2.0 - 180.0, get_viewport_rect().size.y / 2.0 - 70.0)
	title.size = Vector2(360.0, 140.0)
	title.add_theme_color_override("font_color", Color("#f1f4dd"))
	title.add_theme_font_size_override("font_size", 22)
	loading_overlay.add_child(title)

	get_viewport().size_changed.connect(_resize_loading_overlay)
	get_tree().create_timer(0.45).timeout.connect(_hide_loading_overlay)

func _resize_loading_overlay() -> void:
	if not is_instance_valid(loading_overlay):
		return
	loading_overlay.size = get_viewport_rect().size

func _hide_loading_overlay() -> void:
	if is_instance_valid(loading_overlay):
		loading_overlay.queue_free()

func _on_mobile_controls_toggled(enabled: bool) -> void:
	if mobile_controls != null:
		mobile_controls.set_enabled(enabled)

func _update_debug() -> void:
	if debug_fps == null:
		return

	debug_fps.text = "FPS %d" % Engine.get_frames_per_second()
	var memory_bytes := Performance.get_monitor(Performance.MEMORY_STATIC)
	debug_memory.text = "RAM %.1f MB" % (memory_bytes / 1048576.0) if memory_bytes > 0 else "RAM N/D"
	debug_entities.text = "Entidades %d" % (1 + game_world.houses.size())
	debug_objects.text = "Objetos %d" % (game_world.houses.size() + game_world.path_tiles.size())
	debug_detail.text = "%d casas · %d camino" % [game_world.houses.size(), game_world.path_tiles.size()]
	debug_particles.text = "%d partículas" % player.run_clouds.size()
