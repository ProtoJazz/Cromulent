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

// ── Top-level event listeners ─────────────────────────────────────────

document.getElementById('add-server-btn').addEventListener('click', () => {
  selectedView = 'add';
  renderContent();
});

// ── Start ─────────────────────────────────────────────────────────────

init();
