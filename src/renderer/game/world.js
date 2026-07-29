import { COLORS, VILLAGE, WORLD } from './config.js';
import { hash2d } from './math.js';

export class World {
  constructor(onProgress = () => {}) {
    this.texture = new Image();
    this.textureReady = false;

    this.pathTexture = new Image();
    this.pathTextureReady = false;

    this.houses = VILLAGE.houses.map((definition) => {
      const image = new Image();
      return { ...definition, image, ready: false };
    });

    this.resources = [
      {
        label: 'Césped',
        image: this.texture,
        src: new URL('../assets/grass-texture.png', import.meta.url).href,
        onLoad: () => {
          this.textureReady = true;
        }
      },
      {
        label: 'Camino',
        image: this.pathTexture,
        src: new URL('../assets/stone-grass-texture.png', import.meta.url).href,
        onLoad: () => {
          this.pathTextureReady = true;
        }
      },
      ...this.houses.map((house) => ({
        label: `Casa ${house.id}`,
        image: house.image,
        src: new URL(`../assets/houses/${house.asset}`, import.meta.url).href,
        onLoad: () => {
          house.ready = true;
        }
      }))
    ];

    const centerX = WORLD.width / 2;
    const plaza = VILLAGE.plaza;
    const [creamHouse, woodHouse, stoneHouse] = this.houses;
    this.pathRoutes = [
      [
        { x: centerX, y: WORLD.height + 140 },
        { x: centerX + 34, y: WORLD.height - 980 },
        { x: centerX - 22, y: plaza.y + 210 },
        plaza
      ],
      [
        plaza,
        { x: centerX - 170, y: plaza.y + 6 },
        { x: creamHouse.x, y: creamHouse.y }
      ],
      [
        plaza,
        { x: centerX + 170, y: plaza.y + 6 },
        { x: woodHouse.x, y: woodHouse.y }
      ],
      [
        plaza,
        { x: centerX, y: plaza.y - 145 },
        { x: stoneHouse.x, y: stoneHouse.y }
      ]
    ];
    this.pathTiles = buildPathTiles(this.pathRoutes, WORLD.tileSize);
    this.pathTileKeys = new Set(this.pathTiles.map((tile) => pathTileKey(tile.gridX, tile.gridY)));
    this.ready = this.loadResources(onProgress);
  }

  loadResources(onProgress) {
    const total = this.resources.length;
    let loaded = 0;
    onProgress(loaded, total, 'Preparando recursos');

    return Promise.all(
      this.resources.map((resource) => new Promise((resolve, reject) => {
        const handleError = () => {
          reject(new Error(`No se pudo cargar ${resource.label}`));
        };
        const handleLoad = () => {
          resource.image.removeEventListener('error', handleError);
          resource.onLoad();
          loaded += 1;
          onProgress(loaded, total, resource.label);
          resolve(resource.image);
        };

        resource.image.addEventListener('load', handleLoad, { once: true });
        resource.image.addEventListener('error', handleError, { once: true });
        resource.image.src = resource.src;
      }))
    ).then(() => this);
  }

  render(context, camera) {
    context.save();
    context.translate(-camera.position.x, -camera.position.y);
    context.fillStyle = COLORS.grass;
    const visibleBounds = camera.visibleBounds;
    context.fillRect(
      visibleBounds.left,
      visibleBounds.top,
      visibleBounds.right - visibleBounds.left,
      visibleBounds.bottom - visibleBounds.top
    );

    if (this.textureReady) {
      this.renderTextureTiles(context, camera);
    }

    this.renderPath(context, camera);

    context.restore();
  }

  renderTextureTiles(context, camera) {
    const { tileSize } = WORLD;
    const firstTileX = Math.max(0, Math.floor(camera.position.x / tileSize));
    const lastTileX = Math.min(
      WORLD.columns - 1,
      Math.ceil((camera.position.x + camera.viewport.width) / tileSize) - 1
    );
    const firstTileY = Math.max(0, Math.floor(camera.position.y / tileSize));
    const lastTileY = Math.min(
      WORLD.rows - 1,
      Math.ceil((camera.position.y + camera.viewport.height) / tileSize) - 1
    );

    context.imageSmoothingEnabled = false;

    for (let tileY = firstTileY; tileY <= lastTileY; tileY += 1) {
      for (let tileX = firstTileX; tileX <= lastTileX; tileX += 1) {
        const centerX = tileX * tileSize + tileSize / 2;
        const centerY = tileY * tileSize + tileSize / 2;
        const rotation = Math.floor(hash2d(tileX, tileY) * 4) * (Math.PI / 2);

        context.save();
        context.translate(centerX, centerY);
        context.rotate(rotation);
        context.drawImage(this.texture, -tileSize / 2, -tileSize / 2, tileSize, tileSize);
        context.restore();
      }
    }
  }

