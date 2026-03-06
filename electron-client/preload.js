const { contextBridge, ipcRenderer } = require('electron');

console.log('🔧 Preload script running!');

const api = {
  getServers: () => ipcRenderer.invoke('get-servers'),
  saveServers: (servers) => ipcRenderer.invoke('save-servers', servers),
  connectServer: (url) => ipcRenderer.invoke('connect-server', url),
  
  // PTT APIs
  getPTTKey: () => ipcRenderer.invoke('get-ptt-key'),
  setPTTKey: (keyCode) => ipcRenderer.invoke('set-ptt-key', keyCode),
  getPTTDevice: () => ipcRenderer.invoke('get-ptt-device'),
  setPTTDevice: (devicePath) => ipcRenderer.invoke('set-ptt-device', devicePath),
  listPTTDevices: () => ipcRenderer.invoke('list-ptt-devices'),
  onPTTState: (callback) => ipcRenderer.on('ptt-state', (event, isPressed) => callback(isPressed)),
  onPTTError: (callback) => ipcRenderer.on('ptt-error', (event, message) => callback(message)),

  storeRefreshToken: (serverUrl, token, email) => 
    ipcRenderer.invoke('store-refresh-token', serverUrl, token, email),
  getRefreshToken: (serverUrl) => 
    ipcRenderer.invoke('get-refresh-token', serverUrl),
  clearRefreshToken: (serverUrl) => 
    ipcRenderer.invoke('clear-refresh-token', serverUrl),
  getDeviceInfo: () => 
    ipcRenderer.invoke('get-device-info'),
};

// Expose as electronAPI
contextBridge.exposeInMainWorld('electronAPI', api);

console.log('✅ electronAPI exposed to window');