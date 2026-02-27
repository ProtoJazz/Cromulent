const NotificationHandler = {
  mounted() {
    // Preload notification sound
    this.audio = new Audio('/sounds/notification.mp3');
    this.audio.preload = 'auto';

    this.handleEvent("desktop-notification", (data) => {
      this.showNotification(data);
      this.playSound();
    });
  },

  showNotification(data) {
    const isElectron = typeof window.electronAPI !== 'undefined';
    const title = `${data.author} in #${data.channel_name}`;
    const options = {
      body: data.message_preview,
      icon: '/images/logo.svg',
      tag: `mention-${data.notification_id}`,  // Prevents duplicate notifications
      requireInteraction: false
    };

    if (isElectron) {
      // Electron: Notification API works directly in renderer process
      const notification = new Notification(title, options);
      notification.onclick = () => {
        this.pushEvent("navigate-to-channel", { channel_slug: data.channel_slug });
      };
    } else {
      // Web browser: check/request permission
      if (Notification.permission === "granted") {
        const notification = new Notification(title, options);
        notification.onclick = () => {
          window.focus();
          this.pushEvent("navigate-to-channel", { channel_slug: data.channel_slug });
        };
      } else if (Notification.permission === "default") {
        // Request permission on first notification attempt (not on page load)
        Notification.requestPermission().then(permission => {
          if (permission === "granted") {
            const notification = new Notification(title, options);
            notification.onclick = () => {
              window.focus();
              this.pushEvent("navigate-to-channel", { channel_slug: data.channel_slug });
            };
          }
        });
      }
      // If "denied", silently skip — user chose to block notifications
    }
  },

  playSound() {
    // Clone audio node to allow overlapping sounds if multiple notifications fire rapidly
    const sound = this.audio.cloneNode();
    sound.play().catch(err => {
      // Browsers block autoplay before first user interaction — this is expected
      console.warn('Notification sound blocked (requires user interaction first):', err.message);
    });
  }
};

export default NotificationHandler;
