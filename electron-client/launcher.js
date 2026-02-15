let servers = [];

// Load servers when page loads
async function init() {
    servers = await window.electronAPI.getServers();
    renderServers();
    initPTT();

    if (window.electron) {
  window.electron.onPTTState((isPressed) => {
    const status = document.getElementById('ptt-status');
    if (status) {
      status.textContent = isPressed ? '🎤 PTT ACTIVE' : '🔇 PTT OFF';
      status.style.color = isPressed ? 'green' : 'gray';
    }
  });
}

}

function populateLoginServerList() {
  const select = document.getElementById('login-server');
  
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

// Quick login from launcher
async function quickLogin() {
  const serverIndex = document.getElementById('login-server').value;
  const email = document.getElementById('login-email').value.trim();
  const password = document.getElementById('login-password').value;
  
  const errorEl = document.getElementById('login-error');
  const statusEl = document.getElementById('login-status');
  const loginBtn = document.getElementById('login-btn');
  
  errorEl.style.display = 'none';
  statusEl.style.display = 'none';
  
  if (!email || !password) {
    errorEl.textContent = 'Please enter email and password';
    errorEl.style.display = 'block';
    return;
  }
  
  const server = servers[serverIndex];
  if (!server) {
    errorEl.textContent = 'Please select a server';
    errorEl.style.display = 'block';
    return;
  }
  
  loginBtn.disabled = true;
  loginBtn.textContent = 'Logging in...';
  statusEl.textContent = 'Connecting...';
  statusEl.style.display = 'block';
  
  try {
    const authManager = new AuthManager(server.url);
    
    statusEl.textContent = 'Authenticating...';
    const success = await authManager.login(email, password);
    
    if (success) {
      statusEl.textContent = 'Success! Connecting to server...';
      
      // Wait a moment so user sees the success message
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Connect to the server
      await window.electronAPI.connectServer(server.url);
    } else {
      errorEl.textContent = 'Login failed';
      errorEl.style.display = 'block';
      statusEl.style.display = 'none';
    }
  } catch (error) {
    console.error('Login error:', error);
    errorEl.textContent = error.message || 'Login failed';
    errorEl.style.display = 'block';
    statusEl.style.display = 'none';
  } finally {
    loginBtn.disabled = false;
    loginBtn.textContent = 'Login & Connect';
  }
}

// Update renderServers to also update the login dropdown
function renderServers() {
  const listEl = document.getElementById('server-list');
  if (servers.length === 0) {
    listEl.innerHTML = `
      <div class="empty-state">
        <p>No servers added yet.</p>
        <p>Add your first server below to get started.</p>
      </div>
    `;
  } else {
    listEl.innerHTML = servers.map((server, index) => `
      <div class="server-item" onclick="connectToServer(${index})">
        <div>
          <div class="server-name">${escapeHtml(server.name)}</div>
          <div class="server-url">${escapeHtml(server.url)}</div>
        </div>
        <button class="remove-btn" onclick="event.stopPropagation(); removeServer(${index})">
          Remove
        </button>
      </div>
    `).join('');
  }
  
  populateLoginServerList();
}

// Display the server list
function renderServers() {
    const listEl = document.getElementById('server-list');
    
    if (servers.length === 0) {
        listEl.innerHTML = `
            <div class="empty-state">
                <p>No servers added yet.</p>
                <p>Add your first server below to get started. You dirty goblin</p>
            </div>
        `;
        return;
    }

    listEl.innerHTML = servers.map((server, index) => `
        <div class="server-item" onclick="connectToServer(${index})">
            <div>
                <div class="server-name">${escapeHtml(server.name)}</div>
                <div class="server-url">${escapeHtml(server.url)}</div>
            </div>
            <button class="remove-btn" onclick="event.stopPropagation(); removeServer(${index})">
                Remove
            </button>
        </div>
    `).join('');


     populateLoginServerList();
}

// Add a new server
async function addServer() {
    const name = document.getElementById('server-name').value.trim();
    const url = document.getElementById('server-url').value.trim();
    
    if (!name || !url) {
        showError('Please enter both server name and URL');
        return;
    }

    // Basic URL validation
    try {
        new URL(url);
    } catch (e) {
        showError('Please enter a valid URL (e.g., https://chat.example.com)');
        return;
    }

    // Check if server already exists
    if (servers.some(s => s.url === url)) {
        showError('This server is already in your list');
        return;
    }

    servers.push({ name, url });
    await window.electronAPI.saveServers(servers);
    
    document.getElementById('server-name').value = '';
    document.getElementById('server-url').value = '';
    hideError();
    
    renderServers();
}

// Remove a server
async function removeServer(index) {
    if (confirm('Remove this server from your list?')) {
        servers.splice(index, 1);
        await window.electronAPI.saveServers(servers);
        renderServers();
    }
}

// Connect to a server
async function connectToServer(index) {
  const server = servers[index];
  // Connect using the existing API
  await window.electronAPI.connectServer(server.url);
}

// Helper functions
function showError(message) {
    const errorEl = document.getElementById('error-message');
    errorEl.textContent = message;
    errorEl.style.display = 'block';
}

function hideError() {
    const errorEl = document.getElementById('error-message');
    errorEl.style.display = 'none';
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}


async function initPTT() {
  // Just show that PTT is active
  document.getElementById('ptt-key').textContent = 'Left Ctrl (hold)';
  console.log("INIT PTT");
  
  // Listen for PTT state changes
  window.electronAPI.onPTTState((pressed) => {
    console.log("PTT State:", pressed);
    const statusEl = document.getElementById('ptt-status');
    statusEl.textContent = pressed ? '🔴 PRESSED' : 'Released';
    statusEl.style.color = pressed ? '#ff6b6b' : '#333';
  });
  
  // Listen for PTT errors
  window.electronAPI.onPTTError((message) => {
    console.error("PTT Error:", message);
    showError(message);
  });
}
// Event listeners
document.getElementById('add-btn').addEventListener('click', addServer);

document.getElementById('server-url').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') addServer();
});


// Initialize
init();