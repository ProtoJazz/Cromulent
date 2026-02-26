# External Integrations

**Analysis Date:** 2026-02-26

## APIs & External Services

**WebRTC Signaling:**
- **Purpose:** Peer-to-peer voice communication negotiation
- **Implementation:** Server-relayed via Phoenix Channels (`lib/cromulent_web/channels/voice_channel.ex`)
- **What's integrated:** Not an external API; internal Phoenix Channel system
- **SDP/ICE Flow:** Browser clients send offer/answer/candidate messages through `voice:channel_id` channel
  - `sdp_offer` - Initiator sends WebRTC offer
  - `sdp_answer` - Responder sends WebRTC answer
  - `ice_candidate` - Both sides send NAT traversal candidates
  - Server broadcasts all messages to other peers in same voice channel

**Email Service (Conditional):**
- **Service:** Swoosh (pluggable adapter)
- **Current (Dev):** Local in-browser preview at `/dev/mailbox`
- **Required (Prod):** Must configure Swoosh adapter via `config/runtime.exs`
- **Supported Adapters:** Mailgun, SMTP, AWS SES (Swoosh library supports; not configured)
- **What's integrated:** User confirmation emails, password reset emails
  - Implementation: `lib/cromulent/accounts/user_notifier.ex`
  - Adapter selection: Configured in `config/config.exs` (dev: `:local`, production: must set env)

## Data Storage

**Primary Database:**
- **Type/Provider:** PostgreSQL 12+
- **Connection:** Ecto ORM via `lib/cromulent/repo.ex`
- **Client Library:** Postgrex
- **URL Format (Production):** `ecto://USER:PASS@HOST/DATABASE` (via `DATABASE_URL` env var)
- **Development:** `localhost:5469` (docker-compose)
- **Default Credentials (Dev):** `postgres:example`

**Data Models:**
- `users` - User accounts with email, hashed password, username, role, confirmation status
- `users_tokens` - Session/reset tokens (soft-deleted with `:delete_all` cascade)
- `channels` - Text/voice channels (hardcoded in config: general, random, voice-main)
- `channel_memberships` - User-channel associations (permissions)
- `channel_reads` - Track read position per user per channel
- `messages` - Text messages with author and channel
- `message_mentions` - Message-to-user mention relationships
- `groups` - User groups for organizing communities
- `group_memberships` - User-group associations
- `notifications` - User notification records

**File Storage:**
- **Status:** Not detected
- **Assumption:** Using local filesystem only (no S3/cloud storage integration)
- **Upload handling:** No multipart/file upload endpoints detected in router

**Caching:**
- **Status:** None detected
- **Phoenix PubSub:** In-memory ETS-based for real-time features (not persistent cache)
- **Potential Future:** Redis could be added for distributed caching if multi-node deployment needed

## Authentication & Identity

**Auth Provider:**
- **Type:** Custom token-based system (no third-party OAuth/SAML)
- **Implementation:**
  - Password registration/login: Email + bcrypt-hashed password
  - Session tokens: Standard Phoenix session cookies (signed via `SECRET_KEY_BASE`)
  - Refresh tokens: Device-tracked tokens for Electron client
    - Generated in `lib/cromulent/accounts/` → `Accounts.generate_user_refresh_token(user, device_info)`
    - Device info captured: `device_name`, `device_type`, `ip_address`
    - Stored in `users_tokens` table with context `refresh_token`

**Auth Endpoints:**
- `POST /api/auth/login` - Email/password login, returns refresh token
- `POST /api/auth/verify` - Verify refresh token validity
- `POST /api/auth/logout` - Invalidate refresh token
- `POST /auto_login` - Exchange refresh token for session cookie (Electron flow)
- `POST /users/log_in` - Session-based login (LiveView)
- `DELETE /users/log_out` - Session logout
- LiveView auto-auth via `on_mount` hooks: `CromulentWeb.UserAuth` module

**User Confirmation:**
- Email confirmation token sent on registration
- Reset password tokens for forgotten passwords
- Update email tokens for email changes

## Monitoring & Observability

**Error Tracking:**
- **Status:** Not detected
- **Could integrate:** Sentry, Rollbar (not currently configured)

**Logs:**
- **Strategy:** Standard Elixir Logger to console
- **Format (Dev):** `[$level] $message\n` (simple format in `config/dev.exs`)
- **Format (Prod):** `$time $metadata[$level] $message\n` with request IDs
- **Metadata:** `:request_id` attached to all requests
- **No log aggregation detected:** Logs go to stdout (suitable for containerized deployment with Docker log drivers)

