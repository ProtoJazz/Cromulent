# Codebase Structure

**Analysis Date:** 2026-02-26

## Directory Layout

```
cromulent/
├── lib/                          # Elixir source code
│   ├── cromulent/                # Business logic contexts
│   │   ├── accounts/             # User authentication, tokens
│   │   ├── channels/             # Text/voice channels, membership
│   │   ├── chat/                 # Room servers, typing state
│   │   ├── groups/               # User groups for @mentions
│   │   ├── messages/             # Message creation, mention parsing
│   │   ├── notifications/        # Mention notifications, read tracking
│   │   ├── application.ex        # OTP supervision tree
│   │   ├── repo.ex               # Ecto repository
│   │   ├── mailer.ex             # Email sending config
│   │   └── *.ex                  # Utilities (UUID7, VoiceState, Seeds)
│   │
│   └── cromulent_web/            # Web UI and APIs
│       ├── channels/             # WebSocket handlers (VoiceChannel, UserSocket)
│       ├── components/           # Reusable LiveView components
│       ├── controllers/          # HTTP request handlers
│       ├── live/                 # LiveView pages
│       ├── router.ex             # HTTP route definitions
│       ├── endpoint.ex           # Phoenix endpoint config
│       ├── user_auth.ex          # Authentication middleware
│       └── *.ex                  # Web utilities (Presence, Telemetry)
│
├── assets/                       # Client-side code (JS, CSS)
│   ├── js/                       # JavaScript entry points
│   │   ├── app.js                # Main app setup, LiveSocket config
│   │   ├── voice.js              # WebRTC peer connection management
│   │   └── electron-bridge.js    # Electron-specific IPC
│   ├── vendor/                   # Third-party JS (topbar)
│   ├── tailwind.config.js        # Tailwind CSS config
│   └── package.json              # NPM dependencies
│
├── electron-client/              # Electron desktop app
│   ├── main.js                   # Main process, PTT manager
│   ├── preload.js                # Secure IPC bridge
│   ├── auth-manager.js           # Token storage, auto-login
│   ├── launcher.js               # Server/quick login UI
│   └── ptt-daemon/               # Rust PTT daemon (Linux)
│
├── config/                       # Application configuration
│   ├── config.exs                # Main config
│   ├── dev.exs                   # Development settings
│   ├── prod.exs                  # Production settings
│   └── test.exs                  # Test settings
│
├── priv/                         # Static assets and migrations
│   ├── repo/
│   │   ├── migrations/           # Database schema changes
│   │   └── seeds.exs             # Initial seed data
│   ├── static/                   # Compiled assets (CSS, JS, images)
│   └── gettext/                  # i18n translation files
│
├── test/                         # Test suite
│   ├── cromulent/                # Context tests
│   ├── cromulent_web/            # Web layer tests
│   ├── support/                  # Test helpers
│   └── test_helper.exs           # Test config
│
├── mix.exs                       # Mix project definition, dependencies
└── .envrc                        # Direnv configuration (secrets, env vars)
```

## Directory Purposes

**`lib/cromulent/`:**
- Purpose: Domain business logic, data access, transactions
- Contains: Context modules (Accounts, Channels, Messages, Notifications, Groups), schema definitions, utilities
- Key files:
  - `accounts/` — User registration, login, token generation/verification
  - `channels/` — Channel CRUD, membership queries, permissions
  - `messages/` — Message creation with mention parsing and notification fan-out
  - `notifications/` — Mention notifications, unread/read tracking
  - `chat/room_server.ex` — GenServer for per-channel state (typing indicators)
  - `groups/` — User groups for @mentions
  - `application.ex` — OTP supervision tree, process startup
  - `voice_state.ex` — GenServer tracking active voice sessions

**`lib/cromulent_web/`:**
- Purpose: HTTP request handling, real-time UI, WebSocket signaling
- Contains: Controllers, LiveViews, channels, components, middleware
- Key files:
  - `router.ex` — Route definitions, pipelines, auth guards
  - `endpoint.ex` — Phoenix endpoint config, middleware stack
  - `user_auth.ex` — Authentication/authorization middleware
  - `channels/` — WebSocket handlers for voice signaling
  - `live/` — Server-rendered pages (ChannelLive, LobbyLive, admin, auth flows)
  - `controllers/` — HTTP endpoints (auth, auto-login, session management)
  - `components/` — Reusable UI building blocks

**`assets/js/`:**
- Purpose: Client-side application logic
- Contains: JavaScript modules for real-time UI, WebRTC, Electron integration
- Key files:
  - `app.js` — Phoenix Socket/LiveSocket setup, hook registration
  - `voice.js` — WebRTC PeerConnection management, audio stream handling, PTT UI
  - `electron-bridge.js` — IPC communication with Electron main process

