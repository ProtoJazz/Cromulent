# Features Research

**Domain:** Self-hostable voice and chat application
**Researched:** 2026-02-26
**Confidence:** HIGH (based on analysis of Discord, Slack, Mattermost, Rocket.Chat)

## Feature Categories

### @Mentions

**Table Stakes (P1 - Must Have):**

| Feature | Complexity | Description |
|---------|-----------|-------------|
| @user autocomplete dropdown | Medium | Type @ and get filterable list of users in channel |
| Keyboard navigation | Low | Up/down/enter/escape to navigate autocomplete dropdown |
| @mention highlighting in messages | Low | Visual distinction for mentions in rendered messages |
| @everyone and @here | Low | Broadcast mentions to all channel members or online members |
| @group mentions | Low | Mention user groups (already parsed server-side) |

**Differentiators:**

| Feature | Complexity | Description |
|---------|-----------|-------------|
| Mention chips in input | High | Rich mention tokens in message input (like Discord) |
| Mention preview tooltip | Medium | Hover over @mention to see user card |
| Channel cross-linking | Medium | #channel-name auto-links to channels |

**Anti-Features (Deliberately Avoid):**

| Feature | Why Avoid |
|---------|-----------|
| Rich mention chips in input | High complexity vs value — type-ahead popup is sufficient for small groups |
| @role mentions | Overly complex permission model for small-scale use |

**Dependencies:**
- Requires user/group list accessible to client (already exists via channel membership)
- @mention highlighting depends on rich text rendering pipeline

---

### Notifications

**Table Stakes (P1 - Must Have):**

| Feature | Complexity | Description |
|---------|-----------|-------------|
| @mention alerts (in-app) | Low | Real-time badge/indicator when mentioned |
| Unread channel indicators | Medium | Bold channel names, unread count badges |
| Mention count badges | Low | Red badge with mention count per channel |
| Desktop notifications (Electron) | Medium | OS-level push notifications for mentions |
| Sound alerts | Low | Audible ping for mentions |
| Mark as read on view | Low | Clear unread state when user views channel |

**Differentiators:**

| Feature | Complexity | Description |
|---------|-----------|-------------|
| Notification preferences per channel | Medium | Mute specific channels, customize per-channel |
| Do Not Disturb mode | Low | Suppress all notifications temporarily |
| Notification history/inbox | Medium | View past notifications in a dedicated panel |
| Custom notification sounds | Low | User-selectable sound effects |
| Keyword notifications | Medium | Get notified for specific words, not just mentions |

**Anti-Features (Deliberately Avoid):**

| Feature | Why Avoid |
|---------|-----------|
| Per-message read receipts | Privacy concerns — users feel surveilled |
| Email notifications | Adds Swoosh production config complexity, overkill for self-hosted |
| Push notifications (mobile) | No mobile app in scope |

**Dependencies:**
- Desktop notifications require Electron IPC bridge (exists in preload.js)
- Sound alerts require audio playback library
- Unread indicators depend on existing `channel_reads` and `notifications` tables

---

### Rich Text Rendering

**Table Stakes (P1 - Must Have):**

| Feature | Complexity | Description |
|---------|-----------|-------------|
| Markdown bold/italic/strikethrough | Low | Basic inline formatting |
| Code blocks with syntax highlighting | Medium | Fenced code blocks with language detection |
| Inline code | Low | Backtick-wrapped inline code |
| Auto-linking URLs | Low | Bare URLs become clickable links |
| Lists (ordered/unordered) | Low | Markdown list rendering |
| Blockquotes | Low | > prefixed quote blocks |

**Differentiators:**

| Feature | Complexity | Description |
|---------|-----------|-------------|
| Link previews (unfurling) | High | Fetch og:title, og:description, og:image for URLs |
| Image embeds | Medium | Inline display of image URLs |
| Code syntax highlighting | Medium | Language-aware coloring in code blocks |
| Message editing with markdown preview | Medium | Live preview of formatting while typing |