  renderPath(context, camera) {
    if (!this.pathTextureReady) {
      return;
    }

    context.save();
    context.imageSmoothingEnabled = false;

    for (const tile of this.pathTiles) {
      if (!isTileVisible(tile, camera)) {
        continue;
      }

      const centerX = tile.gridX * WORLD.tileSize + WORLD.tileSize / 2;
      const centerY = tile.gridY * WORLD.tileSize + WORLD.tileSize / 2;
      const rotation = Math.floor(hash2d(tile.gridX + 41, tile.gridY - 17) * 4) * (Math.PI / 2);

      context.save();
      context.translate(centerX, centerY);
      context.rotate(rotation);
      context.drawImage(
        this.pathTexture,
        -WORLD.tileSize / 2,
        -WORLD.tileSize / 2,
        WORLD.tileSize,
        WORLD.tileSize
      );
      context.restore();
    }

    this.renderPathTransitions(context, camera);

    context.restore();
  }

  renderPathTransitions(context, camera) {
    if (!this.textureReady) {
      return;
    }

    for (const tile of this.pathTiles) {
      if (!isTileVisible(tile, camera)) {
        continue;
      }

      const neighbors = [
        { gridX: tile.gridX - 1, gridY: tile.gridY, side: 'left' },
        { gridX: tile.gridX + 1, gridY: tile.gridY, side: 'right' },
        { gridX: tile.gridX, gridY: tile.gridY - 1, side: 'top' },
        { gridX: tile.gridX, gridY: tile.gridY + 1, side: 'bottom' }
      ];

      for (const neighbor of neighbors) {
        if (this.pathTileKeys.has(pathTileKey(neighbor.gridX, neighbor.gridY))) {
          continue;
        }
        drawGrassTransition(context, this.texture, tile, neighbor.side);
      }
    }
  }

  renderActors(context, player, camera) {
    const layers = this.houses
      .filter((house) => house.ready && isHouseVisible(house, camera))
      .map((house) => ({
        depth: house.y,
        priority: 0,
        draw: () => this.renderHouse(context, house)
      }));

    layers.push({
      depth: player.position.y,
      priority: 1,
      draw: () => player.render(context)
    });

    context.save();
    context.imageSmoothingEnabled = false;

    layers
      .sort((first, second) => first.depth - second.depth || first.priority - second.priority)
      .forEach((layer) => layer.draw());

    context.restore();
  }

  renderHouse(context, house) {
    const drawY = house.y - house.size * 0.87;
    context.save();
    context.drawImage(house.image, house.x - house.size / 2, drawY, house.size, house.size);
    context.restore();
  }
}

function isTileVisible(tile, camera) {
  const tileLeft = tile.gridX * WORLD.tileSize;
  const tileTop = tile.gridY * WORLD.tileSize;
  return isRectVisible(
    tileLeft,
    tileTop,
    WORLD.tileSize,
    WORLD.tileSize,
    camera
  );
}

function isHouseVisible(house, camera) {
  const drawY = house.y - house.size * 0.87;
  return isRectVisible(
    house.x - house.size / 2,
    drawY,
    house.size,
    house.size,
    camera
  );
}

function isRectVisible(x, y, width, height, camera) {
  const bounds = camera.visibleBounds;
  return (
    x + width > bounds.left
    && x < bounds.right
    && y + height > bounds.top
    && y < bounds.bottom
  );
}

