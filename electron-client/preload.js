const { contextBridge, ipcRenderer } = require('electron');

// Expose safe APIs to the renderer process
contextBridge.exposeInMainWorld('electronAPI', {
    // Store operations
    getServers: () => ipcRenderer.invoke('store:get-servers'),
    saveServers: (servers) => ipcRenderer.invoke('store:save-servers', servers),
    getCurrentServer: () => ipcRenderer.invoke('store:get-current-server'),
    setCurrentServer: (url) => ipcRenderer.invoke('store:set-current-server', url),
    
    // Navigation
    loadURL: (url) => ipcRenderer.send('navigate', url),
    
    // PTT
    getPTTState: () => ipcRenderer.invoke('ptt:get-state'),
    onPTTToggle: (callback) => {
        ipcRenderer.on('ptt-toggle', (event, pressed) => {
            callback(pressed);
        });
    },
    
    // Platform info
    platform: process.platform
});