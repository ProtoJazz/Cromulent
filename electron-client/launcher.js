let servers = [];
let selectedView = 'welcome'; // 'welcome' | 'add'
let connectedUrl = null;
let contextMenuServerIndex = null;

// ── Init ──────────────────────────────────────────────────────────────

async function init() {
  servers = await window.electronAPI.getServers();
  renderSidebar();
  renderContent();
  initPTT();
  setupContextMenu();
  setupWebview();
  bindSettingsEvents();
}

// ── Sidebar ───────────────────────────────────────────────────────────

function getInitials(name) {
  return name
    .split(/\s+/)
    .map(w => w[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);
}

function renderSidebar() {
  const container = document.getElementById('server-icons');
  container.innerHTML = servers.map((server, index) => `
    <button
      data-server-index="${index}"
      class="server-icon w-12 h-12 rounded-full ${connectedUrl === server.url ? 'bg-indigo-600' : 'bg-gray-800'} text-white flex items-center justify-center text-sm font-semibold cursor-pointer flex-shrink-0"
      title="${escapeHtml(server.name)}\n${escapeHtml(server.url)}"
    >${escapeHtml(getInitials(server.name))}</button>
  `).join('');

  container.querySelectorAll('[data-server-index]').forEach(btn => {
    btn.addEventListener('click', () => {
      const idx = parseInt(btn.dataset.serverIndex);
      connectToServer(idx);
    });

    btn.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      const idx = parseInt(btn.dataset.serverIndex);
      showContextMenu(e.clientX, e.clientY, idx);
    });
  });
}

// ── Context Menu ──────────────────────────────────────────────────────

function setupContextMenu() {
  document.addEventListener('click', () => hideContextMenu());
  document.addEventListener('contextmenu', (e) => {
    if (!e.target.closest('#server-icons [data-server-index]')) {
      hideContextMenu();
    }
  });

  document.getElementById('ctx-remove').addEventListener('click', () => {
    if (contextMenuServerIndex !== null) {
      removeServer(contextMenuServerIndex);
    }
    hideContextMenu();
  });
}

function showContextMenu(x, y, serverIndex) {
  contextMenuServerIndex = serverIndex;
  const menu = document.getElementById('context-menu');
  menu.style.left = x + 'px';
  menu.style.top = y + 'px';
  menu.classList.remove('hidden');
}

function hideContextMenu() {
  document.getElementById('context-menu').classList.add('hidden');
  contextMenuServerIndex = null;
}

// ── Webview ───────────────────────────────────────────────────────────

function setupWebview() {
  const webview = document.getElementById('server-webview');

  // Set preload path (same directory as launcher.html)
  const dir = window.location.pathname.substring(0, window.location.pathname.lastIndexOf('/'));
  webview.setAttribute('preload', `file://${dir}/preload.js`);
}

function showWebview(url) {
  const webview = document.getElementById('server-webview');
  const content = document.getElementById('content');

  // Only reload if URL changed
  if (webview.getAttribute('src') !== url) {
    webview.setAttribute('src', url);
  }

  content.classList.add('hidden');
  webview.classList.remove('hidden');
}

function hideWebview() {
  const webview = document.getElementById('server-webview');
  const content = document.getElementById('content');

  webview.classList.add('hidden');
  content.classList.remove('hidden');
}

// ── Content ───────────────────────────────────────────────────────────

