# Phase 2: Notification System - Research

**Researched:** 2026-02-27
**Domain:** Real-time notifications, desktop alerts, Web APIs
**Confidence:** HIGH

## Summary

Phase 2 implements multi-channel notification delivery for @mentions. The codebase already has a robust backend notification system with database-backed tracking, PubSub broadcasting, and mention badge counts. The new work focuses on **frontend delivery mechanisms**: Electron native notifications, Web Notifications API, audible sounds, a notification inbox UI, and user popovers.

The existing infrastructure (`Cromulent.Notifications`, `Notification` schema, `ChannelRead` tracking, and PubSub broadcasts via RoomServer) provides the foundation. The phase adds client-side notification handling triggered by Phoenix PubSub events, sound playback via HTML5 Audio, and UI components (inbox dropdown, user popover tooltips).

**Primary recommendation:** Use Phoenix LiveView's `push_event` to send notification data from server to client, leverage Electron's `new Notification()` API for desktop alerts, Web Notifications API for browser users, HTML5 Audio for sounds, and LiveView components for inbox and popovers. No additional Elixir dependencies needed — client-side JavaScript hooks and LiveView events handle all delivery.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Desktop Alerts:**
- Full context notifications: author name, channel name, and message preview text
- Clicking a notification focuses the app/tab and navigates to the mentioned channel
- Each mention gets its own notification (stack individually, not grouped)
- Single default alert sound plays for all mention notifications
- System detects Electron vs web browser and uses native OS notifications or Web Notifications API accordingly
- Notifications only fire when user is online and not currently viewing the mentioned channel

**Unread Badges & Tracking:**
- Badge system already exists and works with real mention data — no rebuild needed
- Clicking a desktop notification and jumping to the channel auto-clears the mention badge
- New work: ensure desktop notification delivery integrates with the existing badge/tracking system

**Notification Inbox:**
- Bell icon in the top header bar (not in the sidebar)
- Bell icon shows a number badge with unread notification count
- Dropdown panel opens on click with a list of notifications
- Each item shows: author, channel name, message snippet, and timestamp (rich preview)
- Click an item to navigate to that channel
- "Mark all as read" button to clear the inbox
- No per-item dismiss — keep it simple

**User Popover:**
- Triggered by hover with ~300ms delay on any username
- Displays: avatar, display name, online/offline status dot, role badge
- Info only — no quick actions or buttons
- Works everywhere usernames appear: @mentions in messages, sidebar member list, and any other username rendering

### Claude's Discretion

- Notification sound file selection and format
- Exact popover positioning and animation
- Dropdown panel dimensions and scroll behavior
- Web Notifications API permission request flow and timing
- Error handling for denied notification permissions

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

Per-channel notification preferences (NOTF-08), DND mode (NOTF-09), and offline/push notifications (NOTF-10) are already tracked as v2 requirements.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NOTF-01 | System detects whether user is on Electron or web browser client | `window.electronAPI` detection pattern already in `electron-bridge.js` |
| NOTF-02 | Electron users receive native OS desktop notifications when mentioned | Electron `new Notification()` API in main/renderer process, IPC bridge for click handlers |
| NOTF-03 | Web browser users receive Web Notifications API alerts when mentioned | Standard Web Notifications API with `Notification.requestPermission()` |
| NOTF-04 | Notifications only fire when user is online and not viewing the mentioned channel | Server-side filtering via PubSub `user:#{user_id}` topics + client-side visibility check |
| NOTF-05 | User hears an audible sound when mentioned in a channel they're not viewing | HTML5 Audio API with preloaded MP3/OGG sound file |
| NOTF-06 | User can view a notification inbox tab showing missed mentions and alerts | LiveView component with inbox dropdown UI, queries `Notification` schema |
| NOTF-07 | User tooltip/popover shows display name, avatar, online status, and role on hover | LiveView JS hook for hover detection, Flowbite tooltip or custom CSS popover |

