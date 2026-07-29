import { Camera } from './game/camera.js';
import { CollisionWorld } from './game/collision.js';
import { WORLD } from './game/config.js';
import { Input } from './game/input.js';
import { Player } from './game/player.js';
import { World } from './game/world.js';

export class Game {
  constructor(canvas, onLoadingProgress = () => {}, onDebugUpdate = () => {}) {
    this.canvas = canvas;
    this.context = canvas.getContext('2d');
    this.input = new Input(window);
    this.world = new World(onLoadingProgress);
    this.ready = this.world.ready;
    this.collisionWorld = new CollisionWorld();
    this.player = new Player(this.collisionWorld);
    this.camera = new Camera();
    this.viewport = { width: 1, height: 1, dpr: 1 };
    this.lastTime = 0;
    this.pointer = { x: 0, y: 0, inside: false };
    this.onDebugUpdate = onDebugUpdate;
    this.debugElapsed = 0;
    this.debugFrameCount = 0;

    this.onResize = () => this.resize();
    this.onPointerMove = (event) => {
      const rectangle = this.canvas.getBoundingClientRect();
      this.pointer.x = event.clientX - rectangle.left;
      this.pointer.y = event.clientY - rectangle.top;
      this.pointer.inside = true;
    };
    this.onPointerLeave = () => {
      this.pointer.inside = false;
    };

    window.addEventListener('resize', this.onResize);
    this.canvas.addEventListener('pointermove', this.onPointerMove);
    this.canvas.addEventListener('pointerleave', this.onPointerLeave);
    this.resize();
    this.camera.snapTo(this.player.position);
  }

  start() {
    requestAnimationFrame((time) => this.frame(time));
  }

  resize() {
    const rectangle = this.canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.viewport.width = Math.max(1, rectangle.width);
    this.viewport.height = Math.max(1, rectangle.height);
    this.viewport.dpr = dpr;
    this.canvas.width = Math.floor(this.viewport.width * dpr);
    this.canvas.height = Math.floor(this.viewport.height * dpr);
    this.camera.resize(this.viewport.width, this.viewport.height);
    this.context.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  frame(time) {
    const deltaTime = this.lastTime === 0 ? 0 : Math.min((time - this.lastTime) / 1000, 0.05);
    this.lastTime = time;

    this.update(deltaTime);
    this.render();
    this.input.endFrame();

    requestAnimationFrame((nextTime) => this.frame(nextTime));
  }

  update(deltaTime) {
    this.player.update(deltaTime, this.input);
    this.camera.update(this.player.position, deltaTime);

    this.updateDebug(deltaTime);
  }

  updateDebug(deltaTime) {
    if (deltaTime <= 0) {
      return;
    }

    this.debugElapsed += deltaTime;
    this.debugFrameCount += 1;

    if (this.debugElapsed < 0.25) {
      return;
    }

    const houseCount = this.world.houses.filter((house) => house.ready).length;
    const pathTileCount = this.world.pathTiles.length;

    this.onDebugUpdate({
      fps: Math.round(this.debugFrameCount / this.debugElapsed),
      entities: 1 + houseCount,
      objects: houseCount + pathTileCount,
      houses: houseCount,
      pathTiles: pathTileCount,
      particles: this.player.runClouds.length
    });

    this.debugElapsed = 0;
    this.debugFrameCount = 0;
  }

  render() {
    const { width, height } = this.viewport;
    this.context.clearRect(0, 0, width, height);
    this.world.render(this.context, this.camera);
    this.renderInteractionTile();

    this.context.save();
    this.context.translate(-this.camera.position.x, -this.camera.position.y);
    this.world.renderActors(this.context, this.player, this.camera);
    this.context.restore();
  }

  renderInteractionTile() {
    if (!this.pointer.inside) {
      return;
    }

    const worldX = this.pointer.x + this.camera.position.x;
    const worldY = this.pointer.y + this.camera.position.y;
    const gridX = Math.floor(worldX / WORLD.tileSize);
    const gridY = Math.floor(worldY / WORLD.tileSize);

    if (
      gridX < 0
      || gridY < 0
      || gridX >= WORLD.columns
      || gridY >= WORLD.rows
    ) {
      return;
    }

    const tileX = gridX * WORLD.tileSize;
    const tileY = gridY * WORLD.tileSize;

    this.context.save();
    this.context.translate(-this.camera.position.x, -this.camera.position.y);
    this.context.lineJoin = 'round';
    this.context.lineWidth = 3;
    this.context.strokeStyle = 'rgba(255, 255, 255, 0.92)';
    this.context.strokeRect(
      tileX + 2,
      tileY + 2,
      WORLD.tileSize - 4,
      WORLD.tileSize - 4
    );
    this.context.restore();
  }
}
