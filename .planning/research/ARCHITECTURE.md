# Architecture Research

**Domain:** Self-hostable voice and chat application enhancements
**Researched:** 2026-02-26
**Confidence:** HIGH for Phoenix LiveView patterns, MEDIUM for link preview performance

## Feature 1: @Mention Autocomplete

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     SERVER (Phoenix)                     │
├─────────────────────────────────────────────────────────┤
│  ChannelLive.mount/3                                    │
│    ↓                                                    │
│  assign(:mentionable_users, channel_members)            │
│  assign(:mentionable_groups, user_groups)               │
│    ↓                                                    │
│  HEEx template: data-users={JSON} data-groups={JSON}    │
├─────────────────────────────────────────────────────────┤
│                     CLIENT (JavaScript)                  │
├─────────────────────────────────────────────────────────┤
│  MentionAutocomplete Hook                               │
│    ↓                                                    │
│  Tribute.js attached to message input                   │
│    ↓                                                    │
│  trigger: '@' → filter users/groups client-side         │
│    ↓                                                    │
│  Selection inserts @username into input                 │
│    ↓                                                    │
│  Form submit → existing message flow                    │
└─────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| **ChannelLive** | Provide mentionable user/group data | Elixir (`lib/cromulent_web/live/channel_live.ex`) |
| **Channels context** | Query channel members | Elixir (`lib/cromulent/channels.ex`) |
| **MentionAutocomplete Hook** | Attach Tribute.js, manage dropdown | JavaScript (`assets/js/hooks/mention_autocomplete.js`) |
| **Tribute.js** | Autocomplete UI, keyboard navigation | npm package |

### Data Flow

1. `ChannelLive.mount` → query channel members + groups
2. Pass as JSON in `data-users` / `data-groups` attributes
3. Hook `mounted()` → parse JSON, attach Tribute.js to input
4. User types `@` → Tribute.js filters client-side
5. User selects → `@username` inserted into input text
6. Form submit → existing `Messages.create_message/4` → `MentionParser` extracts mentions

### Key Decisions

- **Client-side filtering:** Channel member lists are small (5-50), no need for server-side search
- **`phx-update="ignore"`:** Message input container must be ignored by LiveView to prevent autocomplete race conditions
- **Data refresh:** Re-assign mentionable users when channel membership changes (PubSub)

---

## Feature 2: Notification System

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   TRIGGER (Existing)                     │
├─────────────────────────────────────────────────────────┤
│  Messages.create_message → fan_out_notifications        │
│    ↓                                                    │
│  INSERT INTO notifications (existing)                   │
│    ↓                                                    │
│  PubSub.broadcast("user:#{user_id}", {:mention_changed})│
├─────────────────────────────────────────────────────────┤
│                   DELIVERY CHANNELS                     │
├─────────────────────────────────────────────────────────┤
│  1. IN-APP (Unread badges)                              │
│     - LobbyLive sidebar updates unread/mention counts   │
│     - Bold channel names with unreads                   │
│                                                         │
│  2. DESKTOP NOTIFICATIONS (Electron IPC)                │
│     - LiveView → push_event("notification:show")        │
│     - Hook → window.electronAPI.showNotification(...)   │
│     - Electron main process → OS notification           │
│                                                         │
│  3. SOUND ALERTS (Browser Audio API)                    │
│     - Hook → Howler.js plays mention/message sound      │
│     - Different sounds: mention vs new message          │
└─────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| **Notifications context** | Store notifications, mark read, query counts | Elixir (existing: `lib/cromulent/notifications.ex`) |
| **ChannelLive** | Subscribe to `user:#{user_id}`, handle broadcasts | Elixir (`lib/cromulent_web/live/channel_live.ex`) |
| **LobbyLive / Sidebar** | Display unread/mention counts | Elixir (`lib/cromulent_web/components/sidebar.ex`) |
| **NotificationHook** | Listen for push events, trigger desktop/sound | JavaScript (`assets/js/hooks/notification.js`) |
| **Electron IPC (main)** | Show OS-level desktop notifications | Electron (`electron-client/main.js`) |
| **Electron Preload** | Expose `electronAPI.showNotification()` | Electron (`electron-client/preload.js`) |

### Data Flow: Desktop Notification

```
User mentioned in #general
  ↓
Messages.create_message(...) → transaction
  ↓
Notifications.fan_out_notifications(...) → INSERT notification rows
  ↓
PubSub.broadcast("user:123", {:mention_changed})
  ↓
ALL LiveViews subscribed to "user:123" receive message
  ↓
ChannelLive.handle_info({:mention_changed}, socket)
  ↓
Conditional: If user NOT in channel where mentioned, push desktop notification
  ↓
push_event("notification:show", %{
  title: "#general",
  body: "@john: Hello there!",
  channel_id: channel.id
})
  ↓
NotificationHook.handleEvent("notification:show", payload)
  ↓
if (window.electronAPI) {
  window.electronAPI.showNotification(payload)
} else {
  new Notification(title, {body: body})
}
  ↓
OS displays notification → click navigates to channel
```