</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | 1.1.x | Server-rendered UI with real-time updates | Already in use, provides `push_event` for server-to-client communication |
| Phoenix PubSub | 2.x | User-specific message broadcasting | Already in use, handles `user:#{user_id}` topic pattern for targeted notifications |
| Electron | ~33.x | Desktop app wrapper | Already in use for PTT, provides native notification APIs |
| Web Notifications API | Native | Browser notification system | Standard browser API, no dependencies |
| HTML5 Audio | Native | Sound playback | Standard browser API, no dependencies |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Flowbite | 2.x | Tailwind UI components | Already in use, provides tooltip/dropdown patterns (optional — can use custom CSS) |
| Tippy.js / Floating UI | 6.x / 1.x | Advanced tooltip positioning | If Flowbite tooltips insufficient, use for complex hover popovers (LOW priority) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Web Notifications API | Push API + Service Workers | Overkill for logged-in users, adds complexity, requires VAPID keys |
| Electron Notification | electron-native-notification npm | Unnecessary abstraction, native Electron API is simpler |
| Custom audio player | Howler.js | HTML5 Audio sufficient for single notification sound |
| Tippy.js | CSS anchor positioning (Chrome 135+) | Modern CSS not yet cross-browser, tippy.js more reliable for 2026 |

**Installation:**

No new Elixir dependencies. JavaScript dependencies already installed (Electron, Flowbite). Optional tippy.js if needed:

```bash
cd assets && npm install tippy.js @popperjs/core
```

## Architecture Patterns

### Recommended Project Structure

```
lib/cromulent_web/
├── components/
│   ├── notification_inbox.ex      # Bell icon + dropdown component
│   ├── user_popover.ex             # Hover tooltip component
│   └── layouts/app.html.heex       # Add bell icon to header bar

assets/js/
├── hooks/
│   ├── notification_handler.js     # Desktop notification delivery
│   ├── notification_sound.js       # Audio playback hook
│   └── user_popover.js             # Popover hover logic

priv/static/sounds/
└── mention.mp3                     # Notification sound file
```

### Pattern 1: Server-to-Client Notification Delivery

**What:** Server broadcasts mention event via PubSub, LiveView receives it, pushes event to client JavaScript hook
**When to use:** Every mention creation that requires notification
**Example:**

```elixir
# Server: RoomServer broadcasts mention (already exists)
PubSub.broadcast(Cromulent.PubSub, "user:#{user_id}", {:mention_notification, notification_data})

# Server: LiveView handle_info catches broadcast
def handle_info({:mention_notification, data}, socket) do
  if socket.assigns.channel.id != data.channel_id do
    {:noreply, push_event(socket, "desktop-notification", data)}
  else
    {:noreply, socket}  # User is viewing the channel, don't notify
  end
end
```

```javascript
// Client: JavaScript hook handles event
Hooks.NotificationHandler = {
  mounted() {
    this.handleEvent("desktop-notification", (data) => {
      if (window.electronAPI) {
        this.showElectronNotification(data);
      } else {
        this.showWebNotification(data);
      }
    });
  },

  showElectronNotification(data) {
    const notification = new Notification(data.title, {
      body: data.body,
      icon: "/images/icon.png"
    });
    notification.onclick = () => {
      this.pushEvent("navigate-to-channel", { channel_id: data.channel_id });
    };
  }
}
```

### Pattern 2: User-Specific PubSub Topics

**What:** Subscribe to `user:#{user_id}` topic to receive targeted broadcasts
**When to use:** Any user-specific real-time event (notifications, DMs, system alerts)
**Example:**

```elixir
# Server: Subscribe in LiveView mount
def mount(_params, _session, socket) do
  Phoenix.PubSub.subscribe(Cromulent.PubSub, "user:#{socket.assigns.current_user.id}")
  {:ok, socket}
end

# Server: Broadcast to specific user
PubSub.broadcast(
  Cromulent.PubSub,
  "user:#{user_id}",
  {:mention_notification, %{
    channel_id: channel_id,
    channel_name: channel_name,
    author: author_name,
    message_preview: truncated_body,
    notification_id: notification_id
  }}
)
```

