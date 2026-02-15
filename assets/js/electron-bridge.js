// Only run in Electron
if (window.electronAPI) {
  console.log('🖥️  Electron bridge loaded');

  class AuthManager {
    constructor(serverUrl) {
      this.serverUrl = serverUrl;
    }

    async login(email, password) {
      const deviceInfo = await window.electronAPI.getDeviceInfo();
      
      const response = await fetch(`${this.serverUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, ...deviceInfo })
      });

      const data = await response.json();

      if (data.success) {
        await window.electronAPI.storeRefreshToken(
          this.serverUrl,
          data.refresh_token,
          data.user.email
        );
        return await this.autoLogin(data.refresh_token);
      }
      throw new Error(data.error || 'Login failed');
    }

    async autoLogin(refreshToken = null) {
      if (!refreshToken) {
        const auth = await window.electronAPI.getRefreshToken(this.serverUrl);
        if (!auth?.refreshToken) {
          console.log('ℹ️  No stored token found');
          return false;
        }
        refreshToken = auth.refreshToken;
        console.log('🔑 Using stored token for:', auth.email);
      }

      console.log('🔄 Attempting auto-login...');

      const formData = new URLSearchParams();
      formData.append('refresh_token', refreshToken);

      const response = await fetch(`${this.serverUrl}/auto_login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: formData,
        credentials: 'include',
        redirect: 'manual'
      });

      if (response.status === 302 || response.status === 0 || response.type === 'opaqueredirect') {
        console.log('✅ Auto-login successful, session cookie set');
        return true;
      } else {
        console.log('❌ Auto-login failed, status:', response.status);
        await window.electronAPI.clearRefreshToken(this.serverUrl);
        return false;
      }
    }

    async logout() {
      const auth = await window.electronAPI.getRefreshToken(this.serverUrl);
      
      if (auth?.refreshToken) {
        await fetch(`${this.serverUrl}/api/auth/logout`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: auth.refreshToken })
        });
      }

      await window.electronAPI.clearRefreshToken(this.serverUrl);
      window.location.href = `${this.serverUrl}/users/log_in`;
    }
  }

  window.AuthManager = AuthManager;

  // Auto-login on login page
  if (window.location.pathname === '/users/log_in') {
    console.log('📋 On login page, attempting auto-login...');
    const authManager = new AuthManager(window.location.origin);
    authManager.autoLogin().then(success => {
      if (success) {
        console.log('✅ Auto-login successful, redirecting to home');
        window.location.href = '/';
      } else {
        console.log('ℹ️  No valid token, showing login form');
      }
    });
  }
} else {
  console.log('Not running in Electron, skipping bridge');
}