function renderContent() {
  const el = document.getElementById('content');

  if (selectedView === 'add') {
    hideWebview();
    el.innerHTML = `
      <div class="max-w-md mx-auto mt-8">
        <h2 class="text-2xl font-bold text-white mb-2">Add Server</h2>
        <p class="text-gray-400 mb-6">Enter a name and URL for your Cromulent server.</p>

        <div id="add-error" class="hidden mb-4 p-3 rounded-lg bg-red-900/50 border border-red-700 text-red-300 text-sm"></div>

        <div class="mb-4">
          <label class="block mb-2 text-sm font-medium text-gray-300">Server Name</label>
          <input type="text" id="server-name"
            class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5 placeholder-gray-400"
            placeholder="My Server" />
        </div>

        <div class="mb-6">
          <label class="block mb-2 text-sm font-medium text-gray-300">Server URL</label>
          <input type="url" id="server-url"
            class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5 placeholder-gray-400"
            placeholder="https://chat.example.com" />
        </div>

        <button id="add-submit-btn"
          class="w-full text-white bg-indigo-600 hover:bg-indigo-700 focus:ring-4 focus:ring-indigo-800 font-medium rounded-lg text-sm px-5 py-2.5 cursor-pointer">
          Add Server
        </button>

        ${connectedUrl ? `
          <button id="back-btn"
            class="w-full mt-3 text-gray-300 bg-gray-700 hover:bg-gray-600 font-medium rounded-lg text-sm px-5 py-2.5 cursor-pointer">
            Back to Server
          </button>
        ` : ''}
      </div>

      <!-- Quick Login -->
      <div class="max-w-md mx-auto mt-10 pt-8 border-t border-gray-700">
        <h3 class="text-lg font-semibold text-white mb-1">Quick Login</h3>
        <p class="text-gray-400 text-sm mb-4">Authenticate and connect to a saved server.</p>

        <div id="login-error" class="hidden mb-4 p-3 rounded-lg bg-red-900/50 border border-red-700 text-red-300 text-sm"></div>
        <div id="login-status" class="hidden mb-4 p-3 rounded-lg bg-green-900/50 border border-green-700 text-green-300 text-sm"></div>

        <div class="mb-4">
          <label class="block mb-2 text-sm font-medium text-gray-300">Server</label>
          <select id="login-server"
            class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
          </select>
        </div>

        <div class="mb-4">
          <label class="block mb-2 text-sm font-medium text-gray-300">Email</label>
          <input type="email" id="login-email"
            class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5 placeholder-gray-400"
            placeholder="you@example.com" />
        </div>

        <div class="mb-6">
          <label class="block mb-2 text-sm font-medium text-gray-300">Password</label>
          <input type="password" id="login-password"
            class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5 placeholder-gray-400"
            placeholder="Password" />
        </div>

        <button id="login-btn"
          class="w-full text-white bg-green-600 hover:bg-green-700 focus:ring-4 focus:ring-green-800 font-medium rounded-lg text-sm px-5 py-2.5 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
          Login & Connect
        </button>
      </div>
    `;

    populateLoginServerList();
    bindAddServerEvents();
    bindLoginEvents();

    if (connectedUrl) {
      document.getElementById('back-btn').addEventListener('click', () => {
        selectedView = 'welcome';
        showWebview(connectedUrl);
        renderContent(); // clear the form from behind the webview
      });
    }
    return;
  }

  // Welcome view (default) — only shown when not connected
  if (connectedUrl) {
    // Webview is visible, content is hidden, but set a placeholder
    el.innerHTML = '';
    showWebview(connectedUrl);
    return;
  }

  hideWebview();

  if (servers.length === 0) {
    el.innerHTML = `
      <div class="flex flex-col items-center justify-center h-full text-center">
        <h1 class="text-3xl font-bold text-white mb-3">Cromulent Voice Chat</h1>
        <p class="text-gray-400 mb-6 max-w-sm">No servers yet. Click the <span class="text-green-400 font-bold text-lg">+</span> in the sidebar to add your first server.</p>
      </div>
    `;
  } else {
    el.innerHTML = `
      <div class="flex flex-col items-center justify-center h-full text-center">
        <h1 class="text-3xl font-bold text-white mb-3">Cromulent Voice Chat</h1>
        <p class="text-gray-400 max-w-sm">Click a server icon in the sidebar to connect, or press <span class="text-green-400 font-bold text-lg">+</span> to add another.</p>
      </div>
    `;
  }
}

