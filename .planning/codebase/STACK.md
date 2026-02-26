# Technology Stack

**Analysis Date:** 2026-02-26

## Languages

**Primary:**
- **Elixir 1.14+** - Backend application logic, Phoenix framework
- **JavaScript/Node.js** - Frontend LiveView assets and Electron client
- **HTML (HEEx)** - Phoenix LiveView templates in `lib/cromulent_web/`
- **CSS (Tailwind)** - Styling via Tailwind CSS 3.4.3
- **Rust** - Push-to-talk daemon (`electron-client/ptt-daemon/`) for Linux low-latency input

**Build/Config Languages:**
- **TOML** - Rust Cargo manifests (`electron-client/Cargo.toml`)
- **JSON** - Node package manifests and Electron configuration

## Runtime

**Environment:**
- **Elixir/OTP 26.1.2** - Server runtime (from CLAUDE.md)
- **Node.js** - Electron (v40.4.0) and frontend asset bundling
- **Electron 40.4.0** - Desktop client runtime

**Package Manager:**
- **Mix** - Elixir dependency manager and build tool
- **npm** - Node.js package manager for Electron and frontend assets
- Lockfiles: `mix.lock`, `package-lock.json` (electron-client and assets directories)

## Frameworks

**Core Backend:**
- **Phoenix 1.7.20** - Web framework, LiveView, and WebSocket channels
- **Phoenix LiveView 1.0.0** - Server-rendered reactive UI with WebSocket synchronization
- **Phoenix Channels** - Real-time bidirectional communication for voice signaling
- **Ecto 3.10** - Database ORM and query builder
- **Phoenix HTML 4.1** - HTML rendering utilities

**Frontend:**
- **LiveView Hooks** - JavaScript integration with server-rendered components (`voice.js` hooks into VoiceRoom)
- **Flowbite 4.0.1** - UI component library (in `assets/package.json`)

**Testing:**
- **ExUnit** - Elixir built-in testing framework (configured in `config/test.exs`)
- **Floki** - HTML parsing for LiveView tests

**Build/Dev:**
- **esbuild 0.17.11** - JavaScript bundler and minifier
- **Tailwind CSS 3.4.3** - CSS framework with JIT compilation
- **Heroicons v2.1.1** - SVG icon set (via GitHub, sparse checkout)
- **Bandit 1.5** - HTTP/1.1 server adapter for Phoenix (in `config.exs`)
- **Phoenix Live Reload 1.2** - Development hot-reload (`dev` environment only)
- **Phoenix Live Dashboard 0.8.3** - Development dashboard and metrics
- **Electron Packager 19.0.3** - Electron app packaging for distribution

## Key Dependencies

**Authentication & Security:**
- **bcrypt_elixir 3.0** - Password hashing for user registration/login
  - Used in `lib/cromulent/accounts/` for credential management

**Email & HTTP:**
- **Swoosh 1.5** - Email library with multiple adapters
  - Configured: Local adapter in dev (`.planbox` emails in browser), Mailgun/SMTP for production
  - Used in `lib/cromulent/accounts/user_notifier.ex` for confirmation emails
- **Finch 0.13** - HTTP client for Swoosh email delivery
  - Started in `lib/cromulent/application.ex` as supervised process

**Database:**
- **Postgrex 0.0.0+** - PostgreSQL driver for Elixir
- **Ecto SQL 3.10** - SQL query builder and migration tools
- **phoenix_ecto 4.5** - Integration layer between Phoenix and Ecto

**Utilities:**
- **Jason 1.2** - JSON encoding/decoding (configured as `:phoenix` JSON library)
- **Gettext 0.26** - Internationalization framework
- **Telemetry Metrics 1.0** - Metrics collection for dashboards
- **Telemetry Poller 1.0** - Periodic telemetry polling
- **DNS Cluster 0.1.1** - Distributed node discovery via DNS (production clustering)
- **Uniq 0.6** - Unique value generation utilities

**Desktop Client (Electron):**
- **electron-store 11.0.2** - Persistent key-value storage for refresh tokens and device info
- **electron-localshortcut 3.2.1** - Global keyboard shortcut binding (PTT fallback)
- **uiohook-napi 1.5.4** - Cross-platform native global keyboard hooks (Windows/Mac/Linux PTT)

**Rust (PTT Daemon):**
- No external Rust dependencies in current `Cargo.toml` - uses stdlib only for event handling

## Configuration

**Environment Variables:**

Development (`config/dev.exs`):
- `SECRET_KEY_BASE` - Session signing key (dev default in `.envrc`)
- Database: PostgreSQL on `localhost:5469`, user `postgres`, password `example`
- Phoenix server: `localhost:4000` (dev-only)

Production (`config/runtime.exs`):
- `DATABASE_URL` - Required, format: `ecto://USER:PASS@HOST/DATABASE`
- `SECRET_KEY_BASE` - Required, session signing key
- `PHX_HOST` - Public hostname (default: `example.com`)
- `PORT` - HTTP port (default: `4000`)
- `POOL_SIZE` - Database connection pool size (default: `10`)
- `ECTO_IPV6` - Enable IPv6 sockets (set to "true" or "1")
- `DNS_CLUSTER_QUERY` - Optional distributed node discovery query
- `PHX_SERVER` - Set to `true` to enable HTTP server in release

Build Configuration:
- `mix.exs` - Mix project definition with aliases
- `config/config.exs` - General app and dependency configuration
- `config/dev.exs` - Development-specific overrides
- `config/test.exs` - Test-specific overrides
- `config/runtime.exs` - Runtime environment binding
- `config/prod.exs` - Production overrides

Frontend/Asset Build:
- `assets/tailwind.config.js` - Tailwind configuration
- `assets/package.json` - Frontend dependency manifest
- esbuild and Tailwind configured in `config.exs` with install-and-run watchers

## Hardcoded Configuration

**Channels** (in `config/config.exs`):
- `general` (text channel)
- `random` (text channel)
- `voice-main` (voice channel)

**WebRTC ICE Servers** (in `assets/js/voice.js`):
- Google STUN server: `stun:stun.l.google.com:19302` (primary NAT traversal)
- TURN servers: Can be added by uncommenting and setting credentials

**Push-to-Talk Key** (Electron, default in `electron-client/main.js`):
- Default PTT key code: `29` (Left Ctrl)
- Configurable via `electron-store` with key `ptt-key-code`

## Platform Requirements

**Development:**
- **Elixir 1.14+** with Mix
- **PostgreSQL 12+** (Docker: `localhost:5469` via docker-compose)
- **Node.js 16+** (for esbuild, Tailwind, Electron)
- **Rust 1.70+** (only if building PTT daemon from source on Linux)

**Production:**
- **Elixir/OTP 26.1.2** (as per CLAUDE.md)
- **PostgreSQL 12+** (remote or managed)
- **Linux/Unix** for Erlang distribution (optional clustering)

**Electron Desktop Client:**
- **Linux 64-bit** (primary; packaging configured for Linux)
- **macOS/Windows** (via uiohook-napi fallback, untested; globalShortcut fallback available)
- **5MB ASAR package** (estimated with dependencies)

---

*Stack analysis: 2026-02-26*
