---
phase: 03-voice-reliability
plan: "03"
subsystem: api
tags: [elixir, phoenix, channels, presence, webrtc, turn, liveview]

# Dependency graph
requires:
  - phase: 03-01
    provides: TURN provider abstraction (Coturn/Metered/STUN-only) via get_ice_servers pattern

provides:
  - Presence-based duplicate-join guard in VoiceChannel.join/3 returning already_in_channel error
  - Cross-channel auto-leave via push_event("voice:leave") before joining new channel
  - TURN credential injection into push_event("voice:join") ice_servers payload
  - voice_connection_state assign lifecycle (nil -> :connecting -> :connected/:disconnected -> nil)
  - voice_state_changed LiveView event handler for JS-driven state transitions

affects:
  - 03-04 (JS hook and VoiceBar plan — these events and assigns are the server-side contract it consumes)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Presence.list/1 called with topic string (not socket) for cross-socket duplicate detection
    - get_ice_servers/1 private function dispatching on TURN_PROVIDER env var with STUN fallback
    - Cross-channel leave via push_event before join in same LiveView batch — JS processes in order
    - voice_connection_state lifecycle driven by two sources: server on join/leave, JS on state_changed

key-files:
  created: []
  modified:
    - lib/cromulent_web/channels/voice_channel.ex
    - lib/cromulent_web/live/channel_live.ex

key-decisions:
  - "Use Presence.list(topic_string) not Presence.list(socket) — topic-string check catches all sockets/tabs globally, not just current connection"
  - "TURN credential fetch failure falls back to STUN-only (no crash) — preserves voice on most networks"
  - "voice_connection_state starts nil (not in voice), goes :connecting on join, updated to :connected/:disconnected by JS, back to nil on leave"

patterns-established:
  - "Voice connection lifecycle: nil -> :connecting (server) -> :connected/:disconnected (JS via voice_state_changed) -> nil (server leave)"
  - "Cross-channel switch: push_event('voice:leave') then push_event('voice:join') in same handle_event call — guaranteed ordering"

requirements-completed: [VOIC-01, VOIC-02]

# Metrics
duration: 2min
completed: 2026-03-01
---

# Phase 3 Plan 3: Server-Side Voice Reliability Summary

**Presence duplicate-join guard and TURN credential injection wired into VoiceChannel and ChannelLive with voice_connection_state lifecycle**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-03-01T18:16:27Z
- **Completed:** 2026-03-01T18:17:32Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- VoiceChannel.join/3 now rejects duplicate connections with `{:error, %{reason: "already_in_channel"}}` using Phoenix Presence global topic lookup
- ChannelLive.handle_event("join_voice") auto-leaves the current channel before joining a new one, injects TURN/STUN ICE servers, and sets voice_connection_state to :connecting
- New voice_state_changed event handler lets JS push connection state updates back to the server
- leave_voice now clears voice_connection_state to nil alongside clearing voice_channel

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Presence duplicate-join guard to VoiceChannel** - `8fedd59` (feat)
2. **Task 2: Add cross-channel leave, TURN wiring, and connection state to ChannelLive** - `36ca9ce` (feat)

## Files Created/Modified

- `lib/cromulent_web/channels/voice_channel.ex` - join/3 now checks Presence.list("voice:#{channel_id}") and returns already_in_channel error if user key found
- `lib/cromulent_web/live/channel_live.ex` - mount adds voice_channel/voice_connection_state assigns; join_voice gets cross-channel leave + TURN ice_servers + :connecting state; leave_voice clears state; new voice_state_changed handler; private get_ice_servers/1

## Decisions Made

- Used `Presence.list("voice:#{channel_id}")` (topic string) not `Presence.list(socket)` — the topic-string form queries presence for the entire channel topic globally, catching duplicate joins from any tab or connection
- TURN credential fetch failure falls back silently to STUN-only — TURN is best-effort; failing loudly would break voice for everyone when TURN is misconfigured
- `voice_connection_state` driven by two sources: server sets :connecting/:nil, JS pushes :connected/:disconnected via voice_state_changed — clean separation of concerns

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - both files compiled cleanly on first attempt.

## Notes for Plan 04 (JS and VoiceBar)

**Events JS should handle:**

- `voice:join` payload now includes `ice_servers` key — JS should use this array instead of a hardcoded STUN URL
- `voice:leave` — already handled; also fired automatically before a cross-channel join
- JS should push `voice_state_changed` with `state: "connected"` or `state: "disconnected"` to update server-side state

**State transitions available in assigns:**

- `voice_connection_state`: nil | :connecting | :connected | :disconnected
- `voice_channel`: nil | channel struct

**VoiceBar can pattern-match on voice_connection_state** to show appropriate UI (e.g., spinner on :connecting, green indicator on :connected, red on :disconnected, hidden on nil).

## Next Phase Readiness

- Server-side contract is fully in place for Plan 04 to implement the JS hook updates and VoiceBar component
- No blockers — voice channel still works in STUN-only mode without any env vars set

## Self-Check: PASSED

- voice_channel.ex: FOUND
- channel_live.ex: FOUND
- 03-03-SUMMARY.md: FOUND
- Commit 8fedd59 (Task 1): FOUND
- Commit 36ca9ce (Task 2): FOUND

---
*Phase: 03-voice-reliability*
*Completed: 2026-03-01*