// ── Event Binding ─────────────────────────────────────────────────────

function bindAddServerEvents() {
  document.getElementById('add-submit-btn').addEventListener('click', addServer);
  document.getElementById('server-url').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') addServer();
  });
}

function bindLoginEvents() {
  document.getElementById('login-btn').addEventListener('click', quickLogin);
  document.getElementById('login-password').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') quickLogin();
  });
}

// ── Server Management ─────────────────────────────────────────────────

async function addServer() {
  const name = document.getElementById('server-name').value.trim();
  const url = document.getElementById('server-url').value.trim();
  const errorEl = document.getElementById('add-error');

  errorEl.classList.add('hidden');

  if (!name || !url) {
    errorEl.textContent = 'Please enter both server name and URL.';
    errorEl.classList.remove('hidden');
    return;
  }

  try {
    new URL(url);
  } catch {
    errorEl.textContent = 'Please enter a valid URL (e.g., https://chat.example.com).';
    errorEl.classList.remove('hidden');
    return;
  }

  if (servers.some(s => s.url === url)) {
    errorEl.textContent = 'This server is already in your list.';
    errorEl.classList.remove('hidden');
    return;
  }

  servers.push({ name, url });
  await window.electronAPI.saveServers(servers);

  renderSidebar();
  selectedView = 'welcome';
  renderContent();
}

async function removeServer(index) {
  const removedUrl = servers[index].url;
  servers.splice(index, 1);
  await window.electronAPI.saveServers(servers);

  // If we removed the connected server, disconnect
  if (connectedUrl === removedUrl) {
    connectedUrl = null;
    hideWebview();
    document.getElementById('server-webview').removeAttribute('src');
  }

  renderSidebar();
  renderContent();
}

function connectToServer(index) {
  const server = servers[index];
  connectedUrl = server.url;
  selectedView = 'welcome';
  renderSidebar(); // update active highlight
  renderContent(); // shows webview
}

// ── Quick Login ───────────────────────────────────────────────────────

function populateLoginServerList() {
  const select = document.getElementById('login-server');
  if (!select) return;

  if (servers.length === 0) {
    select.innerHTML = '<option>No servers added</option>';
    select.disabled = true;
    document.getElementById('login-btn').disabled = true;
    return;
  }

  select.innerHTML = servers.map((server, index) =>
    `<option value="${index}">${escapeHtml(server.name)} - ${escapeHtml(server.url)}</option>`
  ).join('');
  select.disabled = false;
  document.getElementById('login-btn').disabled = false;
}

async function quickLogin() {
  const serverIndex = document.getElementById('login-server').value;
  const email = document.getElementById('login-email').value.trim();
  const password = document.getElementById('login-password').value;

  const errorEl = document.getElementById('login-error');
  const statusEl = document.getElementById('login-status');
  const loginBtn = document.getElementById('login-btn');

  errorEl.classList.add('hidden');
  statusEl.classList.add('hidden');

  if (!email || !password) {
    errorEl.textContent = 'Please enter email and password.';
    errorEl.classList.remove('hidden');
    return;
  }

  const server = servers[serverIndex];
  if (!server) {
    errorEl.textContent = 'Please select a server.';
    errorEl.classList.remove('hidden');
    return;
  }

  loginBtn.disabled = true;
  loginBtn.textContent = 'Logging in...';
  statusEl.textContent = 'Connecting...';
  statusEl.classList.remove('hidden');

  try {
    const authManager = new AuthManager(server.url);
    statusEl.textContent = 'Authenticating...';
    const success = await authManager.login(email, password);

    if (success) {
      statusEl.textContent = 'Success! Connecting to server...';
      await new Promise(resolve => setTimeout(resolve, 500));
      connectToServer(parseInt(serverIndex));
    } else {
      errorEl.textContent = 'Login failed.';
      errorEl.classList.remove('hidden');
      statusEl.classList.add('hidden');
    }
  } catch (error) {
    console.error('Login error:', error);
    errorEl.textContent = error.message || 'Login failed.';
    errorEl.classList.remove('hidden');
    statusEl.classList.add('hidden');
  } finally {
    loginBtn.disabled = false;
    loginBtn.textContent = 'Login & Connect';
  }
}