Source: [Phoenix.PubSub documentation](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html) — standard topic naming pattern

### Pattern 3: Notification Inbox Query

**What:** Query unread notifications with associated data for inbox display
**When to use:** Rendering notification inbox dropdown
**Example:**

```elixir
defmodule Cromulent.Notifications do
  def list_unread_notifications(user_id, limit \\ 20) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      join: m in assoc(n, :message),
      join: u in assoc(m, :user),
      join: c in assoc(n, :channel),
      order_by: [desc: n.inserted_at],
      limit: ^limit,
      select: %{
        id: n.id,
        channel_id: c.id,
        channel_name: c.name,
        author: u.username,
        message_preview: fragment("LEFT(?, 100)", m.body),
        inserted_at: n.inserted_at,
        mention_type: n.mention_type
      }
    )
    |> Repo.all()
  end

  def mark_all_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: DateTime.utc_now() |> DateTime.truncate(:second)])
  end
end
```

### Pattern 4: Electron vs Browser Detection

**What:** Check for `window.electronAPI` to determine runtime environment
**When to use:** Branching notification delivery logic
**Example:**

```javascript
// Already established pattern in electron-bridge.js
const isElectron = typeof window.electronAPI !== 'undefined';

if (isElectron) {
  // Use Electron Notification API (works in renderer process)
  const notification = new Notification(title, options);
} else {
  // Use Web Notifications API (requires permission)
  if (Notification.permission === "granted") {
    new Notification(title, options);
  } else if (Notification.permission !== "denied") {
    Notification.requestPermission().then(permission => {
      if (permission === "granted") {
        new Notification(title, options);
      }
    });
  }
}
```

Source: Existing pattern in `/home/protojazz/workspace/cromulent/assets/js/electron-bridge.js`

### Pattern 5: HTML5 Audio for Notification Sound

**What:** Preload audio file, play on notification event
**When to use:** All mention notifications (desktop + web)
**Example:**

```javascript
Hooks.NotificationSound = {
  mounted() {
    // Preload sound
    this.audio = new Audio('/sounds/mention.mp3');
    this.audio.preload = 'auto';

    this.handleEvent("play-notification-sound", () => {
      // Clone audio to allow overlapping sounds
      const sound = this.audio.cloneNode();
      sound.play().catch(err => {
        console.warn('Failed to play notification sound:', err);
      });
    });
  }
}
```

Source: [HTML5 Audio best practices](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/audio)

### Pattern 6: User Popover with Hover Delay

**What:** Show user info tooltip after 300ms hover, hide on mouseout
**When to use:** All username displays (messages, sidebar, autocomplete)
**Example:**

```javascript
Hooks.UserPopover = {
  mounted() {
    this.hoverTimer = null;
    this.el.addEventListener('mouseenter', () => {
      this.hoverTimer = setTimeout(() => {
        this.pushEvent("fetch-user-info", { user_id: this.el.dataset.userId });
      }, 300);
    });

    this.el.addEventListener('mouseleave', () => {
      clearTimeout(this.hoverTimer);
      this.pushEvent("hide-user-info", {});
    });

    this.handleEvent("show-user-popover", (data) => {
      // Render popover with data (avatar, username, online status, role)
      this.showPopover(data);
    });
  }
}
```

Alternative: Use Flowbite's tooltip component with `data-tooltip-target` attributes for simpler implementation.