**`electron-client/`:**
- Purpose: Desktop application wrapper and native integrations
- Contains: Electron main/renderer processes, PTT manager, token storage
- Key files:
  - `main.js` — Window management, PTT backend selection, fallback hierarchy
  - `preload.js` — Secure IPC API exposure
  - `auth-manager.js` — Token persistence via electron-store, auto-login flow
  - `launcher.js` — Server selection and quick login UI

**`config/`:**
- Purpose: Application configuration per environment
- Key files:
  - `config.exs` — Shared config (Ecto, Logger, Gettext)
  - `dev.exs` — Development-only settings (code reloading, LiveDashboard)
  - `prod.exs` — Production settings (disable debug, compiled assets)
  - `test.exs` — Test settings (in-memory DB, disabled auth)

**`priv/repo/migrations/`:**
- Purpose: Database schema evolution
- Pattern: Timestamped files (e.g., `20260224140123_create_groups.exs`)
- Contains: Ecto.Migration definitions for tables, indexes, constraints

**`priv/static/`:**
- Purpose: Compiled/processed assets served to browser
- Generated by: `mix phx.digest` (production), esbuild (JS), Tailwind (CSS)
- Served by: Phoenix static plug under `/` path

**`test/`:**
- Purpose: Test suite
- Pattern: Mirrors `lib/` structure
- Examples:
  - `cromulent/accounts_test.exs` — Context tests
  - `cromulent_web/live/user_login_live_test.exs` — LiveView tests
  - `support/` — Test helpers, fixtures, custom assertions

## Key File Locations

**Entry Points:**
- `lib/cromulent/application.ex` — OTP application startup, supervisor tree
- `lib/cromulent_web/endpoint.ex` — HTTP server config, middleware pipeline
- `assets/js/app.js` — Browser-side app initialization

**Configuration:**
- `.envrc` — Environment variables (SECRET_KEY_BASE, DATABASE_URL, etc.)
- `config/` — Environment-specific settings
- `mix.exs` — Dependency definitions, build configuration

**Core Logic:**
- `lib/cromulent/accounts.ex` — User CRUD, auth token generation
- `lib/cromulent/channels.ex` — Channel queries, membership, permissions
- `lib/cromulent/messages.ex` — Message creation, deletion, mention parsing
- `lib/cromulent/notifications.ex` — Mention fan-out, unread counts, read tracking
- `lib/cromulent/groups.ex` — Group CRUD, member queries
- `lib/cromulent/chat/room_server.ex` — Per-channel event coordination (typing, messages)

**Web Routes:**
- `lib/cromulent_web/router.ex` — All HTTP and LiveView routes
- `lib/cromulent_web/controllers/auth_controller.ex` — API auth endpoints (`/api/auth/*`)
- `lib/cromulent_web/controllers/auto_login_controller.ex` — `/auto_login` (Electron refresh token → session)

**Real-Time (Channels & Presence):**
- `lib/cromulent_web/channels/user_socket.ex` — WebSocket connection, token verification
- `lib/cromulent_web/channels/voice_channel.ex` — Voice room signaling (SDP, ICE, PTT state)
- `lib/cromulent_web/presence.ex` — Online user tracking per channel

**LiveView Pages:**
- `lib/cromulent_web/live/lobby_live.ex` — Landing page (redirects to first visible channel)
- `lib/cromulent_web/live/channel_live.ex` — Main chat UI (messages, typing, sidebar)
- `lib/cromulent_web/live/user_login_live.ex` — Authentication form
- `lib/cromulent_web/live/user_registration_live.ex` — Sign-up form
- `lib/cromulent_web/live/user_settings_live.ex` — User profile/preferences
- `lib/cromulent_web/live/admin_live.ex` — Admin panel (users, channels, groups)

**Models (Schemas):**
- `lib/cromulent/accounts/user.ex` — User schema, password hashing, registration changeset
- `lib/cromulent/accounts/user_token.ex` — Auth tokens (session, refresh, email verification)
- `lib/cromulent/channels/channel.ex` — Channel schema, slug generation
- `lib/cromulent/channels/channel_membership.ex` — Channel membership join table
- `lib/cromulent/messages/message.ex` — Message schema, validation
- `lib/cromulent/messages/message_mention.ex` — Message mention join table
- `lib/cromulent/notifications/notification.ex` — Mention notification rows
- `lib/cromulent/groups/group.ex` — User group schema
- `lib/cromulent/groups/group_membership.ex` — Group membership join table

**Components:**
- `lib/cromulent_web/components/core_components.ex` — Generic UI components (buttons, forms, etc.)
- `lib/cromulent_web/components/sidebar.ex` — Channel/group sidebar navigation
- `lib/cromulent_web/components/voice_bar.ex` — Voice channel UI (mute, deafen, PTT)
- `lib/cromulent_web/components/members_sidebar.ex` — Active users in channel
- `lib/cromulent_web/components/message_component.ex` — Individual message rendering
- `lib/cromulent_web/components/layouts.ex` — Page layout templates