// ── PTT ───────────────────────────────────────────────────────────────

async function initPTT() {
  const key = await window.electronAPI.getPTTKey().catch(() => null);
  document.getElementById('ptt-key').textContent = key || 'Left Ctrl';

  window.electronAPI.onPTTState((pressed) => {
    const dot = document.getElementById('ptt-dot');
    const label = document.getElementById('ptt-label');
    if (pressed) {
      dot.classList.remove('bg-gray-600');
      dot.classList.add('bg-red-500');
      label.textContent = 'PTT: Active';
      label.classList.remove('text-gray-400');
      label.classList.add('text-red-400');
    } else {
      dot.classList.remove('bg-red-500');
      dot.classList.add('bg-gray-600');
      label.textContent = 'PTT: Off';
      label.classList.remove('text-red-400');
      label.classList.add('text-gray-400');
    }

    // Forward PTT state to the webview so the Phoenix app receives it
    const webview = document.getElementById('server-webview');
    if (webview && !webview.classList.contains('hidden')) {
      webview.send('ptt-state', pressed);
    }
  });

  window.electronAPI.onPTTError((message) => {
    console.error('PTT Error:', message);
  });
}

// ── Helpers ───────────────────────────────────────────────────────────

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// ── Settings Modal ────────────────────────────────────────────────────

// Map JS event.code → evdev/uiohook scancode
const JS_CODE_TO_PTT = {
  'ControlLeft': 29, 'ControlRight': 97,
  'AltLeft': 56,     'AltRight': 100,
  'ShiftLeft': 42,   'ShiftRight': 54,
  'Space': 57,
  'CapsLock': 58,
  'Tab': 15,
  'Backquote': 41,
  'F13': 183, 'F14': 184, 'F15': 185, 'F16': 186,
  'F17': 187, 'F18': 188, 'F19': 189, 'F20': 190,
};

const PTT_KEY_NAMES = {
  29: 'Left Ctrl',  97: 'Right Ctrl',
  56: 'Left Alt',  100: 'Right Alt',
  42: 'Left Shift', 54: 'Right Shift',
  57: 'Space',
  58: 'Caps Lock',
  15: 'Tab',
  41: 'Backtick',
  183: 'F13', 184: 'F14', 185: 'F15', 186: 'F16',
  187: 'F17', 188: 'F18', 189: 'F19', 190: 'F20',
};

let settingsPendingKey = null;  // keycode staged for save
let settingsPendingDevice = undefined; // device path staged for save (undefined = unchanged)
let settingsListening = false;

async function openSettings() {
  settingsPendingKey = null;
  settingsPendingDevice = undefined;
  settingsListening = false;

  const modal = document.getElementById('settings-modal');
  modal.classList.remove('hidden');

  // Show current PTT key
  const currentKey = await window.electronAPI.getPTTKey().catch(() => 29);
  document.getElementById('ptt-key-display').textContent = PTT_KEY_NAMES[currentKey] || `Key ${currentKey}`;
  document.getElementById('ptt-key-btn').dataset.currentCode = currentKey;
  setKeyBtnIdle();

  // Device section — Linux only
  const isLinux = navigator.userAgent.includes('Linux') || navigator.platform.includes('Linux');
  const deviceSection = document.getElementById('ptt-device-section');
  if (isLinux) {
    deviceSection.classList.remove('hidden');
    await loadDevices();
  } else {
    deviceSection.classList.add('hidden');
  }
}

