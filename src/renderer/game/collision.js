import { VILLAGE, WORLD } from './config.js';
import { clamp } from './math.js';

const COLLISION_EPSILON = 0.0001;

export class CollisionWorld {
  constructor({
    bounds = {
      left: WORLD.edgePadding,
      top: WORLD.edgePadding,
      right: WORLD.width - WORLD.edgePadding,
      bottom: WORLD.height - WORLD.edgePadding
    },
    obstacles = createHouseObstacles(VILLAGE.houses)
  } = {}) {
    this.bounds = { ...bounds };
    this.obstacles = obstacles.map((obstacle) => ({ ...obstacle }));
  }

  setObstacles(obstacles) {
    this.obstacles = obstacles.map((obstacle) => ({ ...obstacle }));
  }

  moveCircle(position, movement, radius) {
    const next = { x: position.x, y: position.y };
    const distance = Math.hypot(movement.x, movement.y);
    const stepSize = Math.max(6, radius * 0.65);
    const steps = Math.max(1, Math.ceil(distance / stepSize));
    const step = {
      x: movement.x / steps,
      y: movement.y / steps
    };
    let blockedX = false;
    let blockedY = false;

    for (let stepIndex = 0; stepIndex < steps; stepIndex += 1) {
      const beforeStep = { ...next };
      next.x += step.x;
      next.y += step.y;

      const bounded = this.keepCircleInsideBounds(next, radius);
      blockedX ||= Math.abs(bounded.x - next.x) > COLLISION_EPSILON;
      blockedY ||= Math.abs(bounded.y - next.y) > COLLISION_EPSILON;
      next.x = bounded.x;
      next.y = bounded.y;

      // A few passes handle corners where two house sides meet.
      for (let pass = 0; pass < 4; pass += 1) {
        let corrected = false;

        for (const obstacle of this.obstacles) {
          const correction = circleRectCorrection(next, radius, obstacle);
          if (!correction) {
            continue;
          }

          next.x += correction.x;
          next.y += correction.y;
          blockedX ||= Math.abs(correction.x) > COLLISION_EPSILON;
          blockedY ||= Math.abs(correction.y) > COLLISION_EPSILON;
          corrected = true;
        }

        const correctedBounds = this.keepCircleInsideBounds(next, radius);
        blockedX ||= Math.abs(correctedBounds.x - next.x) > COLLISION_EPSILON;
        blockedY ||= Math.abs(correctedBounds.y - next.y) > COLLISION_EPSILON;
        next.x = correctedBounds.x;
        next.y = correctedBounds.y;

        if (!corrected) {
          break;
        }
      }

      // If a very tight corner needed a correction, do one final positional
      // pass before the next substep so the circle cannot remain embedded.
      if (Math.abs(next.x - beforeStep.x) < COLLISION_EPSILON && Math.abs(next.y - beforeStep.y) < COLLISION_EPSILON) {
        break;
      }
    }

    return {
      position: next,
      blockedX,
      blockedY
    };
  }

  keepCircleInsideBounds(position, radius) {
    return {
      x: clamp(position.x, this.bounds.left + radius, this.bounds.right - radius),
      y: clamp(position.y, this.bounds.top + radius, this.bounds.bottom - radius)
    };
  }
}

export function createHouseObstacles(houses) {
  return houses.map((house) => {
    const collision = house.collision ?? {
      width: house.size * 0.84,
      height: house.size * 0.64,
      offsetX: 0,
      offsetY: -house.size * 0.4
    };
    const centerX = house.x + (collision.offsetX ?? 0);
    const left = centerX - collision.width / 2;

    if (collision.top !== undefined && collision.bottom !== undefined) {
      return {
        id: house.id,
        left,
        top: house.y + collision.top,
        right: left + collision.width,
        bottom: house.y + collision.bottom
      };
    }

    const centerY = house.y + (collision.offsetY ?? 0);

    return {
      id: house.id,
      left,
      top: centerY - collision.height / 2,
      right: left + collision.width,
      bottom: centerY + collision.height / 2
    };
  });
}

function circleRectCorrection(circle, radius, rectangle) {
  const closestX = clamp(circle.x, rectangle.left, rectangle.right);
  const closestY = clamp(circle.y, rectangle.top, rectangle.bottom);
  const deltaX = circle.x - closestX;
  const deltaY = circle.y - closestY;
  const distanceSquared = deltaX * deltaX + deltaY * deltaY;
  const radiusSquared = radius * radius;

  if (distanceSquared >= radiusSquared) {
    return null;
  }

  if (distanceSquared > COLLISION_EPSILON) {
    const distance = Math.sqrt(distanceSquared);
    const penetration = radius - distance;
    return {
      x: (deltaX / distance) * penetration,
      y: (deltaY / distance) * penetration
    };
  }

  return correctionFromInsideRectangle(circle, radius, rectangle);
}

function correctionFromInsideRectangle(circle, radius, rectangle) {
  const distances = [
    { distance: circle.x - rectangle.left, x: -(circle.x - rectangle.left + radius), y: 0 },
    { distance: rectangle.right - circle.x, x: rectangle.right - circle.x + radius, y: 0 },
    { distance: circle.y - rectangle.top, x: 0, y: -(circle.y - rectangle.top + radius) },
    { distance: rectangle.bottom - circle.y, x: 0, y: rectangle.bottom - circle.y + radius }
  ];

  distances.sort((first, second) => first.distance - second.distance);
  return { x: distances[0].x, y: distances[0].y };
}
