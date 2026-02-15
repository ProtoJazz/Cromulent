class AuthManager {
  constructor(serverUrl) {
    this.serverUrl = serverUrl;
  }

  /**
   * Login with email/password and store refresh token
   */
  async login(email, password) {
    try {
      const deviceInfo = await window.electronAPI.getDeviceInfo();
      console.log('🔐 Logging in to:', this.serverUrl);

      const response = await fetch(`${this.serverUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          password,
          ...deviceInfo
        })
      });

      const data = await response.json();

      if (data.success) {
        console.log('✅ Login successful');
        
        // Store refresh token
        await window.electronAPI.storeRefreshToken(
          this.serverUrl,
          data.refresh_token,
          data.user.email
        );

        // Exchange for session cookie
        return await this.autoLogin(data.refresh_token);
      } else {
        throw new Error(data.error || 'Login failed');
      }
    } catch (error) {
      console.error('❌ Login error:', error);
      throw error;
    }
  }

  /**
   * Auto-login using stored refresh token
   * Returns true if successful, false otherwise
   */
  async autoLogin(refreshToken = null) {
    try {
      // If no token provided, get from storage
      if (!refreshToken) {
        const auth = await window.electronAPI.getRefreshToken(this.serverUrl);
        if (!auth || !auth.refreshToken) {
          console.log('ℹ️  No stored token for:', this.serverUrl);
          return false;
        }
        refreshToken = auth.refreshToken;
        console.log('🔑 Using stored token for:', auth.email);
      }

      console.log('🔄 Attempting auto-login...');

      // Exchange refresh token for session cookie
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
        // Token might be expired, clear it
        await window.electronAPI.clearRefreshToken(this.serverUrl);
        return false;
      }
    } catch (error) {
      console.error('❌ Auto-login error:', error);
      return false;
    }
  }

  /**
   * Logout - revoke token and clear storage
   */
  async logout() {
    try {
      const auth = await window.electronAPI.getRefreshToken(this.serverUrl);
      
      if (auth && auth.refreshToken) {
        console.log('🚪 Logging out from:', this.serverUrl);
        
        // Revoke token on server
        await fetch(`${this.serverUrl}/api/auth/logout`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: auth.refreshToken })
        });
      }

      // Clear local storage
      await window.electronAPI.clearRefreshToken(this.serverUrl);
      
      console.log('✅ Logged out');
      
      // Redirect to login
      window.location.href = `${this.serverUrl}/users/log_in`;
    } catch (error) {
      console.error('❌ Logout error:', error);
    }
  }
}

// Make it globally available
window.AuthManager = AuthManager;