async function loadDevices() {
  const select = document.getElementById('ptt-device-select');
  const currentDevice = await window.electronAPI.getPTTDevice().catch(() => null);

  select.innerHTML = '<option value="">Loading...</option>';
  select.disabled = true;

  const devices = await window.electronAPI.listPTTDevices().catch(() => []);

  select.innerHTML = '<option value="">Auto-detect</option>' +
    devices.map(d =>
      `<option value="${escapeHtml(d.path)}">${escapeHtml(d.name)} — ${escapeHtml(d.path)}</option>`
    ).join('');
  select.disabled = false;

  // Restore saved selection
  if (currentDevice) {
    select.value = currentDevice;
    if (!select.value) {
      // Device no longer present — add as disabled option so user sees it
      const opt = document.createElement('option');
      opt.value = currentDevice;
      opt.textContent = `${currentDevice} (not found)`;
      opt.disabled = true;
      select.appendChild(opt);
      select.value = currentDevice;
    }
  }
}

function setKeyBtnListening() {
  settingsListening = true;
  const btn = document.getElementById('ptt-key-btn');
  const hint = document.getElementById('ptt-key-hint');
  btn.classList.add('border-indigo-500', 'text-indigo-300');
  document.getElementById('ptt-key-display').textContent = 'Press a key…';
  hint.textContent = 'Press any supported key (Ctrl, Alt, Shift, Space, F13–F20…)';
}

function setKeyBtnIdle() {
  settingsListening = false;
  const btn = document.getElementById('ptt-key-btn');
  const hint = document.getElementById('ptt-key-hint');
  btn.classList.remove('border-indigo-500', 'text-indigo-300');
  hint.textContent = 'Click to rebind — then press any key';
}

function bindSettingsEvents() {
  document.getElementById('settings-btn').addEventListener('click', openSettings);
  document.getElementById('settings-close').addEventListener('click', closeSettings);
  document.getElementById('settings-cancel').addEventListener('click', closeSettings);
  document.getElementById('settings-backdrop').addEventListener('click', closeSettings);

  document.getElementById('ptt-key-btn').addEventListener('click', () => {
    if (settingsListening) {
      setKeyBtnIdle();
    } else {
      setKeyBtnListening();
    }
  });

  document.getElementById('ptt-device-refresh').addEventListener('click', loadDevices);

  document.addEventListener('keydown', (e) => {
    if (!settingsListening) return;
    e.preventDefault();
    e.stopPropagation();

    const code = JS_CODE_TO_PTT[e.code];
    if (!code) {
      document.getElementById('ptt-key-hint').textContent = `"${e.code}" isn't supported as a PTT key — try Ctrl, Alt, Shift, Space, or F13–F20`;
      return;
    }

    settingsPendingKey = code;
    document.getElementById('ptt-key-display').textContent = PTT_KEY_NAMES[code] || `Key ${code}`;
    setKeyBtnIdle();
  }, true);

  document.getElementById('settings-save').addEventListener('click', async () => {
    const saveBtn = document.getElementById('settings-save');
    saveBtn.disabled = true;
    saveBtn.textContent = 'Saving…';

    try {
      if (settingsPendingKey !== null) {
        await window.electronAPI.setPTTKey(settingsPendingKey);
        document.getElementById('ptt-key').textContent = PTT_KEY_NAMES[settingsPendingKey] || `Key ${settingsPendingKey}`;
      }

      const deviceSelect = document.getElementById('ptt-device-select');
      if (deviceSelect && !deviceSelect.classList.contains('hidden')) {
        const chosenDevice = deviceSelect.value || null;
        await window.electronAPI.setPTTDevice(chosenDevice);
      }
    } finally {
      saveBtn.disabled = false;
      saveBtn.textContent = 'Save';
    }

    closeSettings();
  });
}

function closeSettings() {
  setKeyBtnIdle();
  document.getElementById('settings-modal').classList.add('hidden');
}

// ── Top-level event listeners ─────────────────────────────────────────

document.getElementById('add-server-btn').addEventListener('click', () => {
  selectedView = 'add';
  renderContent();
});

// ── Start ─────────────────────────────────────────────────────────────

init();
