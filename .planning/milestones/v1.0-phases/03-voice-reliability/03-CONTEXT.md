# Phase 3: Voice Reliability - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix two voice problems: (1) add TURN server support so users behind restrictive NATs can connect, (2) prevent a user from appearing in the same voice channel multiple times. Connection state should be clearly visible. Creating voice channels, recording, or multi-channel support are separate phases.

</domain>

<decisions>
## Implementation Decisions

### TURN credential delivery
- Credentials injected at join time via the existing `push_event("voice:join", ...)` payload — adds `ice_servers` key to what already passes `channel_id`, `user_token`, `user_id` to JS
- No extra HTTP round-trip; flows naturally with the existing join event
- 1-hour TTL for credentials
- TURN_SECRET stored as environment variable in `config/runtime.exs` (consistent with SECRET_KEY_BASE, DATABASE_URL)
- HMAC time-limited credential scheme: username = `"timestamp:user_id"`, password = `HMAC-SHA1(secret, username)` — RFC 8489 / Coturn standard

### TURN provider abstraction
- Abstraction layer with pluggable providers selected via `TURN_PROVIDER` env var
- `TURN_PROVIDER=coturn` — HMAC auth using `TURN_URL` + `TURN_SECRET`
- `TURN_PROVIDER=metered` — REST API auth using `TURN_API_KEY` to call Metered.ca
- No `TURN_PROVIDER` set = STUN-only mode (current behavior, graceful default)
- Coturn and Metered.ca are the two concrete providers in this phase; abstraction makes adding more straightforward

### Double-join prevention
- Guard lives in `VoiceChannel.join/3` — check Phoenix Presence for the user_id, reject with `{:error, %{reason: "already_in_channel"}}` if already tracked
- Rejected silently: client `receive("error")` already logs, no user-visible error popup
- Reconnect grace period: rely on Phoenix Presence timeout to clear the old entry; new join attempt succeeds once it clears — no special retry logic needed
- Cross-channel: LiveView `handle_event("join_voice")` checks if `voice_channel` is already assigned; if so, pushes `voice:leave` before `voice:join` to auto-leave the current channel first

### Connection state UI
- Color-coded dot + text label in `VoiceBar`:
  - Yellow dot + "Connecting..." — between channel join and WebRTC channel success
  - Green dot + channel name — connected (channel join succeeded; peers connect as they arrive)
  - Red dot + "Disconnected" — channel join failed or peer connection dropped
- Three states only: connecting / connected / disconnected
- "Connected" triggers immediately on successful Phoenix Channel join (not waiting for a peer)
- No reconnect button — disconnected state shows the existing leave/disconnect button; user rejoins manually by clicking the channel again

### TURN deployment
- Coturn added to `docker-compose.yml` for local development
- Separate `Dockerfile.coturn` for production deployment (Coolify-compatible), references existing `Dockerfile` conventions
- Self-hosted Coturn is the default recommended path; Metered.ca is the managed alternative

### Claude's Discretion
- Exact Elixir module structure for the provider abstraction (behaviour + implementations)
- Coturn container config details in docker-compose (image, ports, config file approach)
- How `voice.js` receives and applies the `ice_servers` payload from the join event
- Error handling when TURN credential generation fails

</decisions>

<specifics>
## Specific Ideas

- Ship with Coturn in docker-compose so developers can test TURN locally without an external service
- Coolify deployment: a `Dockerfile.coturn` separate from the app Dockerfile, so Coturn runs as its own service
- TURN_PROVIDER omitted = STUN-only is intentional — existing deployments keep working without changes

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VoiceState` Agent (`lib/cromulent/voice_state.ex`): Tracks user→channel mapping — already exists but not connected to Channel join guard; useful as a secondary cross-reference
- `VoiceBar` component (`lib/cromulent_web/components/voice_bar.ex`): The hardcoded green dot + channel name here is where connection state display goes
- `push_event("voice:join", ...)` in `channel_live.ex:158`: Already passes metadata to JS; extend this payload to include `ice_servers`
- `ICE_SERVERS` constant in `voice.js:1`: Currently hardcoded STUN-only; replace with dynamic value from join event payload
- `peer.onconnectionstatechange` in `voice.js:196`: Already fires state changes — hook this to drive VoiceBar state updates

### Established Patterns
- Env vars for secrets: `SECRET_KEY_BASE`, `DATABASE_URL` in `config/runtime.exs` — `TURN_SECRET` and `TURN_PROVIDER` follow the same pattern
- Phoenix Presence for voice state: `Presence.track/3` and `Presence.list/1` already used in `VoiceChannel` — double-join guard checks here
- `push_event` + JS hook pattern: LiveView pushes events, JS hooks react — already in place for `voice:join` and `voice:leave`
- docker-compose for local infra: `db` (postgres) and `adminer` already there — `coturn` follows same pattern

### Integration Points
- `VoiceChannel.join/3` — add Presence check before allowing join
- `channel_live.ex handle_event("join_voice")` — add cross-channel auto-leave logic before pushing `voice:join`
- `voice.js VoiceRoom.join()` — consume `ice_servers` from event payload instead of hardcoded constant
- `VoiceBar` component — add connection state prop and dynamic dot/label rendering

</code_context>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-voice-reliability*
*Context gathered: 2026-03-01*
