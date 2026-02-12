const { app, BrowserWindow, ipcMain, globalShortcut } = require('electron');
const path = require('path');
const fs = require('fs');

// Enable Wayland global shortcuts support
if (process.platform === 'linux') {
    app.commandLine.appendSwitch('enable-features', 'GlobalShortcutsPortal');
}

let mainWindow;
let userDataPath;

// PTT state (toggle mode)
let isMicEnabled = false;
let pttShortcut = 'Space';

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 1200,
        height: 800,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js')
        }
    });

    mainWindow.loadFile('launcher.html');
    mainWindow.webContents.openDevTools();
}

// Storage helpers
function getStorePath() {
    if (!userDataPath) {
        userDataPath = app.getPath('userData');
    }
    return path.join(userDataPath, 'store.json');
}

function readStore() {
    try {
        const data = fs.readFileSync(getStorePath(), 'utf8');
        return JSON.parse(data);
    } catch (err) {
        return { servers: [], currentServer: null };
    }
}

function writeStore(data) {
    fs.writeFileSync(getStorePath(), JSON.stringify(data, null, 2));
}

// Register global PTT (toggle mode)
function registerPTT() {
    globalShortcut.unregisterAll();
    
    const ret = globalShortcut.register(pttShortcut, () => {
        isMicEnabled = !isMicEnabled;
        
        console.log('PTT toggled:', isMicEnabled ? 'MIC ON' : 'MIC OFF');
        
        if (mainWindow) {
            mainWindow.webContents.send('ptt-toggle', isMicEnabled);
        }
    });
    
    if (ret) {
        console.log('✅ PTT registered:', pttShortcut);
    } else {
        console.log('❌ PTT registration failed');
    }
}

// IPC Handlers
ipcMain.handle('store:get-servers', () => {
    const store = readStore();
    return store.servers || [];
});

ipcMain.handle('store:save-servers', (event, servers) => {
    const store = readStore();
    store.servers = servers;
    writeStore(store);
    return true;
});

ipcMain.handle('store:get-current-server', () => {
    const store = readStore();
    return store.currentServer;
});

ipcMain.handle('store:set-current-server', (event, url) => {
    const store = readStore();
    store.currentServer = url;
    writeStore(store);
    return true;
});

ipcMain.on('navigate', (event, url) => {
    mainWindow.loadURL(url);
});

app.whenReady().then(() => {
    createWindow();
    registerPTT();
      globalShortcut.register('CommandOrControl+Y', () => {
        console.log('TEST SHORTCUT WORKED!');
    });
    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        }
    });
});

app.on('will-quit', () => {
    globalShortcut.unregisterAll();
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});