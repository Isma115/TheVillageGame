const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  platform: process.platform,
  getMemoryInfo: () => ipcRenderer.invoke('debug-memory')
});