### Unread Indicators

**Current state:** `Notifications.unread_counts_for_user/1` and `mention_counts_for_user/1` exist.

**Enhancements:**
1. Bold channel names if `unread_count > 0`
2. Red badge with mention count if `mention_count > 0`
3. Real-time updates via `user:#{user_id}` PubSub subscription

### Key Decisions

- **Notification dedupe:** Use `tag` field with notification_id to replace duplicates in Electron
- **Sound throttling:** Limit to 1 sound per 2 seconds to avoid spam
- **Desktop permission:** Request lazily on first mention, not on app launch

---

## Feature 3: TURN Server Integration

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     DOCKER COMPOSE                      │
├─────────────────────────────────────────────────────────┤
│  services:                                              │
│    postgres: {...}                                      │
│    adminer: {...}                                       │
│    coturn:  ← NEW                                       │
│      image: coturn/coturn:4.6-alpine                    │
│      ports:                                             │
│        - "3478:3478/udp"   # STUN/TURN                  │
│        - "5349:5349/tcp"   # TURNS (TLS)                │
│        - "49152-65535:49152-65535/udp" # Media relay     │
│      volumes:                                           │
│        - ./coturn.conf:/etc/coturn/turnserver.conf       │
└─────────────────────────────────────────────────────────┘
              ↓ (config read by Phoenix)
┌─────────────────────────────────────────────────────────┐
│                     PHOENIX CONFIG                      │
├─────────────────────────────────────────────────────────┤
│  config :cromulent, :ice_servers, [                     │
│    %{urls: "stun:stun.l.google.com:19302"},             │
│    %{urls: "turn:localhost:3478",                       │
│       username: generated, credential: generated}       │
│  ]                                                      │
└─────────────────────────────────────────────────────────┘
              ↓ (passed to client)
┌─────────────────────────────────────────────────────────┐
│                     CLIENT JAVASCRIPT                   │
├─────────────────────────────────────────────────────────┤
│  VoiceRoom Hook receives ice_servers config             │
│    ↓                                                    │
│  new RTCPeerConnection({iceServers: config})            │
│    ↓                                                    │
│  WebRTC: STUN checks → TURN fallback if needed          │
└─────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| **coturn service** | STUN/TURN server for NAT traversal | Docker container (`docker-compose.yml`) |
| **turnserver.conf** | coturn configuration | Config file (`coturn/turnserver.conf`) |
| **TurnCredentials module** | Generate time-limited HMAC credentials | Elixir (new: `lib/cromulent/voice/turn_credentials.ex`) |
| **ChannelLive** | Pass ICE server config to client | Elixir (assigns, push_event) |
| **VoiceRoom.js** | Use ICE servers in RTCPeerConnection | JavaScript (`assets/js/voice.js`) |

### TURN Credential Flow

1. Server starts → coturn running with `static-auth-secret`
2. User joins voice → `ChannelLive` calls `TurnCredentials.generate(user_id)`
3. Generates: `username = "#{timestamp}:#{user_id}"`, `credential = HMAC-SHA1(secret, username)`
4. Credentials sent via `push_event("voice:config", %{ice_servers: [...]})`
5. Client uses credentials in `RTCPeerConnection` constructor
6. Credentials expire after 24 hours (configurable TTL)

### Double-Join Bug Fix

**Problem:** User can join voice channel multiple times creating duplicate peer connections.

**Solution:** State tracking in VoiceState GenServer + client-side guard.

- Server: `VoiceChannel.join/3` checks `VoiceState.is_in_voice?(user_id)` before allowing join
- Client: Before joining, explicitly leave any existing voice connection
- Presence: Use `"#{user_id}:#{socket.id}"` as unique tracking key

---

