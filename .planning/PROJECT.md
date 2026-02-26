# Cromulent

## What This Is

A small-scale, self-hostable voice and chat application inspired by Discord. Built with Elixir/Phoenix LiveView on the backend, with an Electron desktop client featuring Rust-based push-to-talk. Aimed at individuals and small groups who want a private, configurable communication platform they control.

## Core Value

Friends can reliably chat and voice call on a self-hosted server that just works — deploy it, invite people, and use it daily.

## Requirements

### Validated

- ✓ User registration with email/password and email confirmation — existing
- ✓ Session-based auth (browser) and refresh token auth (Electron) — existing
- ✓ Text channels with real-time messaging via PubSub — existing
- ✓ Voice channels with WebRTC peer-to-peer audio — existing
- ✓ Push-to-talk with multi-backend fallback (Rust daemon, uiohook, globalShortcut) — existing
- ✓ Channel membership and private channels — existing
- ✓ User groups with membership management — existing
- ✓ Basic @mention parsing (@user, @group, @everyone, @here) — existing
- ✓ Notification records created for mentions — existing
- ✓ Admin role with channel write permissions — existing
- ✓ Electron desktop client with auto-login and server selection — existing
- ✓ Presence tracking for online/offline status — existing
- ✓ Typing indicators in text channels — existing

### Active

- [ ] @mention autocomplete — type-ahead popup when user types @ in message input
- [ ] User tooltip/popover — display name, avatar, online status, and role on hover/click
- [ ] @mention notification alerts — real-time alert when mentioned
- [ ] Unread indicators — unread message counts on channels, bold unread channel names
- [ ] Desktop notifications — OS-level push notifications via Electron for mentions
- [ ] Sound alerts — audible notification sounds for mentions and new messages
- [ ] Voice double-join fix — prevent users from joining voice channels multiple times
- [ ] TURN server — bundled coturn for reliable voice behind restrictive NATs
- [ ] Link previews — unfurl URLs with title, description, and thumbnail
- [ ] Markdown rendering — bold, italic, code blocks, lists in chat messages
- [ ] Image embeds — inline display of pasted image URLs
- [ ] Code syntax highlighting — syntax-highlighted code blocks with language detection
- [ ] Feature toggles for self-hosters — enable/disable voice, file uploads, registration, etc. per instance

### Out of Scope

- OAuth/LDAP/SSO — local accounts sufficient for small-scale self-hosting
- Mobile app — web and Electron desktop cover the use cases for now
- Direct messages — focus on channel-based communication first
- Video chat — audio-only keeps complexity and bandwidth manageable
- File uploads — no cloud storage integration; image embeds via URL for now
- Multi-node clustering — single-server deployment is the target

## Context

Cromulent is a brownfield project with a working foundation. The Phoenix LiveView backend handles real-time UI, Phoenix Channels relay WebRTC signaling for voice, and an Electron client provides desktop-native push-to-talk. PostgreSQL stores users, channels, messages, notifications, and groups. The codebase uses Elixir context modules for domain logic, GenServer processes for per-channel state, and PubSub for event broadcasting.

Current gaps: @mentions are parsed server-side but lack client-side autocomplete and rich display. Notifications exist in the database but don't surface well in the UI (no desktop notifications, no sound). Voice works peer-to-peer via Google STUN but has double-join bugs and no TURN fallback for restrictive networks. Messages are plain text with no rich rendering.

## Constraints

- **Tech stack**: Elixir/Phoenix LiveView, PostgreSQL, Electron — established, not changing
- **Deployment**: Single-server self-hosted, Docker-friendly
- **Scale**: Small groups (5-50 users), not designed for large communities
- **Voice**: Peer-to-peer WebRTC, no SFU/media server

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Bundled TURN server (coturn) | Self-hosters shouldn't need external TURN service | — Pending |
| Feature toggles via server config | Server owners control what's available without code changes | — Pending |
| Type-ahead popup for @mentions | Good UX without full Discord-style mention chips | — Pending |
| Peer-to-peer voice (no SFU) | Simpler architecture, sufficient for small groups | ✓ Good |

---
*Last updated: 2026-02-26 after initialization*
