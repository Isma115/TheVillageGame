const MOVEMENT_KEYS = new Set([
  'ArrowUp',
  'ArrowDown',
  'ArrowLeft',
  'ArrowRight',
  'KeyW',
  'KeyA',
  'KeyS',
  'KeyD',
  'ShiftLeft',
  'ShiftRight'
]);

export class Input {
  constructor(target = window) {
    this.keys = new Set();
    this.virtualKeys = new Set();
    this.justPressed = new Set();

    this.onKeyDown = (event) => {
      if (MOVEMENT_KEYS.has(event.code)) {
        event.preventDefault();
      }

      if (!event.repeat) {
        this.justPressed.add(event.code);
      }

      this.keys.add(event.code);
    };

    this.onKeyUp = (event) => {
      this.keys.delete(event.code);
    };

    this.onBlur = () => {
      this.keys.clear();
      this.clearVirtualKeys();
    };

    target.addEventListener('keydown', this.onKeyDown, { passive: false });
    target.addEventListener('keyup', this.onKeyUp);
    target.addEventListener('blur', this.onBlur);
  }

  isDown(...codes) {
    return codes.some((code) => this.keys.has(code) || this.virtualKeys.has(code));
  }

  setVirtualKeys(codes) {
    this.virtualKeys = new Set(codes);
  }

  setVirtualKey(code, active) {
    if (active) {
      this.virtualKeys.add(code);
      return;
    }

    this.virtualKeys.delete(code);
  }

  clearVirtualKeys() {
    this.virtualKeys.clear();
  }

  consumePress(code) {
    const pressed = this.justPressed.has(code);
    this.justPressed.delete(code);
    return pressed;
  }

  endFrame() {
    this.justPressed.clear();
  }
}
