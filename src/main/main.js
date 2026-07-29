const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('node:path');

ipcMain.handle('debug-memory', () => {
  const metrics = app.getAppMetrics();
  const memoryKilobytes = metrics.reduce((total, metric) => {
    const workingSetSize = Number(metric.memory?.workingSetSize);
    return total + (Number.isFinite(workingSetSize) ? workingSetSize : 0);
  }, 0);

  return {
    kilobytes: memoryKilobytes,
    processes: metrics.length
  };
});

function createWindow() {
  const window = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 900,
    minHeight: 600,
    backgroundColor: '#18241d',
    title: 'Pradera',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  window.loadFile(path.join(__dirname, '../renderer/index.html'));
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
