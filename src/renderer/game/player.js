import { PLAYER, COLORS } from './config.js';
import { normalize } from './math.js';

const RUN_CLOUD_DISTANCE = 27;

export class Player {
  constructor(collisionWorld) {
    this.collisionWorld = collisionWorld;
    this.position = { ...PLAYER.spawn };
    this.velocity = { x: 0, y: 0 };
    this.facing = { x: 0, y: 1 };
    this.animationTime = 0;
    this.distanceTravelled = 0;
    this.state = 'idle';
    this.runClouds = [];
    this.runCloudDistance = 0;
    this.runCloudSide = 1;
  }

  update(deltaTime, input) {
    const axisX = Number(input.isDown('ArrowRight', 'KeyD')) - Number(input.isDown('ArrowLeft', 'KeyA'));
    const axisY = Number(input.isDown('ArrowDown', 'KeyS')) - Number(input.isDown('ArrowUp', 'KeyW'));
    const direction = normalize(axisX, axisY);
    const sprinting = input.isDown('ShiftLeft', 'ShiftRight') && direction.length > 0;
    const speed = sprinting ? PLAYER.runSpeed : PLAYER.walkSpeed;
    const movement = {
      x: direction.x * speed * deltaTime,
      y: direction.y * speed * deltaTime
    };

    const collisionResult = this.collisionWorld.moveCircle(this.position, movement, PLAYER.radius);
    const actualMovement = {
      x: collisionResult.position.x - this.position.x,
      y: collisionResult.position.y - this.position.y
    };
    const actualDistance = Math.hypot(actualMovement.x, actualMovement.y);
    this.velocity.x = deltaTime > 0 ? actualMovement.x / deltaTime : 0;
    this.velocity.y = deltaTime > 0 ? actualMovement.y / deltaTime : 0;
    this.position.x = collisionResult.position.x;
    this.position.y = collisionResult.position.y;

    if (direction.length > 0 && actualDistance > 0.05) {
      this.facing.x = direction.x;
      this.facing.y = direction.y;
      this.distanceTravelled += actualDistance;
      this.animationTime += deltaTime * (sprinting ? 12 : 8);
      this.state = sprinting ? 'running' : 'walking';
    } else {
      this.velocity.x = 0;
      this.velocity.y = 0;
      this.animationTime += deltaTime * 2.2;
      this.state = 'idle';
    }

    this.updateRunClouds(deltaTime, this.state === 'running', actualDistance);
  }

  updateRunClouds(deltaTime, running, actualDistance) {
    this.runClouds = this.runClouds.filter((cloud) => {
      cloud.age += deltaTime;
      cloud.x += cloud.velocityX * deltaTime;
      cloud.y += cloud.velocityY * deltaTime;
      return cloud.age < cloud.life;
    });

    if (!running) {
      this.runCloudDistance = 0;
      return;
    }

    this.runCloudDistance += actualDistance;
    while (this.runCloudDistance >= RUN_CLOUD_DISTANCE) {
      this.runCloudDistance -= RUN_CLOUD_DISTANCE;
      this.spawnRunCloud();
    }
  }

  spawnRunCloud() {
    const side = { x: -this.facing.y, y: this.facing.x };
    const sideOffset = this.runCloudSide * 5.5;
    const backwardOffset = -3;
    const drift = 8 + Math.random() * 6;

    this.runClouds.push({
      x: this.position.x + side.x * sideOffset + this.facing.x * backwardOffset,
      y: this.position.y + 35 + side.y * sideOffset + this.facing.y * backwardOffset,
      age: 0,
      life: 0.38 + Math.random() * 0.12,
      size: 5.5 + Math.random() * 2.5,
      velocityX: -this.facing.x * drift + side.x * (Math.random() - 0.5) * 5,
      velocityY: -this.facing.y * drift + side.y * (Math.random() - 0.5) * 5 - 7
    });

    this.runCloudSide *= -1;
  }

