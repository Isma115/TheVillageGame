import { CAMERA, WORLD } from './config.js';
import { clamp, damp } from './math.js';

export class Camera {
  constructor() {
    this.position = { x: 0, y: 0 };
    this.viewport = { width: 1, height: 1 };
  }

  resize(width, height) {
    this.viewport.width = width;
    this.viewport.height = height;
    this.position.x = clamp(this.position.x, 0, this.maxX);
    this.position.y = clamp(this.position.y, 0, this.maxY);
  }

  snapTo(target) {
    this.position.x = this.targetX(target.x);
    this.position.y = this.targetY(target.y);
  }

  update(target, deltaTime) {
    this.position.x = damp(this.position.x, this.targetX(target.x), CAMERA.followStrength, deltaTime);
    this.position.y = damp(this.position.y, this.targetY(target.y), CAMERA.followStrength, deltaTime);
  }

  targetX(targetX) {
    return clamp(targetX - this.viewport.width / 2, 0, this.maxX);
  }

  targetY(targetY) {
    return clamp(targetY - this.viewport.height / 2, 0, this.maxY);
  }

  get maxX() {
    return Math.max(0, WORLD.width - this.viewport.width);
  }

  get maxY() {
    return Math.max(0, WORLD.height - this.viewport.height);
  }

  get visibleBounds() {
    return {
      left: this.position.x,
      top: this.position.y,
      right: this.position.x + this.viewport.width,
      bottom: this.position.y + this.viewport.height
    };
  }
}