**Anti-Features (Deliberately Avoid):**

| Feature | Why Avoid |
|---------|-----------|
| WYSIWYG editor | Massive complexity, breaks LiveView patterns, users expect markdown in chat |
| Inline GIF search (Tenor/Giphy) | Third-party API dependency, violates self-hosting philosophy |
| LaTeX/math rendering | Niche use case, large library (KaTeX/MathJax) |
| File attachments | Requires file storage infrastructure (out of scope) |

**Dependencies:**
- Markdown rendering is foundation for link previews and image embeds
- Code highlighting depends on markdown parser detecting language
- Link previews require HTTP client (Finch already in stack) and HTML parser (Floki)

---

### Voice Reliability

**Table Stakes (P1 - Must Have):**

| Feature | Complexity | Description |
|---------|-----------|-------------|
| TURN server for NAT traversal | Medium | Relay fallback when P2P fails behind restrictive NATs |
| Double-join prevention | Low | Prevent same user joining voice channel multiple times |
| Connection state indicators | Low | Show connecting/connected/failed state to user |
| Graceful disconnect handling | Low | Clean up when user closes tab or loses connection |

**Differentiators:**

| Feature | Complexity | Description |
|---------|-----------|-------------|
| Auto-reconnect on connection drop | Medium | Automatically rejoin voice after brief network interruption |
| Voice quality indicators | Medium | Show connection quality (latency, packet loss) |
| Server-side voice activity detection | High | Detect who's speaking without PTT |
| Noise suppression | High | Client-side audio processing to reduce background noise |

**Anti-Features (Deliberately Avoid):**

| Feature | Why Avoid |
|---------|-----------|
| Voice activity detection (VAD) | Privacy concerns, false positives, CPU intensive |
| End-to-end encryption | Breaks self-hosted trust model, adds complexity |
| SFU/media server | Overkill for 5-50 users, P2P is sufficient |
| Video chat | Bandwidth/complexity, audio-only keeps it manageable |

**Dependencies:**
- TURN server is infrastructure (Docker), independent of other features
- Double-join fix depends on VoiceState GenServer (exists)
- Connection indicators depend on WebRTC connection state events

---

## Prioritization Matrix

| Priority | Feature | Effort | Impact | Dependencies |
|----------|---------|--------|--------|-------------|
| P1 | @mention autocomplete | Medium | High | None |
| P1 | Unread indicators | Medium | High | Existing notification tables |
| P1 | @mention notification alerts | Low | High | Existing PubSub |
| P1 | Desktop notifications | Medium | High | Electron IPC |
| P1 | Sound alerts | Low | Medium | Audio library |
| P1 | Markdown rendering | Medium | High | None |
| P1 | TURN server | Medium | High | Docker infrastructure |
| P1 | Double-join fix | Low | Medium | VoiceState GenServer |
| P2 | Link previews | High | Medium | Markdown rendering, HTTP client |
| P2 | Image embeds | Medium | Medium | Markdown rendering |
| P2 | Code syntax highlighting | Medium | Medium | Markdown rendering |
| P3 | Feature toggles | Medium | Medium | All features implemented first |

## MVP Definition

**Minimum for "usable with friends":**
1. @mention autocomplete works reliably
2. Unread indicators show which channels have new messages
3. Desktop notifications fire for mentions (Electron)
4. Sound plays on mention
5. Markdown renders (bold, italic, code, links)
6. Voice works behind NAT (TURN server)
7. No double-join bugs in voice

**Can defer to next milestone:**
- Link previews (nice-to-have, not blocking daily use)
- Image embeds (URLs work fine without inline display)
- Code syntax highlighting (plain code blocks are acceptable)
- Feature toggles (all features enabled by default is fine initially)
- Notification preferences per channel

---
*Features research for: Self-hostable voice and chat application*
*Researched: 2026-02-26*