  render(context) {
    const { x, y } = this.position;
    const moving = this.state !== 'idle';
    const stride = moving ? Math.sin(this.animationTime) * (this.state === 'running' ? 7 : 5) : 0;
    const bob = moving ? Math.abs(Math.sin(this.animationTime)) * -1.6 : Math.sin(this.animationTime) * 0.6;

    this.renderRunClouds(context);

    context.save();
    context.translate(x, y);

    // Sombra elíptica para anclar el monigote al terreno.
    context.save();
    context.scale(1, 0.34);
    context.fillStyle = 'rgba(22, 63, 30, 0.23)';
    context.beginPath();
    context.ellipse(0, 12, 27, 14, 0, 0, Math.PI * 2);
    context.fill();
    context.restore();

    context.translate(0, bob);

    // Piernas y zapatos.
    context.lineCap = 'round';
    context.lineWidth = 7;
    context.strokeStyle = COLORS.ink;
    context.beginPath();
    context.moveTo(-7, 25);
    context.lineTo(-8 + stride, 39);
    context.moveTo(7, 25);
    context.lineTo(8 - stride, 39);
    context.stroke();

    context.lineWidth = 5;
    context.strokeStyle = '#274f33';
    context.beginPath();
    context.moveTo(-10 + stride, 40);
    context.lineTo(-3 + stride, 40);
    context.moveTo(3 - stride, 40);
    context.lineTo(10 - stride, 40);
    context.stroke();

    // Cuerpo, con un borde de contraste para que se lea sobre el césped.
    context.fillStyle = '#f1f4dd';
    context.strokeStyle = '#244a30';
    context.lineWidth = 3;
    roundedRect(context, -16, -13, 32, 42, 12);
    context.fill();
    context.stroke();

    context.fillStyle = '#d9ec70';
    roundedRect(context, -14, -11, 28, 18, 8);
    context.fill();

    // Brazos siguiendo levemente la dirección del movimiento.
    context.lineWidth = 6;
    context.strokeStyle = '#f1f4dd';
    context.beginPath();
    context.moveTo(-14, -4);
    context.lineTo(-24 - stride * 0.45, 10);
    context.moveTo(14, -4);
    context.lineTo(24 + stride * 0.45, 10);
    context.stroke();

    // Cabeza y pelo.
    context.fillStyle = '#ffd8ad';
    context.beginPath();
    context.arc(0, -30, 16, 0, Math.PI * 2);
    context.fill();
    context.strokeStyle = '#244a30';
    context.lineWidth = 3;
    context.stroke();

    context.fillStyle = '#c46b45';
    context.beginPath();
    context.arc(0, -34, 14, Math.PI, Math.PI * 2);
    context.lineTo(14, -29);
    context.quadraticCurveTo(4, -37, -10, -28);
    context.closePath();
    context.fill();

    // Ojos orientados hacia la dirección de avance.
    const lookX = this.facing.x * 2.2;
    const lookY = this.facing.y * 1.2;
    context.fillStyle = COLORS.ink;
    context.beginPath();
    context.arc(-5 + lookX, -31 + lookY, 1.8, 0, Math.PI * 2);
    context.arc(5 + lookX, -31 + lookY, 1.8, 0, Math.PI * 2);
    context.fill();

    context.restore();
  }

  renderRunClouds(context) {
    for (const cloud of this.runClouds) {
      const progress = cloud.age / cloud.life;
      const fadeIn = Math.min(1, progress * 10);
      const alpha = (1 - progress) * fadeIn * 0.56;
      const size = cloud.size * (0.78 + progress * 0.56);

      context.save();
      context.globalAlpha = alpha;
      context.fillStyle = '#fffef4';
      context.beginPath();
      context.arc(cloud.x - size * 0.52, cloud.y + size * 0.08, size * 0.48, 0, Math.PI * 2);
      context.arc(cloud.x, cloud.y - size * 0.18, size * 0.7, 0, Math.PI * 2);
      context.arc(cloud.x + size * 0.52, cloud.y + size * 0.08, size * 0.45, 0, Math.PI * 2);
      context.ellipse(cloud.x, cloud.y + size * 0.18, size * 0.9, size * 0.42, 0, 0, Math.PI * 2);
      context.fill();
      context.restore();
    }
  }
}

function roundedRect(context, x, y, width, height, radius) {
  const safeRadius = Math.min(radius, width / 2, height / 2);
  context.beginPath();
  context.moveTo(x + safeRadius, y);
  context.arcTo(x + width, y, x + width, y + height, safeRadius);
  context.arcTo(x + width, y + height, x, y + height, safeRadius);
  context.arcTo(x, y + height, x, y, safeRadius);
  context.arcTo(x, y, x + width, y, safeRadius);
  context.closePath();
}
