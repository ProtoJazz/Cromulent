---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: completed
stopped_at: Completed 06-04-PLAN.md — Voice settings UI and VAD implementation complete
last_updated: "2026-03-03T18:18:00.000Z"
last_activity: 2026-03-03 — Plan 06-04 executed and committed
progress:
  total_phases: 6
  completed_phases: 5
  total_plans: 21
  completed_plans: 21
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-26)

**Core value:** Friends can reliably chat and voice call on a self-hosted server that just works
**Current focus:** Phase 5 - Feature Toggles

## Current Position

Phase: 6 of 6 (Voice Improvement) — COMPLETE
Plan: 4 of 4 in current phase — COMPLETE (2026-03-03)
Status: Plan 06-04 complete — Voice settings UI with PTT/VAD toggle, device pickers, mic test, and VAD loop in voice.js
Last activity: 2026-03-03 — Plan 06-04 executed and committed

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 1.9 minutes
- Total execution time: 0.13 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 2 | 5 min | 2.5 min |
| 02 | 1 | 2.3 min | 2.3 min |
| 03 | 4 | 4 min | 1 min |
| 04 | 2 | 7 min | 3.5 min |
| 05 | 1 | 3 min | 3 min |
| Phase 06-voice-improvement P03 | 2 | 2 tasks | 3 files |
| Phase 06-voice-improvement P02 | 2 | 2 min | 1 min |
| Phase 06-voice-improvement P04 | 2 | 8 min | 4 min |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Bundled TURN server (coturn) — Self-hosters shouldn't need external TURN service
- Feature toggles via server config — Server owners control features without code changes
- Type-ahead popup for @mentions — Good UX without full Discord-style mention chips
- Dropdown renders above input (not below) for better visibility (01-01)
- Max 5 items visible before scrolling in autocomplete (01-01)
- ARIA attributes added for screen reader accessibility (01-01)
- Tab key selects mention (Discord/Slack behavior) (01-02)
- Stable input ID prevents Hook event listener breakage (01-02)
- Input re-acquisition in updated() handles LiveView DOM replacements (01-02)
- User-specific PubSub topic subscription for desktop notifications (02-01)
- Client-side notification suppression when viewing mentioned channel (02-01)
- Notification sound preloading with audio node cloning for overlapping playback (02-01)
- Permission request on first notification attempt, not on page load (02-01)
- @behaviour pattern for swappable TURN providers (Coturn/Metered) via TURN_PROVIDER env var (03-01)
- Use :crypto.mac/4 not deprecated :crypto.hmac/3 which was removed in OTP 26 (03-01)
- TURN env vars read at runtime in provider modules, not at boot — server starts STUN-only without config (03-01)
- network_mode: host used on Linux to avoid Docker NAT breaking TURN relay (03-02)
- Relay port range kept narrow for local dev (49152-49200); Dockerfile.coturn EXPOSE covers full range for production (03-02)
- TURN_SECRET env var substitution is native Coturn feature — no shell scripting needed (03-02)
- [Phase 03]: Use Presence.list(topic_string) not Presence.list(socket) for duplicate-join guard — global topic check catches all tabs/connections
- [Phase 03]: TURN credential fetch failure falls back to STUN-only silently — preserves voice on most networks without crashing
- [Phase 03]: voice_connection_state lifecycle: nil (mount) -> :connecting (server join) -> :connected/:disconnected (JS via voice_state_changed) -> nil (server leave)
- [03-04]: join() wraps Phoenix Channel receive callbacks in Promise so app.js can use .then()/.catch() to push voice_state_changed
- [03-04]: Mid-call peer drop detection via peer.onconnectionstatechange deferred — channel join .then()/.catch() covers primary case
- [03-04]: connection_state attr defaults to :connecting so existing callers without the attr don't crash
- [04-01]: MDEx 0.11 uses sanitize: MDEx.Document.default_sanitize_options() not features: [sanitize: true] — API changed from pre-0.11
- [04-01]: Image URL regex splits BEFORE MDEx processing — prevents image URLs being double-rendered as both img and anchor
- [04-01]: MDEx default_sanitize_options allows code, pre, strong, em, a, blockquote — no explicit allow_tags needed
- [04-02]: try/rescue wraps Finch.request to convert ArgumentError for invalid URL schemes (javascript:, bare words) into {:error, :fetch_failed}
- [04-02]: Task.start (not Task.async) for fire-and-forget from GenServer cast — no caller awaiting result
- [04-02]: LINK_PREVIEWS=disabled env guard checked at cast time (runtime), not compile time
- [04-02]: og:image stripped to nil unless https:// scheme — prevents javascript: XSS in img src
- [05-01]: feature_flags table uses binary_id (UUID7) PK consistent with all other tables in the project
- [05-01]: get_flags/0 uses Repo.one(Flags) || %Flags{} — no crash on fresh install, returns safe defaults
- [05-01]: upsert_flags/1 detects insert vs update by checking id == nil on returned struct from get_flags/0
- [05-01]: feature_flags assign added in ensure_authenticated authenticated branch only (not unauthenticated path)
- [Phase 06-voice-improvement]: [06-03]: voice_mode stored as :string not Ecto.Enum — allows client extensibility without migration
- [Phase 06-voice-improvement]: [06-03]: vad_threshold validated in range -60 to -20 dB to prevent nonsensical VAD sensitivity values
- [Phase 06-voice-improvement]: [06-03]: get_voice_prefs/1 reads from loaded user struct — no extra DB query for settings page render
- [06-02]: speaking_users stored as plain list of string IDs (not MapSet) for LiveView assign serialization compatibility
- [06-02]: broadcast_from! in voice_channel.ex means sender does not see their own speaking ring — acceptable, self-state can be tracked client-side if needed
- [06-02]: Departed voice users cleared from speaking_users in presence_diff handler to prevent stuck ring indicators
- [06-04]: getUserMedia called before enumerateDevices so browser populates device labels (known browser API requirement)
- [06-04]: VAD uses track.enabled toggle (not mute) to suppress audio without destroying the WebRTC track/renegotiating
- [06-04]: VAD loop cleanup: vadActive=false stops rAF loop; vadAudioCtx.close() releases Web Audio resources in leave()
- [06-04]: setSinkId feature-detected at runtime (Chromium/Electron only; no-op on Firefox)

### Roadmap Evolution

- Phase 6 added: Voice improvement

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-03-03T18:18:00Z
Stopped at: Completed 06-04-PLAN.md — Voice settings UI and VAD implementation complete
Resume file: .planning/phases/06-voice-improvement/06-04-SUMMARY.md
