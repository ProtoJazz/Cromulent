const { app, BrowserWindow, ipcMain, globalShortcut } = require('electron');
const path = require('path');
const Store = require('electron-store');
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const store = new (Store.default || Store)();

let mainWindow;
let launcherWindow;
let pttManager;

// ============================================================================
// PTTManager - Multi-backend Push-to-Talk system
// ============================================================================
class PTTManager {
  constructor(mainWindow) {
    this.window = mainWindow;
    this.backend = null;
    this.backendName = null;
    this.keyCode = store.get('ptt-key-code', 29); // Default: Left Ctrl (code 29)
    this.daemonProcess = null;
    this.daemonRespawnTimer = null;
    this.uiohook = null;
    this.isPressed = false;
  }

  async initialize() {
    console.log('[PTT] Initializing...');
    
    // Try backends in order
    if (await this.tryRustDaemon()) {
      console.log('[PTT] Using Rust daemon backend');
      return true;
    }
    
    if (await this.tryUIOHook()) {
      console.log('[PTT] Using uiohook-napi backend');
      return true;
    }
    
    if (await this.tryGlobalShortcut()) {
      console.log('[PTT] Using globalShortcut fallback (toggle mode)');
      return true;
    }
    
    console.error('[PTT] All backends failed');
    this.emitError('No PTT backend available on this system');
    return false;
  }

  // ========== Backend 1: Rust Daemon (Linux preferred) ==========
async tryRustDaemon() {
  if (process.platform !== 'linux') {
    return false;
  }

  const daemonPath = path.join(__dirname, 'ptt-daemon', 'target', 'debug', 'ptt-daemon');
  
  if (!fs.existsSync(daemonPath)) {
    console.log('[PTT] Rust daemon not found at:', daemonPath);
    return false;
  }

  // Try without sudo - user should be in 'input' group
  if (await this.spawnDaemon(daemonPath, false)) {
    this.backendName = 'rust-daemon';
    return true;
  }

  console.log('[PTT] Daemon failed - add user to input group: sudo usermod -a -G input $USER');
  return false;
}

 async spawnDaemon(daemonPath, useSudo) {
  return new Promise((resolve) => {
    const cmd = useSudo ? 'sudo' : daemonPath;
    const spawnArgs = useSudo ? [daemonPath] : [];

    console.log(`[PTT] Spawning: ${cmd} ${spawnArgs.join(' ')}`);

    this.daemonProcess = spawn(cmd, spawnArgs);
    
    let initialOutput = false;

    this.daemonProcess.stdout.on('data', (data) => {
      const lines = data.toString().split('\n').filter(l => l.trim());
      
      lines.forEach(line => {
        console.log('[PTT] Daemon stdout:', line);
        if (line.startsWith('KEY:')) {
          this.handleDaemonKeyEvent(line);
        }
      });
    });

    this.daemonProcess.stderr.on('data', (data) => {
      const msg = data.toString();
      console.log('[PTT] Daemon stderr:', msg);
      
      // Look for successful initialization messages
      if (msg.includes('Listening on:') || msg.includes('Found') && msg.includes('keyboard')) {
        if (!initialOutput) {
          initialOutput = true;
          resolve(true);
        }
      }
      
      if (msg.includes('Permission denied')) {
        this.emitError('PTT requires permissions. Please add your user to the "input" group or run with sudo.');
      }
    });

    this.daemonProcess.on('error', (err) => {
      console.error('[PTT] Daemon spawn error:', err);
      if (!initialOutput) {
        resolve(false);
      }
    });

    this.daemonProcess.on('exit', (code) => {
      console.log(`[PTT] Daemon exited with code ${code}`);
      this.daemonProcess = null;
      
      // Auto-respawn after 2 seconds
      if (this.backendName && this.backendName.startsWith('rust-daemon')) {
        console.log('[PTT] Scheduling daemon respawn...');
        this.daemonRespawnTimer = setTimeout(() => {
          this.spawnDaemon(daemonPath, useSudo);
        }, 2000);
      }
    });

    // Increase timeout to 3 seconds
    setTimeout(() => {
      if (!initialOutput) {
        if (this.daemonProcess) {
          this.daemonProcess.kill();
          this.daemonProcess = null;
        }
        resolve(false);
      }
    }, 3000);
  });
}

handleDaemonKeyEvent(line) {
  // Parse: KEY:29:DOWN or KEY:29:UP or KEY:29:REPEAT
  const parts = line.split(':');
  if (parts.length !== 3) return;

  const keyCode = parseInt(parts[1]);
  const state = parts[2];

  if (keyCode === this.keyCode) {
    // DOWN or REPEAT = pressed
    // UP = released
    const isDown = (state === 'DOWN' || state === 'REPEAT');
    
    if (isDown !== this.isPressed) {
      this.isPressed = isDown;
      this.emitPTT(isDown);
    }
  }
}

  // ========== Backend 2: uiohook-napi (Windows/Mac/limited Linux) ==========
async tryUIOHook() {
  try {
    const { uIOhook, UiohookKey } = require('uiohook-napi');
    
    return new Promise((resolve) => {
      let started = false;

      uIOhook.on('keydown', (event) => {
        if (!started) {
          started = true;
          resolve(true);
        }
        
        if (event.keycode === this.keyCode && !this.isPressed) {
          this.isPressed = true;
          this.emitPTT(true);
        }
      });

      uIOhook.on('keyup', (event) => {
        if (event.keycode === this.keyCode && this.isPressed) {
          this.isPressed = false;
          this.emitPTT(false);
        }
      });

      uIOhook.start();
      this.uiohook = uIOhook;
      this.backendName = 'uiohook';

      // Timeout if no events received
      setTimeout(() => {
        if (!started) {
          uIOhook.stop();
          this.uiohook = null;
          resolve(false);
        }
      }, 1000);
    });
  } catch (err) {
    console.log('[PTT] uiohook-napi not available:', err.message);
    return false;
  }
}

