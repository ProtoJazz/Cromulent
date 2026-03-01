---
phase: 03-voice-reliability
plan: "01"
subsystem: infra
tags: [turn, coturn, metered, webrtc, hmac, finch, elixir]

# Dependency graph
requires: []
provides:
  - "Cromulent.Turn.Provider behaviour with get_ice_servers/1 callback"
  - "Cromulent.Turn.Coturn HMAC-SHA1 time-limited credentials (RFC 8489)"
  - "Cromulent.Turn.Metered REST API credential fetch via Finch"
  - "TURN env var documentation in config/runtime.exs"
affects: [03-voice-reliability-plan-02, 03-voice-reliability-plan-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@behaviour pattern for swappable TURN providers via TURN_PROVIDER env var"
    - "HMAC-SHA1 time-limited credentials using OTP :crypto.mac/4"
    - "Finch HTTP used for external credential API calls within app supervisor"

key-files:
  created:
    - lib/cromulent/turn/provider.ex
    - lib/cromulent/turn/coturn.ex
    - lib/cromulent/turn/metered.ex
  modified:
    - config/runtime.exs

key-decisions:
  - "Use @behaviour for swappable TURN provider selected by TURN_PROVIDER env var with zero code changes"
  - "Use :crypto.mac(:hmac, :sha, ...) not the deprecated :crypto.hmac/3 (removed in OTP 26)"
  - "Env vars read at runtime in provider modules, not at boot in runtime.exs (optional at boot)"
  - "Metered full base URL in TURN_API_URL for flexibility, path appended in code"

patterns-established:
  - "TURN dispatch: caller checks TURN_PROVIDER env var, dispatches to Coturn | Metered | STUN-only"
  - "HMAC-SHA1 credential: username = 'ttl:user_id', password = Base64(HMAC-SHA1(secret, username))"

requirements-completed:
  - VOIC-02

# Metrics
duration: 4min
completed: 2026-03-01
---

# Phase 03 Plan 01: TURN Provider Abstraction Summary

**Three-module TURN server abstraction with Coturn HMAC-SHA1 and Metered.ca REST providers, selectable via TURN_PROVIDER env var at runtime**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-01T18:12:55Z
- **Completed:** 2026-03-01T18:16:00Z
- **Tasks:** 2
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments

- Created `Cromulent.Turn.Provider` behaviour defining `get_ice_servers/1` callback
- Implemented `Cromulent.Turn.Coturn` using `:crypto.mac(:hmac, :sha, ...)` (OTP 26 compatible) for RFC 8489 time-limited credentials
- Implemented `Cromulent.Turn.Metered` using Finch HTTP to Metered.ca REST API, normalizing responses to RTCPeerConnection iceServers format
- Documented all TURN env vars in `config/runtime.exs` as a comment block

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TURN provider behaviour and Coturn implementation** - `0f1929e` (feat)
2. **Task 2: Create Metered provider and extend runtime.exs with TURN env vars** - `a7fb53b` (feat)

## Files Created/Modified

- `lib/cromulent/turn/provider.ex` - `@behaviour Cromulent.Turn.Provider` with `get_ice_servers/1` callback
- `lib/cromulent/turn/coturn.ex` - HMAC-SHA1 Coturn credentials using `:crypto.mac/4` and `Base.encode64/1`
- `lib/cromulent/turn/metered.ex` - Metered.ca REST API fetch via `Finch.request/2` with JSON normalization
- `config/runtime.exs` - TURN env var documentation comment block appended after prod block

## Decisions Made

- **Provider dispatch via env var:** Callers (Plan 03) will read `System.get_env("TURN_PROVIDER")` and dispatch to the appropriate module, defaulting to STUN-only. The behaviour makes this a clean pattern with no `if/else` sprawl.
- **OTP 26 crypto:** Used `:crypto.mac(:hmac, :sha, key, data)` not the removed `:crypto.hmac/3`. The secret is a string from env, passed directly as the key binary.
- **Runtime-only env var reads:** TURN env vars are only read inside provider functions when called, not at application boot. This means the server starts fine without TURN configured — voice just falls back to STUN-only.
- **Metered URL pattern:** `TURN_API_URL` holds the full base URL (e.g. `https://yourapp.metered.live`), path `/api/v2/turn/credentials?secretKey=KEY` is appended in code. More flexible than hardcoding the subdomain pattern.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - both modules compiled clean on first attempt. `:crypto.mac/4` is available in OTP 26 as documented in plan interfaces.

## User Setup Required

None - no external service configuration required. Operators who want TURN support must set env vars (documented in runtime.exs comment block) but this is an optional enhancement.

## Next Phase Readiness

- Plan 03 can now call `Cromulent.Turn.Coturn.get_ice_servers(user_id)` or `Cromulent.Turn.Metered.get_ice_servers(user_id)` depending on `TURN_PROVIDER` env var
- The dispatch pattern for Plan 03: `case System.get_env("TURN_PROVIDER") do "coturn" -> Coturn.get_ice_servers(user_id); "metered" -> Metered.get_ice_servers(user_id); _ -> {:ok, [%{urls: "stun:stun.l.google.com:19302"}]} end`
- No blockers — all three modules compile, STUN-only default requires zero configuration

---
*Phase: 03-voice-reliability*
*Completed: 2026-03-01*

## Self-Check: PASSED

- FOUND: lib/cromulent/turn/provider.ex
- FOUND: lib/cromulent/turn/coturn.ex
- FOUND: lib/cromulent/turn/metered.ex
- FOUND: config/runtime.exs
- FOUND: 03-01-SUMMARY.md
- FOUND commit: 0f1929e (Task 1)
- FOUND commit: a7fb53b (Task 2)