Source: [Tooltips in Phoenix LiveView](https://dev.to/puretype/tooltips-in-phoenix-liveview-k8e)

### Anti-Patterns to Avoid

- **Broadcasting to all users instead of user-specific topics:** Wasteful, leaks notification data to wrong users
- **Storing notification data in LiveView assigns:** Database is source of truth, query on demand for inbox
- **Autoplay audio without user interaction:** Browsers block autoplay, notification sounds are exception but still handle gracefully
- **Creating notification rows for the message author:** Already filtered in `fan_out_notifications`, don't duplicate
- **Requesting Web Notifications permission on page load:** Browsers penalize this, request after first mention received

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Notification permission state machine | Custom permission tracking | `Notification.permission` property | Browser already tracks granted/denied/default state |
| Audio sprite system for multiple sounds | Custom audio manager | Individual HTML5 Audio elements | Only one sound needed, Audio API handles concurrency |
| Tooltip positioning logic | Manual coordinate calculations | Flowbite tooltips or CSS `popover` attribute | Cross-browser positioning is complex, libraries handle edge cases |
| Desktop notification click routing | Custom Electron IPC | Standard `onclick` handler + LiveView events | Notification API already supports click handlers |
| Sound file format detection | Browser capability detection | Multiple `<source>` elements | HTML5 Audio automatically selects compatible format |

**Key insight:** Browser APIs and existing LiveView patterns solve 95% of notification delivery problems. Don't add libraries unless Flowbite/native APIs prove insufficient during implementation.

## Common Pitfalls

### Pitfall 1: Notification Permission Denied Silently

**What goes wrong:** User denies Web Notifications permission, app continues trying to show notifications, nothing happens, user thinks app is broken

**Why it happens:** `Notification.requestPermission()` returns "denied" but code doesn't check result before attempting notifications

**How to avoid:**
1. Check `Notification.permission` before attempting to show notification
2. If "denied", fall back to in-app visual notification (flash message or inbox badge pulse)
3. Provide UI in settings to re-request permission (user must manually change browser settings if denied)

**Warning signs:** User reports "not getting notifications" on web browser but Electron works fine

### Pitfall 2: Duplicate Notifications for Same Mention

**What goes wrong:** User receives multiple notifications for the same mention (one from PubSub broadcast, one from LiveView re-render, etc.)

**Why it happens:** Multiple code paths trigger notification logic, or client-side event handler doesn't deduplicate

**How to avoid:**
1. Single source of truth: PubSub broadcast via `user:#{user_id}` topic
2. Client-side hook tracks shown notification IDs to prevent duplicates
3. Server-side: Only broadcast when `notified_user_ids` contains user (already done in RoomServer)

**Warning signs:** Notification inbox shows duplicate entries, user hears sound twice for one mention

### Pitfall 3: Notifications Fire When User Is Viewing Channel

**What goes wrong:** User is actively reading channel, still gets desktop notification and sound for new mentions in that channel

**Why it happens:** Server doesn't know which channel user is viewing, broadcasts to all mentioned users

**How to avoid:**
1. Server-side: `handle_info({:mention_notification, data}, socket)` checks `socket.assigns.channel.id != data.channel_id` before pushing event
2. Client-side: Additional check in JavaScript hook verifies document visibility (`document.visibilityState === 'visible'`)
3. Badge still updates even if notification suppressed (user sees unread count)

**Warning signs:** User complains about notifications while actively chatting in a channel

### Pitfall 4: Sound Plays Before User Interaction (Browser Blocks)

**What goes wrong:** First notification sound doesn't play, subsequent ones work fine

**Why it happens:** Browsers block autoplay audio until user has interacted with the page (security policy)

**How to avoid:**
1. First notification can fail silently — this is expected browser behavior
2. Don't show error to user, just log warning
3. After first user interaction (click, keypress), all subsequent sounds work
4. Alternative: Use Web Audio API with unlocked context after user gesture

**Warning signs:** Sound works on second mention but not first after page load

### Pitfall 5: Electron Notification Click Doesn't Navigate

**What goes wrong:** User clicks notification in Electron, app focuses but doesn't navigate to mentioned channel

**Why it happens:** Notification `onclick` handler doesn't communicate with LiveView, or IPC bridge incomplete

**How to avoid:**
1. Notification `onclick` calls `this.pushEvent("navigate-to-channel", { channel_id })` via LiveView hook
2. Server-side: `handle_event("navigate-to-channel", %{"channel_id" => id}, socket)` uses `push_patch` to navigate
3. Electron main process: `ipcMain` handler focuses window before navigation

**Warning signs:** Clicking notification brings app to foreground but stays on current channel

### Pitfall 6: User Popover Position Breaks on Scroll

**What goes wrong:** Popover appears in wrong location after user scrolls, or stays fixed when username moves

**Why it happens:** Absolute positioning doesn't account for scroll offset, or position calculated once on hover

**How to avoid:**
1. Use Flowbite's tooltip positioning (handles scroll automatically)
2. If custom: Recalculate position on scroll events within popover visibility window
3. Use CSS `position: fixed` with viewport-relative coordinates, not absolute

**Warning signs:** Popover appears far from hovered username after scrolling chat history

## Code Examples

Verified patterns from official sources and existing codebase:

### Desktop Notification Delivery (Electron + Web)

```javascript
// assets/js/hooks/notification_handler.js
const NotificationHandler = {
  mounted() {
    this.handleEvent("desktop-notification", (data) => {
      this.showNotification(data);
      this.pushEvent("play-notification-sound", {});
    });
  },

  showNotification(data) {
    const isElectron = typeof window.electronAPI !== 'undefined';
    const title = `${data.author} in #${data.channel_name}`;
    const options = {
      body: data.message_preview,
      icon: '/images/cromulent-icon.png',
      tag: `mention-${data.notification_id}`, // Prevents duplicates
      requireInteraction: false
    };

    if (isElectron) {
      // Electron: works in renderer process
      const notification = new Notification(title, options);
      notification.onclick = () => {
        this.pushEvent("navigate-to-channel", { channel_id: data.channel_id });
      };
    } else {
      // Web: check permission first
      if (Notification.permission === "granted") {
        const notification = new Notification(title, options);
        notification.onclick = () => {
          window.focus();
          this.pushEvent("navigate-to-channel", { channel_id: data.channel_id });
        };
      } else if (Notification.permission === "default") {
        Notification.requestPermission().then(permission => {
          if (permission === "granted") {
            new Notification(title, options).onclick = () => {
              this.pushEvent("navigate-to-channel", { channel_id: data.channel_id });
            };
          }
        });
      }
    }
  }
};

