---
phase: 06-voice-improvement
plan: "02"
subsystem: ui
tags: [liveview, pubsub, phoenix-channels, presence, voice, ptt]

# Dependency graph
requires:
  - phase: 06-voice-improvement
    provides: voice_mode field in feature_flags schema (06-03 dependency)
provides:
  - speaking_users LiveView assign maintained by ptt_state PubSub events
  - Green ring-2 ring-green-400 on speaking voice participants in left sidebar
  - Voice participants sorted first in members sidebar Online section
affects: [06-voice-improvement]

# Tech tracking
tech-stack:
  added: []
  patterns: [MapSet for O(1) membership checks on voice user IDs, PubSub hook clause for ptt_state events before catch-all]

key-files:
  created: []
  modified:
    - lib/cromulent_web/user_auth.ex
    - lib/cromulent_web/components/sidebar.ex
    - lib/cromulent_web/components/members_sidebar.ex
    - lib/cromulent_web/components/layouts/app.html.heex

key-decisions:
  - "speaking_users stored as plain list of string IDs (not MapSet) for LiveView assign serialization compatibility"
  - "broadcast_from! in voice_channel.ex means sender does not see their own speaking ring — acceptable, self-ring via client-side state instead"
  - "Departed voice users cleared from speaking_users in presence_diff handler to prevent stuck indicators"

patterns-established:
  - "PubSub hook clauses added before catch-all in handle_presence_info for each new event type"
  - "Voice sort uses Enum.sort_by with 0/1 keys on MapSet membership for stable ordering"

requirements-completed: [VOIC-SPEAKING, VOIC-SORT]

# Metrics
duration: 2min
completed: 2026-03-03
---

# Phase 6 Plan 02: Speaking Indicators and Voice-First Sort Summary

**Green ring on speaking voice participants in sidebar via ptt_state PubSub events, with voice users sorted first in members sidebar Online section**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-03T18:03:39Z
- **Completed:** 2026-03-03T18:05:30Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- user_auth.ex maintains a `speaking_users` list (string IDs) updated by ptt_state PubSub broadcasts from voice_channel.ex
- Departed voice users are cleaned from speaking_users on every presence_diff event
- sidebar.ex shows ring-2 ring-green-400 on voice participant avatars when their user_id is in speaking_users
- members_sidebar.ex sorts voice participants to top of Online section using Enum.sort_by with MapSet membership
- app.html.heex passes speaking_users to sidebar component

## Task Commits

Each task was committed atomically:

1. **Task 1: Add speaking_users assign to user_auth.ex and handle ptt_state events** - `6c2ee98` (feat)
2. **Task 2: Speaking ring in sidebar.ex + voice-first sort in members_sidebar.ex + layout wiring** - `038658d` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `lib/cromulent_web/user_auth.ex` - Initialize speaking_users [], update presence_diff handler, add ptt_state handler
- `lib/cromulent_web/components/sidebar.ex` - Add speaking_users attr, conditional ring-2 ring-green-400 on avatar
- `lib/cromulent_web/components/members_sidebar.ex` - Voice-first sort in online members list
- `lib/cromulent_web/components/layouts/app.html.heex` - Pass speaking_users to sidebar component

## Decisions Made
- speaking_users is a plain list of string IDs rather than MapSet — LiveView assign serialization is cleaner with a list; membership check `uid in list` is fine for small voice participant counts
- Sender's own speaking ring is not shown (broadcast_from! skips sender) — acceptable behavior; self-state can be tracked client-side if needed in future
- Departed user cleanup happens in presence_diff handler — ensures ring never gets stuck when someone leaves voice

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- 15 pre-existing test failures in accounts tests (unrelated to this plan — these existed before any changes in this session)

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Speaking indicators and voice sort complete
- Ready for remaining phase 6 plans (voice mode feature flag UI, etc.)
- Pre-existing test failures should be investigated separately (not caused by this plan)

---
*Phase: 06-voice-improvement*
*Completed: 2026-03-03*
