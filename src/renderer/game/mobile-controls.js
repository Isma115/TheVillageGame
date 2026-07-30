const DEAD_ZONE = 0.2;

export class MobileControls {
  constructor({ input, root, stick, knob, runButton }) {
    this.input = input;
    this.root = root;
    this.stick = stick;
    this.knob = knob;
    this.runButton = runButton;
    this.enabled = false;
    this.stickPointerId = null;
    this.runPointerId = null;

    this.onStickPointerDown = (event) => {
      if (!this.enabled || this.stickPointerId !== null) {
        return;
      }

      event.preventDefault();
      this.stickPointerId = event.pointerId;
      this.stick.setPointerCapture?.(event.pointerId);
      this.updateStick(event);
    };

    this.onStickPointerMove = (event) => {
      if (event.pointerId !== this.stickPointerId) {
        return;
      }

      event.preventDefault();
      this.updateStick(event);
    };

    this.onStickPointerEnd = (event) => {
      if (event.pointerId !== this.stickPointerId) {
        return;
      }

      event.preventDefault();
      this.releasePointer(this.stick, event.pointerId);
      this.resetStick();
    };

    this.onRunPointerDown = (event) => {
      if (!this.enabled || this.runPointerId !== null) {
        return;
      }

      event.preventDefault();
      this.runPointerId = event.pointerId;
      this.runButton.setPointerCapture?.(event.pointerId);
      this.input.setVirtualKey('ShiftLeft', true);
      this.runButton.setAttribute('aria-pressed', 'true');
    };

    this.onRunPointerEnd = (event) => {
      if (event.pointerId !== this.runPointerId) {
        return;
      }

      event.preventDefault();
      this.releasePointer(this.runButton, event.pointerId);
      this.resetRun();
    };

    this.onWindowBlur = () => this.reset();

    this.stick.addEventListener('pointerdown', this.onStickPointerDown);
    this.stick.addEventListener('pointermove', this.onStickPointerMove);
    this.stick.addEventListener('pointerup', this.onStickPointerEnd);
    this.stick.addEventListener('pointercancel', this.onStickPointerEnd);
    this.runButton.addEventListener('pointerdown', this.onRunPointerDown);
    this.runButton.addEventListener('pointerup', this.onRunPointerEnd);
    this.runButton.addEventListener('pointercancel', this.onRunPointerEnd);
    window.addEventListener('blur', this.onWindowBlur);
    document.addEventListener('visibilitychange', this.onWindowBlur);
  }

  setEnabled(enabled) {
    this.enabled = Boolean(enabled);
    this.root.hidden = !this.enabled;
    this.root.setAttribute('aria-hidden', String(!this.enabled));

    if (!this.enabled) {
      this.reset();
    }
  }

  updateStick(event) {
    const rectangle = this.stick.getBoundingClientRect();
    const centerX = rectangle.left + rectangle.width / 2;
    const centerY = rectangle.top + rectangle.height / 2;
    const maxDistance = Math.max(1, rectangle.width / 2 - this.knob.offsetWidth / 2 - 6);
    const rawX = event.clientX - centerX;
    const rawY = event.clientY - centerY;
    const distance = Math.hypot(rawX, rawY);
    const scale = distance > maxDistance ? maxDistance / distance : 1;
    const offsetX = rawX * scale;
    const offsetY = rawY * scale;
    const normalizedX = offsetX / maxDistance;
    const normalizedY = offsetY / maxDistance;
    const activeKeys = new Set();

    if (normalizedX < -DEAD_ZONE) {
      activeKeys.add('ArrowLeft');
    } else if (normalizedX > DEAD_ZONE) {
      activeKeys.add('ArrowRight');
    }

    if (normalizedY < -DEAD_ZONE) {
      activeKeys.add('ArrowUp');
    } else if (normalizedY > DEAD_ZONE) {
      activeKeys.add('ArrowDown');
    }

    if (this.runPointerId !== null) {
      activeKeys.add('ShiftLeft');
    }

    this.input.setVirtualKeys(activeKeys);
    this.knob.style.transform = `translate(${offsetX}px, ${offsetY}px)`;
  }

  resetStick() {
    this.stickPointerId = null;
    this.input.setVirtualKeys(this.runPointerId === null ? [] : ['ShiftLeft']);
    this.knob.style.transform = 'translate(0, 0)';
  }

  resetRun() {
    this.runPointerId = null;
    this.input.setVirtualKey('ShiftLeft', false);
    this.runButton.setAttribute('aria-pressed', 'false');
  }

  reset() {
    this.releasePointer(this.stick, this.stickPointerId);
    this.releasePointer(this.runButton, this.runPointerId);
    this.resetStick();
    this.resetRun();
    this.input.clearVirtualKeys();
  }

  releasePointer(element, pointerId) {
    if (pointerId === null || !element.hasPointerCapture?.(pointerId)) {
      return;
    }

    element.releasePointerCapture(pointerId);
  }
}