export default NotificationHandler;
```

Source: [Electron Notification API](https://www.electronjs.org/docs/latest/api/notification), [Web Notifications API](https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API/Using_the_Notifications_API)

### Server-Side Notification Broadcasting

```elixir
# lib/cromulent/chat/room_server.ex (modify existing handle_cast)
def handle_cast({:broadcast_message, message, notified_user_ids}, state) do
  # Existing text channel broadcast
  PubSub.broadcast(Cromulent.PubSub, topic(state.channel_id), {:new_message, message})

  # Existing unread count update
  member_ids = Cromulent.Channels.list_channel_member_ids(state.channel_id)
  for user_id <- member_ids do
    PubSub.broadcast(Cromulent.PubSub, "user:#{user_id}", {:unread_changed})
  end

  # NEW: Desktop notification for mentioned users
  for user_id <- notified_user_ids do
    PubSub.broadcast(Cromulent.PubSub, "user:#{user_id}", {:mention_changed})

    notification_data = %{
      channel_id: state.channel_id,
      channel_name: Cromulent.Channels.get_channel(state.channel_id).name,
      author: message.user.username,
      message_preview: String.slice(message.body, 0..100),
      notification_id: message.id
    }

    PubSub.broadcast(Cromulent.PubSub, "user:#{user_id}", {:desktop_notification, notification_data})
  end

  {:noreply, state}
