# Cromulent

## What This Is

A small-scale, self-hostable voice and chat application inspired by Discord. Built with Elixir/Phoenix LiveView on the backend, with an Electron desktop client featuring Rust-based push-to-talk. Aimed at individuals and small groups who want a private, configurable communication platform they control.

v1.0 shipped with a complete communication feature set: @mention autocomplete with keyboard navigation, desktop and web notification delivery with sound alerts, unread tracking, user popovers, bundled TURN server for voice reliability, rich text rendering (markdown, link previews, image embeds), operator feature toggles, and a polished voice experience (mute/deafen, speaking indicators, VAD, audio device selection).

## Core Value

Friends can reliably chat and voice call on a self-hosted server that just works — deploy it, invite people, and use it daily.

## Current Milestone: v1.1 Polish & Distribution

**Goal:** Make Cromulent easier to use and easier to self-host — user customization, Windows client, automated builds, Unraid packaging, and a documentation skeleton.

**Target features:**
- User avatars — admin picks mode: none, URL (user pastes), or Libravatar (auto from email); file uploads deferred
- Display name changes — users can update their shown name
- PTT key binding configuration — Electron client only; key stored in user voice preferences, read from server
- Windows + Linux Electron builds via GitHub Actions → GitHub Releases
- Docker image published to GHCR via GitHub Actions
- Unraid Community Applications XML template pointing at GHCR image
- README: self-hosting deployment guide + technical architecture deep-dive

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
- ✓ @mention autocomplete — type-ahead popup with keyboard navigation, @everyone/@here/@group support — v1.0
- ✓ User tooltip/popover — display name, avatar, online status, and role on hover/click — v1.0
- ✓ @mention notification alerts — desktop (Electron + Web API), sound alerts, unread badges — v1.0
- ✓ Notification inbox — tab showing missed mentions and alerts — v1.0
- ✓ Voice double-join fix — server-side Presence guard prevents duplicate joins — v1.0
- ✓ TURN server — bundled coturn with Docker deployment for reliable voice behind NATs — v1.0
- ✓ Markdown rendering — bold, italic, code blocks, lists, blockquotes via MDEx — v1.0
- ✓ Link previews — Open Graph fetch with title, description, thumbnail card — v1.0
- ✓ Image embeds — inline display of image URLs in message feed — v1.0
- ✓ Feature toggles for self-hosters — voice, registration, link previews, TURN, email confirmation via admin UI — v1.0
- ✓ Mute/deafen controls — VoiceBar buttons, Presence state, PTT guard — v1.0
- ✓ Speaking indicators — green ring on active speaker, voice-first member sort — v1.0
- ✓ Voice activity detection (VAD) — opt-in per-user setting with configurable threshold — v1.0
- ✓ Audio device selection — input/output device picker on voice settings page — v1.0
- ✓ Code syntax highlighting — syntax-highlighted code blocks with language detection — v1.0
- ✓ Unread message counts — per-channel unread badge for non-mention messages — v1.0

### Active

- [ ] User avatars — admin-configurable mode (none / URL / Libravatar); displayed in chat, member list, popovers
- [ ] Display name changes — users can update their shown name
- [ ] PTT key binding — Electron client reads configured key from server; user sets in voice preferences
- [ ] Windows + Linux Electron builds — GitHub Actions → GitHub Releases (.AppImage, .deb, .exe/.msi)
- [ ] Docker image published to GHCR via GitHub Actions on tag
- [ ] Unraid Community Applications XML template pointing at GHCR image
- [ ] README — self-hosting deployment guide + technical architecture deep-dive

### Out of Scope

- OAuth/LDAP/SSO — local accounts sufficient for small-scale self-hosting
- Mobile app — web and Electron desktop cover the use cases for now
- Direct messages — focus on channel-based communication first
- Video chat — audio-only keeps complexity and bandwidth manageable
- General file uploads in chat — no cloud storage; image embeds via URL
- Avatar file uploads (local disk / S3) — deferred to v1.2+; URL and Libravatar cover v1.1
- PTT key binding on web — web tab focus limitation makes this low-value; Electron-only for now
- Multi-node clustering — single-server deployment is the target
- Per-message read receipts — privacy concerns, users feel surveilled
- Email notifications — adds Swoosh production config complexity, overkill for self-hosted
- WYSIWYG editor — massive complexity, breaks LiveView patterns, users expect markdown in chat
- Live markdown preview while composing — complexity vs benefit tradeoff
- Inline GIF search — third-party API dependency, violates self-hosting philosophy
- End-to-end encryption — breaks self-hosted trust model, adds significant complexity

## Context

Cromulent v1.0 is a complete, self-hostable voice and chat platform. The Phoenix LiveView backend handles real-time UI, Phoenix Channels relay WebRTC signaling for voice, and an Electron client provides desktop-native push-to-talk. PostgreSQL stores users, channels, messages, notifications, groups, feature flags, and user voice preferences. The codebase uses Elixir context modules for domain logic, GenServer processes for per-channel state, and PubSub for event broadcasting.

**v1.0 shipped (22 days, 6 phases, 21 plans, ~141k LOC across 356 files changed):**
- Full mention and notification pipeline including desktop OS notifications and sound
- Bundled coturn TURN server with Docker deployment
- Rich text: MDEx markdown, Open Graph link previews, image embeds
- Operator feature toggles configurable via admin UI
- Polished voice: mute/deafen controls, speaking indicators, VAD, audio device selection

## Constraints

- **Tech stack**: Elixir/Phoenix LiveView, PostgreSQL, Electron — established, not changing
- **Deployment**: Single-server self-hosted, Docker-friendly
- **Scale**: Small groups (5-50 users), not designed for large communities
- **Voice**: Peer-to-peer WebRTC, no SFU/media server

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Bundled TURN server (coturn) | Self-hosters shouldn't need external TURN service | ✓ Good — Docker deployment works cleanly |
| Feature toggles via admin UI (DB-backed) | Server owners control what's available without code changes | ✓ Good — upsert pattern, no crash on fresh install |
| Type-ahead popup for @mentions | Good UX without full Discord-style mention chips | ✓ Good — keyboard nav feels natural |
| Peer-to-peer voice (no SFU) | Simpler architecture, sufficient for small groups | ✓ Good |
| MDEx for markdown rendering | Rust-backed parser, safe sanitization via default_sanitize_options() | ✓ Good — fast and XSS-safe |
| Open Graph link previews via async Finch | Fire-and-forget from GenServer cast — no blocking message flow | ✓ Good |
| VAD as opt-in per-user with threshold | Privacy concerns, false positives — user controls sensitivity | ✓ Good |
| Deafen auto-mutes, undeafen does NOT auto-unmute | Consistent with Discord/Slack behavior | ✓ Good |
| TURN credentials generated server-side | Security — never exposed in client config | ✓ Good |
| network_mode: host for Coturn on Linux | Avoids Docker NAT breaking TURN relay | ✓ Good |
| @behaviour pattern for swappable TURN providers | Allows Coturn/Metered swap via TURN_PROVIDER env var | ✓ Good |
| voice_connection_state lifecycle (nil→:connecting→:connected/:disconnected) | Clear state machine, nil on leave prevents stale state | ✓ Good |

---
*Last updated: 2026-03-04 after v1.1 milestone started*
