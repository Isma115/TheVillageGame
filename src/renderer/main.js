import { Game } from './game.js';
import { MobileControls } from './game/mobile-controls.js';

const canvas = document.querySelector('#game-canvas');
const loadingScreen = document.querySelector('#loading-screen');
const loadingBar = document.querySelector('#loading-progress');
const loadingPercent = document.querySelector('#loading-percent');
const loadingStatus = document.querySelector('#loading-status');
const debugFps = document.querySelector('#debug-fps');
const debugEntities = document.querySelector('#debug-entities');
const debugObjects = document.querySelector('#debug-objects');
const debugObjectDetail = document.querySelector('#debug-object-detail');
const debugParticles = document.querySelector('#debug-particles');
const debugMemory = document.querySelector('#debug-memory');
const mobileControlsToggle = document.querySelector('#mobile-controls-toggle');
const mobileControlsRoot = document.querySelector('#mobile-controls');
const mobileStick = document.querySelector('#mobile-stick');
const mobileStickKnob = document.querySelector('#mobile-stick-knob');
const mobileRunButton = document.querySelector('#mobile-run');
let memoryRequestPending = false;
let memoryWarningShown = false;

function updateLoadingProgress(loaded, total, label) {
  const progress = total === 0 ? 0 : Math.round((loaded / total) * 100);
  loadingBar.style.width = `${progress}%`;
  loadingPercent.textContent = `${progress}%`;
  loadingStatus.textContent = loaded === total ? 'Todo listo' : `Cargando ${label}…`;
}

function updateDebug(info) {
  debugFps.textContent = `${info.fps}`;
  debugEntities.textContent = `${info.entities}`;
  debugObjects.textContent = `${info.objects}`;
  debugObjectDetail.textContent = `${info.houses} casas · ${info.pathTiles} camino`;
  debugParticles.textContent = `${info.particles}`;
  updateDebugMemory();
}

async function updateDebugMemory() {
  if (memoryRequestPending) {
    return;
  }

  memoryRequestPending = true;

  try {
    const memoryInfo = await window.electronAPI?.getMemoryInfo?.();
    const memoryKilobytes = Number(memoryInfo?.kilobytes);

    if (Number.isFinite(memoryKilobytes) && memoryKilobytes > 0) {
      debugMemory.textContent = formatMemory(memoryKilobytes / 1024);
      return;
    }

    const browserMemory = performance.memory;
    if (browserMemory?.usedJSHeapSize) {
      debugMemory.textContent = formatMemory(browserMemory.usedJSHeapSize / (1024 * 1024));
      return;
    }

    debugMemory.textContent = 'N/D';
  } catch (error) {
    if (!memoryWarningShown) {
      console.warn('No se pudo obtener la memoria de la aplicación:', error);
      memoryWarningShown = true;
    }
    debugMemory.textContent = 'N/D';
  } finally {
    memoryRequestPending = false;
  }
}

function formatMemory(megabytes) {
  return `${megabytes >= 100 ? Math.round(megabytes) : megabytes.toFixed(1)} MB`;
}

const game = new Game(canvas, updateLoadingProgress, updateDebug);
const mobileControls = new MobileControls({
  input: game.input,
  root: mobileControlsRoot,
  stick: mobileStick,
  knob: mobileStickKnob,
  runButton: mobileRunButton
});

mobileControlsToggle.checked = false;
mobileControls.setEnabled(false);
mobileControlsToggle.addEventListener('change', () => {
  mobileControls.setEnabled(mobileControlsToggle.checked);
});

game.ready
  .then(() => {
    canvas.classList.remove('is-loading');
    loadingScreen.classList.add('is-complete');
    game.start();
    window.setTimeout(() => loadingScreen.remove(), 320);
  })
  .catch((error) => {
    console.error(error);
    loadingScreen.classList.add('has-error');
    loadingStatus.textContent = 'No se pudieron cargar todos los recursos.';
  });