**Telemetry:**
- **Framework:** `:telemetry` (Elixir metrics library)
- **Collection:** Telemetry Metrics + Telemetry Poller
- **Dashboard:** Phoenix Live Dashboard (dev only, `/dev/dashboard`) for real-time metrics
- **What's tracked:** HTTP requests, database queries, LiveView events, PubSub broadcasts
- **Metrics reporter:** Configured in `lib/cromulent_web/telemetry.ex` (standard setup)

## CI/CD & Deployment

**Hosting:**
- **Status:** Not detected
- **Infrastructure:** Not configured
- **Current Setup:** Development on localhost with PostgreSQL via docker-compose
- **Deployment Target:** Ready for containerization (Elixir + OTP release compatible)
- **Release Build:** Use `mix release` to create production binary

**CI Pipeline:**
- **Status:** None detected (no `.github/workflows`, `.gitlab-ci.yml`, etc.)
- **Testing:** Manual via `mix test`

**Docker/Container:**
- **Status:** PostgreSQL/Adminer available via `docker-compose up`
- **App containerization:** Not present; would need Dockerfile for production

## Environment Configuration

**Critical Environment Variables (Production):**
1. `DATABASE_URL` - PostgreSQL connection string (required, will error if missing)
2. `SECRET_KEY_BASE` - 64-byte base64-encoded secret for session/CSRF signing (required)
3. `PHX_HOST` - Hostname for URL generation (default: `example.com`)
4. `PORT` - HTTP listen port (default: `4000`)
5. `PHX_SERVER` - Set to `true` to enable HTTP server in Erlang release (required for deployed binary)
6. `POOL_SIZE` - Database connection pool size (default: `10`)
7. `ECTO_IPV6` - Enable IPv6 (optional, set to "true" or "1")
8. `DNS_CLUSTER_QUERY` - Node discovery for clustering (optional)

**Secrets Location:**
- Development: `.envrc` file (Git-ignored, local only)
- Production: Environment variables injected at container/instance startup (12-factor)
- Never committed to Git: `.env`, `.env.local`, `.env.*.local`

**Development Defaults (in `.envrc`):**
```
SECRET_KEY_BASE=hClp2yDdy2vdJYFO2FkryP/dDR4TMe8ZqUhbZHFBR87Eze+CPW7ThhD+hXbHkkhT
DATABASE_URL=ecto://postgres:example@localhost:5469/cromulent_dev
```

**Electron Client Configuration:**
- Server URL: Configured in launcher (user selectable at runtime)
- Refresh token storage: `electron-store` (OS-native encrypted storage)
  - macOS: Keychain
  - Windows: Credential Manager
  - Linux: Plain file (unencrypted) in `~/.config/chromulent-voice-chat/`
- Device info stored: Device name, type (`electron`), IP address (captured at login)

## Webhooks & Callbacks

**Incoming Webhooks:**
- **Status:** None detected
- **Not implemented:** No external service can trigger app actions

**Outgoing Webhooks:**
- **Status:** None detected
- **Not implemented:** App does not call external APIs beyond email delivery

**LiveView Callbacks:**
- Presence tracking: Built-in Phoenix Presence (in-memory, not persistent)
- Channel callbacks: `:after_join`, `:terminate` in `voice_channel.ex`

## Media & WebRTC

**Real-Time Communication:**
- **Protocol:** WebRTC 1.0 (browser native)
- **Signaling Server:** Phoenix Channels (relays SDP offers/answers and ICE candidates)
- **Media Path:** Peer-to-peer direct (not through server)
- **Audio Codec:** Browser default (typically Opus for voice)
- **NAT Traversal:** Google STUN server (`stun.l.google.com:19302`)
- **Push-to-Talk (PTT):**
  - Desktop: Rust daemon (Linux) → uiohook-napi (Windows/Mac) → Electron globalShortcut (fallback)
  - Web: Browser keyboard events on spacebar or configurable key
  - Implementation: `assets/js/voice.js` VoiceRoom class
  - State broadcast: `ptt_state` channel message to track active speakers

**Audio Input:**
- **Browser:** `navigator.mediaDevices.getUserMedia({ audio: true })`
- **Electron:** Same browser API (WebView), with native PTT fallback for system-wide hotkey
- **Permissions:** User must grant microphone access (browser permission prompt)
- **Latency:** WebRTC default (50-150ms p2p depending on network)

---

*Integration audit: 2026-02-26*
