const { contextBridge, ipcRenderer } = require('electron');

console.log('🔧 Preload script running!');

const api = {
  getServers: () => ipcRenderer.invoke('get-servers'),
  saveServers: (servers) => ipcRenderer.invoke('save-servers', servers),
  connectServer: (url) => ipcRenderer.invoke('connect-server', url),
  
  // PTT APIs
  getPTTKey: () => ipcRenderer.invoke('get-ptt-key'),
  setPTTKey: (keyCode) => ipcRenderer.invoke('set-ptt-key', keyCode),
  onPTTState: (callback) => ipcRenderer.on('ptt-state', (event, isPressed) => callback(isPressed)),
  onPTTError: (callback) => ipcRenderer.on('ptt-error', (event, message) => callback(message))
};

// Expose as electronAPI
contextBridge.exposeInMainWorld('electronAPI', api);

console.log('✅ electronAPI exposed to window');