end
```

### LiveView Notification Inbox Component

```elixir
# lib/cromulent_web/components/notification_inbox.ex
defmodule CromulentWeb.Components.NotificationInbox do
  use CromulentWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="relative">
      <button
        phx-click="toggle_inbox"
        phx-target={@myself}
        class="relative p-2 text-gray-400 hover:text-white rounded-full hover:bg-gray-700"
      >
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
        </svg>
        <%= if @unread_count > 0 do %>
          <span class="absolute top-0 right-0 inline-flex items-center justify-center px-1.5 py-0.5 text-xs font-bold leading-none text-white bg-red-600 rounded-full">
            {if @unread_count > 99, do: "99+", else: @unread_count}
          </span>
        <% end %>
      </button>

      <%= if @inbox_open do %>
        <div class="absolute right-0 mt-2 w-96 bg-gray-800 border border-gray-700 rounded-lg shadow-xl z-50 max-h-96 overflow-y-auto">
          <div class="flex items-center justify-between px-4 py-3 border-b border-gray-700">
            <h3 class="text-sm font-semibold text-white">Notifications</h3>
            <%= if @unread_count > 0 do %>
              <button
                phx-click="mark_all_read"
                phx-target={@myself}
                class="text-xs text-indigo-400 hover:text-indigo-300"
              >
                Mark all read
              </button>
            <% end %>
          </div>

          <%= if Enum.empty?(@notifications) do %>
            <div class="px-4 py-8 text-center text-gray-400 text-sm">
              No notifications yet
            </div>
          <% else %>
            <div class="divide-y divide-gray-700">
              <div
                :for={notif <- @notifications}
                phx-click="navigate_to_notification"
                phx-value-channel-id={notif.channel_id}
                phx-target={@myself}
                class="px-4 py-3 hover:bg-gray-700 cursor-pointer"
              >
                <div class="flex items-start gap-3">
                  <div class="flex-shrink-0 w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center text-white text-xs font-medium">
                    {String.first(notif.author) |> String.upcase()}
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm text-white font-medium">
                      <span>{notif.author}</span>
                      <span class="text-gray-400 font-normal"> in </span>
                      <span class="text-indigo-400">#{notif.channel_name}</span>
                    </p>
                    <p class="text-xs text-gray-400 mt-1 line-clamp-2">
                      {notif.message_preview}
                    </p>
                    <p class="text-xs text-gray-500 mt-1">
                      {Calendar.strftime(notif.inserted_at, "%I:%M %p")}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def update(assigns, socket) do
    notifications = Cromulent.Notifications.list_unread_notifications(assigns.current_user.id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:notifications, notifications)
     |> assign(:unread_count, length(notifications))
     |> assign(:inbox_open, assigns[:inbox_open] || false)}
  end

  def handle_event("toggle_inbox", _params, socket) do
    {:noreply, assign(socket, :inbox_open, !socket.assigns.inbox_open)}
  end

  def handle_event("mark_all_read", _params, socket) do
    Cromulent.Notifications.mark_all_read(socket.assigns.current_user.id)
    {:noreply, update(socket, socket.assigns)}
  end

  def handle_event("navigate_to_notification", %{"channel_id" => id}, socket) do
    channel = Cromulent.Channels.get_channel(id)
    send(self(), {:navigate_to_channel, channel})
    {:noreply, assign(socket, :inbox_open, false)}
  end