## Feature 4: Rich Text Rendering

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     MESSAGE FLOW                        │
├─────────────────────────────────────────────────────────┤
│  User types markdown message                            │
│    ↓                                                    │
│  Messages.create_message(body: "**hi**")                │
│    ↓                                                    │
│  Store raw markdown in DB                               │
│    ↓                                                    │
│  PubSub broadcast → All LiveViews                       │
│    ↓                                                    │
│  MessageComponent renders message                       │
│    ↓                                                    │
│  RichText.render(message.body)  ← NEW MODULE            │
│    ↓                                                    │
│  1. Parse markdown (Earmark)                            │
│  2. Sanitize HTML (HtmlSanitizeEx)                      │
│  3. Syntax highlight code blocks (Makeup)               │
│  4. Auto-link bare URLs (Linkify)                       │
│    ↓                                                    │
│  Returns safe HTML → raw() in HEEx template             │
└─────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Library/Implementation |
|-----------|----------------|------------------------|
| **RichText.render/1** | Parse markdown → sanitized HTML | Earmark + HtmlSanitizeEx |
| **RichText.extract_links/1** | Extract URLs from text | Regex or Linkify |
| **LinkPreview.fetch/1** | HTTP GET URL, parse OpenGraph tags | Finch + Floki |
| **RichText.highlight_code/2** | Syntax highlight code blocks | Makeup |
| **MessageComponent** | Render message with rich content | LiveView component |

### Data Flow: Link Previews

```
Message body: "Check out https://example.com"
  ↓
Messages.create_message → store raw text
  ↓
Async: Task.Supervisor spawns LinkPreview.fetch(url)
  ↓
Finch GET → parse HTML with Floki → extract og:title, og:description, og:image
  ↓
Store preview in link_previews table (cached by URL)
  ↓
PubSub broadcast {:link_preview, message_id, preview_data}
  ↓
MessageComponent re-renders with preview card
```

### Key Implementation Decisions

- **Store raw markdown, render on display:** Never store rendered HTML (stale sanitization, storage bloat)
- **Server-side rendering:** Parse and sanitize on server (Earmark + HtmlSanitizeEx), send safe HTML to client
- **Server-side syntax highlighting:** Makeup on server avoids shipping Prism.js (300KB+) to client
- **Async link previews:** Don't block message send on preview fetch — send message, add preview later
- **SSRF protection:** Block private IP ranges, cloud metadata endpoints, enforce timeout/size limits

### Data Schema Changes

```elixir
# New table for link preview caching
create table(:link_previews) do
  add :url, :string, null: false
  add :title, :string
  add :description, :text
  add :image_url, :string
  add :site_name, :string
  timestamps()
end

create unique_index(:link_previews, [:url])
```

---

## Cross-Feature Integration

### Autocomplete + Rich Text
- Autocomplete inserts plain `@username` → Rich text renderer wraps mentions in `<span class="mention">`
- No conflict — autocomplete operates on raw input, rich text operates on display

### Notifications + Rich Text
- Notification body should be plain text (strip markdown)
- `RichText.to_plain_text(body)` strips formatting for notification payload

### TURN + Notifications
- Voice connection failure → show notification with troubleshooting guidance
- `VoiceChannel` broadcasts `{:voice_error, reason}` → LiveView pushes notification

---

## Build Order (Dependency Graph)

```
TURN setup ──┐
             ├──> Voice reliability fixes
Double-join ─┘

Rich text ──> Link previews (depends on rendering pipeline)
             Image embeds (depends on rendering pipeline)
             Code highlighting (depends on rendering pipeline)

Notifications (unread) ──┐
                         ├──> Sound alerts ──> Desktop notifications
Notifications (existing) ┘

Autocomplete ──> (independent)
```

**Recommended phase structure:**
1. **Mentions + Notifications** — @mention autocomplete, unread indicators, notification alerts, sound, desktop notifs
2. **Voice Reliability** — Double-join fix, TURN server integration
3. **Rich Text** — Markdown rendering, link previews, image embeds, code highlighting
4. **Feature Toggles** — Admin controls for enabling/disabling features per instance

Phases 1 and 2 can run in parallel (no dependencies). Phase 3 is independent. Phase 4 wraps everything.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Do This Instead |
|-------------|----------------|-----------------|
| Client-side markdown parsing | XSS risk, inconsistent rendering | Server-side Earmark + HtmlSanitizeEx |
| Polling for autocomplete | HTTP round-trips, server load | Client-side Tribute.js with LiveView data |
| Storing rendered HTML in DB | Stale sanitization, storage bloat | Store raw markdown, render on display |
| Hardcoding TURN credentials in JS | Credentials exposed in DevTools | Server generates per-session credentials via push_event |
| Blocking message send on link preview | 5s timeout blocks UX | Async preview fetch after message insert |

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| **5-20 users** | Current architecture sufficient. No changes needed. |
| **20-50 users** | Background jobs for link previews (Oban), connection pooling for HTTP fetches. |
| **50+ users** | SFU for voice, separate TURN instance, message rendering cache (ETS), async notification delivery. |

Current milestone targets 5-50 users. Inline rendering, P2P voice, bundled TURN are appropriate.

---

*Architecture research for: Cromulent milestone features*
*Researched: 2026-02-26*
*Confidence: HIGH overall, MEDIUM for link preview performance assumptions*