  // ========== Backend 3: globalShortcut (toggle fallback) ==========
  async tryGlobalShortcut() {
    try {
      // Map common key codes to Electron accelerators
      const keyMap = {
        29: 'Control',
        56: 'Alt',
        42: 'Shift',
        57: 'Space'
      };

      const accelerator = keyMap[this.keyCode] || 'Control';
      const success = globalShortcut.register(accelerator, () => {
        this.isPressed = !this.isPressed;
        this.emitPTT(this.isPressed);
      });

      if (success) {
        this.backendName = 'globalShortcut';
        return true;
      }
    } catch (err) {
      console.log('[PTT] globalShortcut failed:', err.message);
    }
    
    return false;
  }

  // ========== Unified event emission ==========
  emitPTT(isPressed) {
    if (this.window && !this.window.isDestroyed()) {
      console.log(`[PTT] ${isPressed ? 'PRESSED' : 'RELEASED'} (backend: ${this.backendName})`);
      this.window.webContents.send('ptt-state', isPressed);
    }
  }

  emitError(message) {
    if (this.window && !this.window.isDestroyed()) {
      this.window.webContents.send('ptt-error', message);
    }
  }

  // ========== Lifecycle ==========
  setKeyCode(keyCode) {
    this.keyCode = keyCode;
    store.set('ptt-key-code', keyCode);
    console.log(`[PTT] Key code changed to ${keyCode}, reinitializing...`);
    
    this.cleanup();
    this.initialize();
  }

  cleanup() {
    console.log('[PTT] Cleaning up...');

    if (this.daemonRespawnTimer) {
      clearTimeout(this.daemonRespawnTimer);
      this.daemonRespawnTimer = null;
    }

    if (this.daemonProcess) {
      this.daemonProcess.kill();
      this.daemonProcess = null;
    }

    if (this.uiohook) {
      try {
        this.uiohook.stop();
      } catch (err) {
        console.error('[PTT] Error stopping uiohook:', err);
      }
      this.uiohook = null;
    }

    globalShortcut.unregisterAll();
    
    this.backendName = null;
    this.isPressed = false;
  }
}

// ============================================================================
// Window Management
// ============================================================================
function createLauncher() {
  launcherWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      webviewTag: true
    }
  });

  launcherWindow.loadFile('launcher.html');
   launcherWindow.webContents.on('did-finish-load', async () => {
    if (!pttManager) {
      pttManager = new PTTManager(launcherWindow);
      const success = await pttManager.initialize();
      
      if (!success) {
        console.error('[PTT] Failed to initialize any backend');
      }
    }
  });
}

function createMainWindow(serverUrl) {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadURL(serverUrl);

  // Initialize PTT after window loads
  mainWindow.webContents.on('did-finish-load', async () => {
    pttManager = new PTTManager(mainWindow);
    const success = await pttManager.initialize();
    
    if (!success) {
      console.error('[PTT] Failed to initialize any backend');
    }
  });

  mainWindow.on('closed', () => {
    if (pttManager) {
      pttManager.cleanup();
      pttManager = null;
    }
    mainWindow = null;
    app.quit();
  });
}

// ============================================================================
// IPC Handlers
// ============================================================================
ipcMain.handle('get-servers', () => {
  return store.get('servers', []);
});

ipcMain.handle('save-servers', (event, servers) => {
  store.set('servers', servers);
  return true;
});

ipcMain.handle('connect-server', (event, serverUrl) => {
  if (launcherWindow) {
    launcherWindow.close();
    launcherWindow = null;
  }
  createMainWindow(serverUrl);
  return true;
});

ipcMain.handle('get-ptt-key', () => {
  return store.get('ptt-key-code', 29);
});

ipcMain.handle('set-ptt-key', (event, keyCode) => {
  if (pttManager) {
    pttManager.setKeyCode(keyCode);
  } else {
    store.set('ptt-key-code', keyCode);
  }
  return true;
});


ipcMain.handle('store-refresh-token', async (event, serverUrl, refreshToken, email) => {
  const tokens = store.get('auth_tokens', {});
  tokens[serverUrl] = {
    refreshToken,
    email,
    lastUsed: Date.now()
  };
  store.set('auth_tokens', tokens);
  console.log('✅ Stored refresh token for:', serverUrl, '- User:', email);
  return true;
});

ipcMain.handle('get-refresh-token', async (event, serverUrl) => {
  const tokens = store.get('auth_tokens', {});
  const auth = tokens[serverUrl] || null;
  console.log('🔑 Retrieved token for:', serverUrl, ':', auth ? `✅ ${auth.email}` : '❌ not found');
  return auth;
});

ipcMain.handle('clear-refresh-token', async (event, serverUrl) => {
  const tokens = store.get('auth_tokens', {});
  delete tokens[serverUrl];
  store.set('auth_tokens', tokens);
  console.log('🗑️  Cleared token for:', serverUrl);
  return true;
});

ipcMain.handle('get-device-info', async () => {
  return {
    device_name: os.hostname(),
    device_type: `electron-${process.platform}`
  };
});

// ============================================================================
// App Lifecycle
// ============================================================================
app.whenReady().then(() => {
  console.log('📁 Electron store path:', store.path);
  createLauncher();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('will-quit', () => {
  if (pttManager) {
    pttManager.cleanup();
  }
});