# Architecture

**Analysis Date:** 2026-02-26

## Pattern Overview

**Overall:** Layered + Context-driven architecture (Elixir/Phoenix idiom)

**Key Characteristics:**
- Context modules (Accounts, Channels, Messages, Notifications, Groups) encapsulate domain logic and data access
- Phoenix LiveView for server-rendered, real-time UI with bidirectional socket communication
- Phoenix Channels for WebRTC signaling and presence tracking in voice rooms
- Supervision tree with GenServer-based stateful components (RoomServer for chat rooms, VoiceState)
- PubSub-based event broadcasting across the application
- Ecto schemas and changesets for data validation and persistence
- Separate API and web authentication flows (refresh tokens for desktop/API, session cookies for LiveView)

## Layers

**Application Layer:**
- Purpose: Entry point and process supervision
- Location: `lib/cromulent/application.ex`
- Contains: OTP supervisor configuration, process initialization
- Depends on: All child processes (Repo, PubSub, RoomSupervisor, Presence, VoiceState, Endpoint)
- Used by: BEAM runtime at startup

**Context/Domain Layer:**
- Purpose: Business logic, data access, transactions
- Location: `lib/cromulent/{accounts,channels,messages,notifications,groups,chat}.ex`
- Contains: Query functions (prefixed `list_`, `get_`), mutation functions (prefixed `create_`, `update_`, `delete_`), permission checks
- Depends on: Repo, other contexts (Messages depends on Channels, Notifications)
- Used by: Web controllers, LiveViews, channels

**Schema/Model Layer:**
- Purpose: Ecto schema definitions and changesets
- Location: `lib/cromulent/{accounts,channels,messages,notifications,groups}/*.ex` (e.g., `User`, `Channel`, `Message`)
- Contains: `schema` blocks, `changeset/2` functions, validations, relationships
- Depends on: Ecto, Cromulent.UUID7 (custom UUID type)
- Used by: Contexts for queries and inserts

**Web Layer:**
- Purpose: HTTP request handling, LiveView rendering, WebSocket signaling
- Location: `lib/cromulent_web/`
- Contains: Router, Controllers, LiveViews, Channels, Components
- Depends on: Contexts, Endpoint, authentication middleware
- Used by: HTTP clients, browsers, WebSocket clients

**Router & Request Pipeline:**
- Location: `lib/cromulent_web/router.ex`
- Pipelines: `:browser` (with CSRF), `:browser_no_csrf` (for auto-login), `:api` (JSON)
- Live Sessions: `:redirect_if_user_is_authenticated`, `:require_authenticated_user`, `:current_user`
- Routes: Auth flows, user management, channel browsing, admin panel, API endpoints

**Controller Layer:**
- Purpose: HTTP request/response handling
- Location: `lib/cromulent_web/controllers/*.ex`
- Contains: `AuthController` (login/logout/verify), `AutoLoginController` (refresh token to session), `UserSessionController`, `PageController`
- Pattern: `action(conn, params)` → calls context → returns JSON or redirects

**LiveView Layer:**
- Purpose: Real-time, server-rendered UI
- Location: `lib/cromulent_web/live/*.ex`
- Contains: Authentication flows (`UserLoginLive`, `UserRegistrationLive`, etc.), main UX (`ChannelLive`, `LobbyLive`), admin (`AdminLive`)
- Lifecycle: `mount/3` → `handle_params/3` (route change) → `handle_event/3` (user interaction) → `handle_info/2` (broadcasts)
- Uses PubSub subscriptions for real-time updates (e.g., new messages, typing indicators)

**Channel Layer (WebRTC Signaling):**
- Purpose: WebSocket connection management, WebRTC peer coordination
- Location: `lib/cromulent_web/channels/*.ex`
- Contains: `UserSocket` (connects Phoenix.Socket with token auth), `VoiceChannel` (relays SDP offers/answers, ICE candidates, presence tracking)
- Pattern: `join/3` → broadcast presence → `handle_in/3` (receive message) → broadcast to peers
- Uses Presence for tracking online users in voice channels

**Component Layer:**
- Purpose: Reusable LiveView components
- Location: `lib/cromulent_web/components/*.ex`
- Contains: `CoreComponents`, `Sidebar`, `VoiceBar`, `MembersSidebar`, `MessageComponent`, `Layouts`
- Pattern: Stateless or stateful (LiveComponent), render HEEx templates

