extends RefCounted
class_name GameConfig

const WORLD_COLUMNS := 35
const TILE_SIZE := 48.0
const WORLD_WIDTH := WORLD_COLUMNS * TILE_SIZE
const WORLD_HEIGHT := WORLD_COLUMNS * TILE_SIZE
const EDGE_PADDING := 54.0

const VILLAGE_CENTER := Vector2(WORLD_WIDTH / 2.0, WORLD_HEIGHT / 2.0)
const PLAZA := Vector2(VILLAGE_CENTER.x, VILLAGE_CENTER.y - 10.0)

const PLAYER_RADIUS := 19.0
const WALK_SPEED := 270.0
const RUN_SPEED := 430.0
const PLAYER_SPAWN := Vector2(PLAZA.x, PLAZA.y + 110.0)
const CAMERA_FOLLOW_STRENGTH := 7.2

const GRASS_COLOR := Color("#5d934f")
const INK_COLOR := Color("#193724")

static func houses() -> Array[Dictionary]:
	return [
		{
			"id": "cream",
			"asset": "house-cream.png",
			"position": Vector2(VILLAGE_CENTER.x - 430.0, VILLAGE_CENTER.y + 10.0),
			"size": 350.0,
			"collision": {"width": 252.0, "top": -96.0, "bottom": -12.0}
		},
		{
			"id": "wood",
			"asset": "house-wood.png",
			"position": Vector2(VILLAGE_CENTER.x + 430.0, VILLAGE_CENTER.y + 10.0),
			"size": 350.0,
			"collision": {"width": 252.0, "top": -96.0, "bottom": -12.0}
		},
		{
			"id": "stone",
			"asset": "house-stone.png",
			"position": Vector2(VILLAGE_CENTER.x, VILLAGE_CENTER.y - 300.0),
			"size": 340.0,
			"collision": {"width": 250.0, "top": -92.0, "bottom": -12.0}
		}
	]
