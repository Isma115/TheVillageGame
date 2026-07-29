const WORLD_TILES = 35;
// La tesela representa aproximadamente la huella visual del personaje.
const TILE_SIZE = 48;

export const WORLD = Object.freeze({
  columns: WORLD_TILES,
  rows: WORLD_TILES,
  tileSize: TILE_SIZE,
  width: WORLD_TILES * TILE_SIZE,
  height: WORLD_TILES * TILE_SIZE,
  edgePadding: 54
});

const villageCenterX = WORLD.width / 2;
const villageCenterY = WORLD.height / 2;

export const VILLAGE = Object.freeze({
  plaza: Object.freeze({ x: villageCenterX, y: villageCenterY - 10 }),
  houses: Object.freeze([
    Object.freeze({
      id: 'cream',
      asset: 'house-cream.png',
      x: villageCenterX - 430,
      y: villageCenterY + 10,
      size: 350,
      collision: Object.freeze({ width: 252, top: -96, bottom: -12 })
    }),
    Object.freeze({
      id: 'wood',
      asset: 'house-wood.png',
      x: villageCenterX + 430,
      y: villageCenterY + 10,
      size: 350,
      collision: Object.freeze({ width: 252, top: -96, bottom: -12 })
    }),
    Object.freeze({
      id: 'stone',
      asset: 'house-stone.png',
      x: villageCenterX,
      y: villageCenterY - 300,
      size: 340,
      collision: Object.freeze({ width: 250, top: -92, bottom: -12 })
    })
  ])
});

export const PLAYER = Object.freeze({
  radius: 19,
  walkSpeed: 270,
  runSpeed: 430,
  spawn: Object.freeze({ x: VILLAGE.plaza.x, y: VILLAGE.plaza.y + 110 })
});

export const CAMERA = Object.freeze({
  followStrength: 7.2
});

export const COLORS = Object.freeze({
  grass: '#5d934f',
  ink: '#193724'
});