## Naming Conventions

**Files:**
- Context modules: `lib/cromulent/{context_name}.ex` (snake_case, plural) — e.g., `accounts.ex`, `channels.ex`
- Schema modules: `lib/cromulent/{context}/{model_name}.ex` (singular) — e.g., `accounts/user.ex`, `channels/channel.ex`
- Web files: `lib/cromulent_web/{type}/{name}_{type}.ex` — e.g., `live/channel_live.ex`, `controllers/auth_controller.ex`
- Migrations: `priv/repo/migrations/{YYYYMMDDHHMMSS}_{snake_case_description}.exs`
- Tests: `test/{mirror_of_lib}/{module_test}.exs` — e.g., `test/cromulent/accounts_test.exs`

**Functions:**
- Query functions: Prefix with `list_` (plural results) or `get_` (single result) — e.g., `list_channels/1`, `get_user/1`
- Mutation functions: Prefix with `create_`, `update_`, `delete_` — e.g., `create_message/4`
- Permission checks: Prefix with `can_` — e.g., `can_write?/2`, `can_delete?/2`
- Private helpers: Prefix with underscore — e.g., `_parse_id/1` (used in pattern matching in `VoiceChannel`)
- Changesets: Suffix with `_changeset` — e.g., `registration_changeset/3`, `changeset/2`

**Variables:**
- Snake_case for Elixir variables — e.g., `current_user`, `channel_id`, `message_body`
- Atom keys for maps — e.g., `%{user_id: 123, channel_id: "abc"}`

**Types (Custom):**
- `Cromulent.UUID7` — Custom Ecto type for primary keys (UUIDv7 binary)
- `Ecto.Enum` — Enum fields — e.g., `role: Ecto.Enum, values: [:admin, :member]`

## Where to Add New Code

**New Feature (e.g., User Roles, Permissions):**
- Primary code: `lib/cromulent/{new_context}.ex` (context module with public API)
- Schema: `lib/cromulent/{new_context}/{model}.ex`
- Web: `lib/cromulent_web/live/{feature}_live.ex` (if UI needed), `lib/cromulent_web/controllers/{feature}_controller.ex` (if API)
- Tests: `test/cromulent/{new_context}_test.exs`, `test/cromulent_web/live/{feature}_live_test.exs`
- Migration: `priv/repo/migrations/{timestamp}_{description}.exs`

**New Component/Module (UI reusable):**
- Implementation: `lib/cromulent_web/components/{component_name}.ex`
- Pattern: Use `defmodule MyComponent do ... def render(assigns) ... end` (function components)
- Import in parent: Add to `lib/cromulent_web.ex` in `html_helpers` quote block

**Utilities (Shared helpers):**
- Location: `lib/cromulent/{context}/` subdirectory or root `lib/cromulent/utils/` if cross-context
- Pattern: Module with functions, e.g., `Cromulent.Messages.MentionParser` for parsing mentions
- Examples: `Cromulent.UUIDv7` (custom type), `Cromulent.Messages.MentionParser` (mention extraction)

**Tests:**
- Unit/context tests: `test/cromulent/{context}_test.exs`
- Integration tests: `test/cromulent_web/live/{live_view}_test.exs`
- Use ExUnit with `describe/1` blocks and `test/3` macros
- Pattern: Setup → Act → Assert; use `conn` or `socket` fixtures

## Special Directories

**`.git/`:**
- Purpose: Version control
- Generated: Yes
- Committed: Yes (with .gitignore)

**`_build/`:**
- Purpose: Compiled Elixir bytecode, dependencies
- Generated: Yes (by `mix compile`, `mix deps.get`)
- Committed: No (.gitignored)

**`deps/`:**
- Purpose: Installed Elixir packages
- Generated: Yes (by `mix deps.get`)
- Committed: No (.gitignored); use `mix.lock` for reproducibility

**`node_modules/`:**
- Purpose: Installed JavaScript packages (Tailwind, esbuild, etc.)
- Generated: Yes (by `npm install` in assets/)
- Committed: No (.gitignored); use `assets/package-lock.json`

**`.elixir_ls/`:**
- Purpose: Language server cache (ElixirLS for editor integration)
- Generated: Yes
- Committed: No (.gitignored)

**`priv/static/`:**
- Purpose: Compiled CSS, JS, images served to browser
- Generated: Yes (by esbuild, Tailwind, mix phx.digest)
- Committed: Yes (pre-compiled for production)

**`rel/`:**
- Purpose: Release artifacts (production deployment config)
- Generated: Yes (by `mix release`)
- Committed: Yes (contains Distillery config)

---

*Structure analysis: 2026-02-26*