end
```

### User Popover with Flowbite

```elixir
# lib/cromulent_web/components/user_popover.ex
defmodule CromulentWeb.Components.UserPopover do
  use Phoenix.Component

  attr :user, :map, required: true
  attr :online, :boolean, default: false

  def user_mention(assigns) do
    ~H"""
    <span
      data-popover-target={"user-popover-#{@user.id}"}
      data-popover-trigger="hover"
      data-popover-placement="top"
      class="inline-flex items-center px-1.5 py-0.5 rounded bg-indigo-600/30 text-indigo-300 hover:bg-indigo-600/40 cursor-default font-medium"
    >
      @{@user.username}
    </span>

    <div
      data-popover
      id={"user-popover-#{@user.id}"}
      role="tooltip"
      class="absolute z-50 invisible inline-block w-64 text-sm transition-opacity duration-300 bg-gray-800 border border-gray-700 rounded-lg shadow-lg opacity-0"
    >
      <div class="px-3 py-2">
        <div class="flex items-center gap-3">
          <div class="relative flex-shrink-0">
            <div class="w-12 h-12 rounded-full bg-gray-600 flex items-center justify-center text-white text-lg font-medium">
              {String.first(@user.username) |> String.upcase()}
            </div>
            <%= if @online do %>
              <span class="absolute bottom-0 right-0 w-4 h-4 bg-green-500 border-2 border-gray-800 rounded-full"></span>
            <% end %>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-white truncate">{@user.username}</p>
            <div class="flex items-center gap-1.5 mt-1">
              <span class={"inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{role_color(@user.role)}"}>
                {role_label(@user.role)}
              </span>
              <span class={"text-xs #{if @online, do: "text-green-400", else: "text-gray-400"}"}>
                {if @online, do: "Online", else: "Offline"}
              </span>
            </div>
          </div>
        </div>
      </div>
      <div data-popper-arrow></div>
    </div>
    """
  end

  defp role_color(:admin), do: "bg-red-600 text-white"
  defp role_color(:moderator), do: "bg-purple-600 text-white"
  defp role_color(_), do: "bg-gray-600 text-gray-300"

  defp role_label(:admin), do: "Admin"
  defp role_label(:moderator), do: "Moderator"
  defp role_label(_), do: "Member"
