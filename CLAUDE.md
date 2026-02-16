# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cromulent is a multi-platform voice chat application with an Elixir/Phoenix backend, LiveView+JS frontend, and an Electron desktop client with Rust-based push-to-talk support.

## Common Commands

### Phoenix Server
```bash
mix setup                  # Install deps, create DB, run migrations, build assets
mix phx.server             # Start dev server (localhost:4000)
mix test                   # Run all tests
mix test test/path_test.exs # Run a single test file
mix test test/path_test.exs:42 # Run a specific test by line number
mix ecto.migrate           # Run database migrations
mix ecto.reset             # Drop, create, and migrate database
```

### Electron Client (run from electron-client/)
```bash
npm start                  # Run Electron app
npm run build              # Package into dist/
```

### Infrastructure
```bash
docker compose up          # Start PostgreSQL (port 5469) + Adminer (port 8080)
```

## Architecture

### Backend (lib/)
- **Phoenix LiveView** for real-time server-rendered UI
- **Phoenix Channels** for WebRTC signaling (`voice_channel.ex` relays SDP offers/answers, ICE candidates, PTT state)
- **Ecto + PostgreSQL** for persistence (users, auth tokens with device tracking)
- Token-based auth (refresh tokens for API/Electron) and session-based auth (browser cookies)
- Channels are hardcoded in config (general, random, voice-main)

### Frontend (assets/js/)
- `voice.js` — WebRTC peer connection management, audio streaming
- `electron-bridge.js` — Electron-specific integration
- `user_socket.js` — Phoenix socket/channel setup
- LiveView hooks bridge server-rendered HTML with client-side JS (e.g., VoiceRoom hook)

### Electron Desktop Client (electron-client/)
- `main.js` — Main process, PTT manager with multi-backend fallback
- `preload.js` — Secure IPC bridge exposing APIs to renderer
- `auth-manager.js` — Token storage and auto-login flow
- `launcher.js/html` — Server selection and quick login UI

### Push-to-Talk Fallback Hierarchy
1. **Rust daemon** (`ptt-daemon/`) — Linux primary, uses evdev for low-latency raw input
2. **uiohook-napi** — Cross-platform global keyboard hooks (Windows/Mac/fallback)
3. **globalShortcut** — Electron-based toggle mode (last resort)

### Voice Flow
Clients join a `voice:channel_id` Phoenix Channel. The server relays WebRTC signaling messages (SDP, ICE) between peers. Audio streams directly peer-to-peer after connection establishment. Uses Google STUN servers for NAT traversal.

### Auth Flow
Login produces a refresh token → Electron stores it via electron-store with device info → auto-login uses `/api/auto_login` to get a session cookie for the WebView.

## Environment

- PostgreSQL default: `localhost:5469`, user `postgres`, password `example`
- `SECRET_KEY_BASE` and `DATABASE_URL` configured via `.envrc` or environment variables
- Elixir 1.18.2, Erlang/OTP 26.1.2