**Stateful GenServer Layer:**
- Purpose: Channel-level state management and event coordination
- Location: `lib/cromulent/chat/room_server.ex`, `lib/cromulent/voice_state.ex`
- Contains: `RoomServer` (tracks typing indicators, broadcasts messages), `VoiceState` (tracks active voice sessions)
- Supervision: Started via `DynamicSupervisor` (Cromulent.RoomSupervisor) on-demand
- Registry: Via `Cromulent.RoomRegistry` for named lookups

**Presence Layer:**
- Purpose: Distributed presence tracking (who's online in which channel)
- Location: `lib/cromulent_web/presence.ex`
- Used by: VoiceChannel to track online users, JavaScript to show active peers
- Protocol: Presence.track/3, Presence.update/3, Presence.list/1

## Data Flow

**User Login Flow:**
1. Browser/Electron submits credentials to `/users/log_in` (LiveView) or `/api/auth/login` (API)
2. `UserLoginLive` or `AuthController` calls `Cromulent.Accounts.get_user_by_email_and_password/2`
3. If valid, `UserSessionController.create/2` or `AuthController.login/2` generates token
4. LiveView: Session cookie set, redirects to lobby
5. API: Refresh token + device info returned, client stores for auto-login

**Auto-Login Flow (Electron):**
1. Electron reads stored refresh_token
2. POST to `/auto_login` with refresh_token
3. `AutoLoginController.create/2` calls `Cromulent.Accounts.get_user_by_refresh_token/1`
4. If valid, logs in user (session cookie) and redirects to LiveView

**Channel/Message Flow:**
1. User navigates to channel slug via `ChannelLive` mount
2. `ChannelLive.handle_params/3` fetches channel and messages
3. Subscribes to PubSub topic `"text:#{channel_id}"` via `RoomServer.ensure_started/1`
4. User sends message via `handle_event("send_message", ...)`
5. `Messages.create_message/4` validates, inserts, parses mentions
6. `Notifications.fan_out_notifications/4` creates notification rows for @mentions
7. `RoomServer.broadcast_message/3` sends to PubSub → all LiveViews in channel get `{:new_message, message}`
8. LiveView receives via `handle_info({:new_message, message}, ...)`, updates assigns, re-renders

**Voice Flow:**
1. User clicks join voice in `ChannelLive`
2. LiveView sends `voice:join` event to client JS hook
3. `app.js` VoiceRoom hook creates new Voice socket, connects to `/socket`
4. `UserSocket.connect/3` verifies token, returns socket with current_user
5. Client joins `"voice:#{channel_id}"` channel via `VoiceRoom.join()`
6. `VoiceChannel.join/3` broadcasts `peer_joined`, tracks presence
7. Client JS receives presence list, initiates peer-to-peer connections (WebRTC)
8. SDP offer/answer and ICE candidates flow via channel: `sdp_offer`, `sdp_answer`, `ice_candidate`
9. `VoiceChannel.handle_in/3` broadcasts these to target peer
10. Audio streams directly peer-to-peer after connection (not relayed through server)

**Notification (Mention) Flow:**
1. Message with `@username`, `@groupname`, `@everyone`, or `@here` triggers parsing
2. `MentionParser` extracts mention types and IDs
3. `Notifications.fan_out_notifications/4` determines recipients:
   - `@user` → only that user
   - `@everyone` → all channel members
   - `@group` → all group members
   - `@here` → only online users (from Presence)
4. Notification rows inserted in DB
5. PubSub broadcasts `{:mention_changed}` to affected users
6. LiveView refreshes mention counts, badge updates in sidebar

**State Management:**
- **Channel Chat State:** Tracked by `RoomServer` (GenServer) — typing timers, message broadcasts
- **Voice State:** Tracked by `VoiceState` (GenServer) — active voice channels, peer connections
- **LiveView Session State:** Client-side assigns in LiveView socket
- **User Presence:** Distributed via `CromulentWeb.Presence` (using Presence tracking)
- **Unread Counts:** Computed on-demand from `ChannelRead` and `Notification` tables

## Key Abstractions

**Context Modules:**
- Purpose: Domain-driven encapsulation of related functionality
- Examples: `Cromulent.Accounts`, `Cromulent.Channels`, `Cromulent.Messages`, `Cromulent.Notifications`
- Pattern: Public API functions (queries, mutations) with private helpers
- Benefit: Clear boundaries, easy to test, reusable across web and API

**Changeset-based Validation:**
- Purpose: Composable validation before persistence
- Examples: `User.registration_changeset/3`, `Channel.changeset/2`, `Message.changeset/2`
- Pattern: `cast/3` → `validate_*` calls → `unique_constraint` → `Repo.insert/update`
- Benefit: Validation errors collected, returned to client for UX feedback

**PubSub Broadcasts:**
- Purpose: Decoupled real-time event distribution
- Topics: `"text:#{channel_id}"` (messages), `"user:#{user_id}"` (notifications), `"voice:#{channel_id}"` (voice events)
- Consumers: LiveViews subscribe via `Phoenix.PubSub.subscribe/2`, receive via `handle_info/2`

**GenServer Stateful Components:**
- Purpose: Long-lived state for channels, rooms
- Examples: `RoomServer` (per-channel typing state), `VoiceState` (voice sessions)
- Lifecycle: `ensure_started/1` (one-time launch), cast/call operations, automatic cleanup on process termination

**Presence Tracking:**
- Purpose: Distributed user presence without polling
- Mechanism: CRDT-like sync across nodes, metadata per user (online_at, muted, deafened)
- Used for: Voice channel member list, @here mentions

## Entry Points

**HTTP Server:**
- Location: `lib/cromulent_web/endpoint.ex`
- Triggers: Incoming HTTP requests on configured port
- Responsibilities: Static file serving, request parsing, session handling, routing to controllers/LiveViews

**LiveView Mount:**
- Location: `lib/cromulent_web/live/*_live.ex` (e.g., `ChannelLive.mount/3`)
- Triggers: User navigates to route or LiveView connects
- Responsibilities: Initialize assigns, validate auth, load data, subscribe to broadcasts

**WebSocket Connection (Voice):**
- Location: `lib/cromulent_web/channels/user_socket.ex`, `lib/cromulent_web/channels/voice_channel.ex`
- Triggers: Client requests `/socket` with token
- Responsibilities: Token verification, channel join, presence tracking, message relaying

**API Endpoints:**
- Location: `lib/cromulent_web/controllers/auth_controller.ex` (`/api/auth/login`, `/api/auth/verify`, `/api/auth/logout`)
- Triggers: POST requests from Electron or other clients
- Responsibilities: Authenticate, generate/verify tokens, return JSON responses

**Application Start:**
- Location: `lib/cromulent/application.ex`
- Triggers: BEAM VM startup
- Responsibilities: Start Repo (DB connection), PubSub, RoomSupervisor, Presence, Endpoint (HTTP server)

## Error Handling

**Strategy:** Result tuples (`{:ok, result}` / `{:error, reason}`), Ecto changesets, early returns

**Patterns:**
- **Database Operations:** `Repo.insert/update/delete` return `{:ok, record}` or `{:error, changeset}`
- **Context Functions:** `create_message/4` returns `{:ok, message}` or `{:error, reason}` (e.g., `:permission_denied`)
- **LiveView:** `handle_event/3` catches errors, puts flash or updates assigns; crashes propagate to browser disconnect
- **Controllers:** Return JSON error (`:unauthorized`, `:not_found`) or redirect with flash
- **Channels:** Return `{:error, %{reason: "..."}}` to reject join; broadcast errors as events
- **Permission Checks:** Early returns (e.g., `can_write?/2` in `Messages.create_message/4`)

## Cross-Cutting Concerns

**Logging:**
- Framework: Console output via `IO.puts/1` (debug), no structured logging library
- Example: `IO.puts("🔊 after_join firing for user #{socket.assigns.current_user.id}")` in `VoiceChannel.join/3`

**Validation:**
- Ecto changesets with custom validators (e.g., password length, email format, username alphanumeric)
- LiveView client-side form validation before submission
- Context layer permission checks (e.g., `can_write?/2`, `can_delete?/2`)

**Authentication:**
- **LiveView:** Session-based with `UserAuth.fetch_current_user/2` in router pipeline
- **API:** Refresh token-based; Electron stores token, exchanges for session via `/auto_login`
- **Channels:** Phoenix.Token signed with `"user socket"` key; verified in `UserSocket.connect/3`
- Token expiry: 24 hours for socket tokens, 60 days for refresh tokens

**Authorization:**
- Role-based: `:admin` vs `:member`
- Channel-level: `write_permission` enum (`:everyone` vs `:admin_only`)
- Message-level: Only admins can delete (hardcoded in `Messages.can_delete?/2`)
- Channel visibility: Private channels restricted to members

**Data Consistency:**
- Transactions: `Repo.transaction/1` in `Messages.create_message/4` for atomic message + notification insert
- Conflict handling: `Repo.insert(..., on_conflict: :nothing)` for idempotent group membership adds
- Soft-delete: Notifications marked read via `updated_at`; messages hard-deleted

---

*Architecture analysis: 2026-02-26*