end
```

Source: Flowbite already integrated per `/home/protojazz/workspace/cromulent/CLAUDE.md`, uses `data-popover-*` attributes for hover tooltips

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Service Worker + Push API | Direct Web Notifications API | Stable since 2020 | Simpler for logged-in users, no VAPID keys needed |
| Manual tooltip positioning | CSS anchor positioning (Chrome 135+) | 2025-2026 | Still experimental, Flowbite/tippy.js more reliable |
| Electron `remote` module | `contextBridge` + `ipcRenderer` | Electron 10+ (2020) | Already using secure pattern in preload.js |
| Phoenix Channels for notifications | PubSub + LiveView `push_event` | LiveView 0.18+ (2023) | Less overhead, simpler than dedicated channel |

**Deprecated/outdated:**

- **Electron `remote` module**: Removed in Electron 14, use `contextBridge` (already done in codebase)
- **`Notification.requestPermission()` callback-based**: Now returns Promise, callback deprecated (still works but prefer Promise)
- **Service Worker required for all notifications**: Only needed for offline/push notifications, not for logged-in web users

## Validation Architecture

> This project does not use Nyquist validation (no `workflow.nyquist_validation` setting found in config.json). Test framework info provided for reference.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit 1.18.2 (bundled with Elixir) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test --max-failures 1` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NOTF-01 | Electron detection returns true when `window.electronAPI` exists | unit (JS) | Manual: inspect `electron-bridge.js` logic | ❌ Wave 0 |
| NOTF-02 | Desktop notification created with correct title/body/icon | integration | `mix test test/cromulent_web/live/channel_live_test.exs -x` | ❌ Wave 0 |
| NOTF-03 | Web notification permission requested and notification shown | manual | Browser DevTools inspection | ❌ Manual only |
| NOTF-04 | Notification not sent if user viewing mentioned channel | unit | `mix test test/cromulent/notifications_test.exs::test_no_notification_when_viewing_channel -x` | ❌ Wave 0 |
| NOTF-05 | Audio element plays sound when mention received | integration | `mix test test/cromulent_web/components/notification_sound_test.exs -x` | ❌ Wave 0 |
| NOTF-06 | Notification inbox displays unread notifications | integration | `mix test test/cromulent_web/components/notification_inbox_test.exs -x` | ❌ Wave 0 |
| NOTF-07 | User popover displays on hover with user data | integration | `mix test test/cromulent_web/components/user_popover_test.exs -x` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test --max-failures 1` (fast fail for immediate feedback)
- **Per wave merge:** `mix test` (full suite to catch regressions)
- **Phase gate:** Full suite green + manual browser/Electron testing before `/gsd:verify-work`

### Wave 0 Gaps

Testing challenges for this phase:

- **NOTF-03 (Web Notifications API):** Cannot be automated in ExUnit, requires manual browser testing or Wallaby/Hound (not in project). Mark as manual test checklist.
- **JavaScript hook testing:** No JS test framework detected (Jest/Vitest). Integration tests can verify server-side `push_event` calls but not client-side notification rendering.

Recommended Wave 0 test setup:

- [ ] `test/cromulent/notifications_test.exs` — covers NOTF-04 (notification broadcasting logic)
- [ ] `test/cromulent_web/components/notification_inbox_test.exs` — covers NOTF-06 (inbox rendering and queries)
- [ ] `test/cromulent_web/components/user_popover_test.exs` — covers NOTF-07 (popover HTML rendering)
- [ ] Manual test checklist in PLAN.md for NOTF-02, NOTF-03, NOTF-05 (desktop notifications, permissions, audio playback)

## Sources

### Primary (HIGH confidence)

- [Phoenix.PubSub documentation](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html) - User-specific topic pattern
- [Phoenix LiveView JS Interop](https://hexdocs.pm/phoenix_live_view/js-interop.html) - `push_event` and hooks
- [Electron Notification API](https://www.electronjs.org/docs/latest/api/notification) - Native desktop notifications
- [Web Notifications API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API/Using_the_Notifications_API) - Browser notifications and permissions
- [HTML5 Audio element (MDN)](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/audio) - Sound playback
- Existing codebase files: `lib/cromulent/notifications.ex`, `lib/cromulent/chat/room_server.ex`, `assets/js/electron-bridge.js`

### Secondary (MEDIUM confidence)

- [Building Real-Time Features with Phoenix Live View and PubSub](https://elixirschool.com/blog/live-view-with-pub-sub) - PubSub patterns
- [Tooltips in Phoenix LiveView (DEV)](https://dev.to/puretype/tooltips-in-phoenix-liveview-k8e) - Popover implementation approaches
- [Phoenix LiveViewTest documentation](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html) - Testing patterns

### Tertiary (LOW confidence)

- Web search results on notification best practices (2026) - General guidance, not framework-specific

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - All technologies already in use, official docs verified
- Architecture: HIGH - PubSub pattern confirmed in existing codebase, LiveView event flow established
- Pitfalls: MEDIUM - Based on common notification implementation issues, not Cromulent-specific experience

**Research date:** 2026-02-27
**Valid until:** 2026-04-27 (60 days - stable technologies, minimal API churn expected)

---

**Key Findings:**

1. **Backend is ready:** Notification schema, mention tracking, and PubSub broadcasts already exist. No new Elixir code needed for notification **creation**, only **delivery**.

2. **Three delivery channels:** Electron native (renderer process `new Notification()`), Web Notifications API (permission-gated), and HTML5 Audio (universal sound). Client-side JavaScript hooks handle all three.

3. **Inbox is a LiveView component:** Query `Notification` schema for unread entries, render dropdown with Flowbite styling. Bell icon goes in `app.html.heex` header bar (not sidebar).

4. **User popovers use Flowbite:** `data-popover-*` attributes + hover trigger = zero custom JavaScript. Flowbite already integrated, handles positioning and delays.

5. **Testing limitations:** No JS test framework, so desktop notification rendering and audio playback are manual verification only. ExUnit tests cover server-side logic (PubSub broadcasts, inbox queries).

**Ready for planning:** All architecture patterns identified, no unknowns blocking implementation.