function buildPathTiles(routes, tileSize) {
  const tiles = new Map();
  const addTile = (gridX, gridY) => {
    if (gridX < 0 || gridY < 0 || gridX >= WORLD.columns || gridY >= WORLD.rows) {
      return;
    }
    tiles.set(`${gridX}:${gridY}`, { gridX, gridY });
  };

  routes.forEach((route) => {
    for (let index = 1; index < route.length; index += 1) {
      const start = route[index - 1];
      const end = route[index];
      const distance = Math.hypot(end.x - start.x, end.y - start.y);
      const samples = Math.max(1, Math.ceil(distance / (tileSize * 0.35)));

      for (let sample = 0; sample <= samples; sample += 1) {
        const amount = sample / samples;
        const x = start.x + (end.x - start.x) * amount;
        const y = start.y + (end.y - start.y) * amount;
        const gridX = Math.floor(x / tileSize);
        const gridY = Math.floor(y / tileSize);
        addPathStripTiles(addTile, gridX, gridY, x, y, start, end, tileSize);
      }
    }
  });

  const plazaGridX = Math.floor(VILLAGE.plaza.x / tileSize);
  const plazaGridY = Math.floor(VILLAGE.plaza.y / tileSize);
  for (let offsetY = -1; offsetY <= 1; offsetY += 1) {
    for (let offsetX = -1; offsetX <= 1; offsetX += 1) {
      addTile(plazaGridX + offsetX, plazaGridY + offsetY);
    }
  }

  return [...tiles.values()].sort((first, second) => {
    if (first.gridY !== second.gridY) {
      return first.gridY - second.gridY;
    }
    return first.gridX - second.gridX;
  });
}

function addPathStripTiles(addTile, gridX, gridY, x, y, start, end, tileSize) {
  addTile(gridX, gridY);

  const horizontal = Math.abs(end.x - start.x) >= Math.abs(end.y - start.y);
  const tileCenterX = gridX * tileSize + tileSize / 2;
  const tileCenterY = gridY * tileSize + tileSize / 2;

  if (horizontal) {
    const adjacentGridY = y < tileCenterY ? gridY - 1 : gridY + 1;
    addTile(gridX, adjacentGridY);
    return;
  }

  const adjacentGridX = x < tileCenterX ? gridX - 1 : gridX + 1;
  addTile(adjacentGridX, gridY);
}

function pathTileKey(gridX, gridY) {
  return `${gridX}:${gridY}`;
}

function drawGrassTransition(context, texture, tile, side) {
  const tileSize = WORLD.tileSize;
  const tileLeft = tile.gridX * tileSize;
  const tileTop = tile.gridY * tileSize;
  const segmentCount = 8;
  const segmentSize = tileSize / segmentCount;
  const fadeSteps = 4;
  const sideSeed = { left: 11, right: 17, top: 23, bottom: 29 }[side];

  context.save();
  for (let segment = 0; segment < segmentCount; segment += 1) {
    const variation = hash2d(
      tile.gridX * 17 + segment * 7 + sideSeed,
      tile.gridY * 31 + sideSeed
    );
    const depth = tileSize * (0.24 + variation * 0.30);
    const bandSize = depth / fadeSteps;

    for (let step = 0; step < fadeSteps; step += 1) {
      const progress = step / (fadeSteps - 1);
      const alpha = 0.94 * Math.pow(1 - progress, 1.35);
      let bandX = tileLeft;
      let bandY = tileTop;
      let bandWidth = tileSize;
      let bandHeight = tileSize;

      if (side === 'left') {
        bandX = tileLeft + step * bandSize;
        bandY = tileTop + segment * segmentSize;
        bandWidth = bandSize + 1;
        bandHeight = segmentSize + 1;
      } else if (side === 'right') {
        bandX = tileLeft + tileSize - (step + 1) * bandSize;
        bandY = tileTop + segment * segmentSize;
        bandWidth = bandSize + 1;
        bandHeight = segmentSize + 1;
      } else if (side === 'top') {
        bandX = tileLeft + segment * segmentSize;
        bandY = tileTop + step * bandSize;
        bandWidth = segmentSize + 1;
        bandHeight = bandSize + 1;
      } else {
        bandX = tileLeft + segment * segmentSize;
        bandY = tileTop + tileSize - (step + 1) * bandSize;
        bandWidth = segmentSize + 1;
        bandHeight = bandSize + 1;
      }

      context.save();
      context.globalAlpha = alpha;
      context.beginPath();
      context.rect(bandX, bandY, bandWidth, bandHeight);
      context.clip();
      context.drawImage(texture, tileLeft, tileTop, tileSize, tileSize);
      context.restore();
    }
  }
  context.restore();
}
