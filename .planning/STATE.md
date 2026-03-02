---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: in_progress
last_updated: "2026-03-02T02:09:36Z"
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 12
  completed_plans: 10
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-26)

**Core value:** Friends can reliably chat and voice call on a self-hosted server that just works
**Current focus:** Phase 4 - Rich Text Rendering

## Current Position

Phase: 4 of 6 (Rich Text Rendering) — IN PROGRESS
Plan: 1 of 2 in current phase — COMPLETE (2026-03-02)
Status: Plan 04-01 complete — MDEx markdown rendering, image embedding, XSS sanitization implemented
Last activity: 2026-03-02 — Plan 04-01 executed and committed

Progress: [███████░░░] 70%

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
| 04 | 1 | 5 min | 5 min |

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

### Roadmap Evolution

- Phase 6 added: Voice improvement

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-03-02
Stopped at: Completed 04-01-PLAN.md — MDEx markdown rendering, image embedding, and XSS sanitization shipped
Resume file: None
