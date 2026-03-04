---
phase: 06-voice-improvement
plan: "03"
subsystem: database
tags: [ecto, postgresql, user-schema, voice-preferences, changeset]

# Dependency graph
requires: []
provides:
  - voice_mode, vad_threshold, mic_device_id, speaker_device_id columns on users table
  - User.voice_preferences_changeset/2 with validated fields
  - Accounts.update_user_voice_prefs/2 for persisting preferences
  - Accounts.get_voice_prefs/1 convenience function
affects:
  - 06-01-voice-mode-voicebar (needs voice_mode field)
  - 06-04-vad-device-settings (needs all four fields and update function)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive Ecto migration with alter table for non-breaking schema changes"
    - "Changeset with validate_inclusion and validate_number for enum-like string + integer validation"

key-files:
  created:
    - priv/repo/migrations/20260303120000_add_voice_preferences_to_users.exs
  modified:
    - lib/cromulent/accounts/user.ex
    - lib/cromulent/accounts.ex

key-decisions:
  - "voice_mode stored as :string not Ecto.Enum — allows client-side extensibility without migration"
  - "vad_threshold validated in range -60 to -20 dB — prevents nonsensical VAD sensitivity values"
  - "get_voice_prefs/1 reads from loaded struct — no extra DB query for settings page render"

patterns-established:
  - "Voice preference changeset: cast then validate_inclusion(voice_mode) + validate_number(vad_threshold)"
  - "Accounts context: update_user_voice_prefs/2 follows same pattern as set_user_role/2 — changeset then Repo.update()"

requirements-completed: [VOIC-VAD, VOIC-DEVICES]

# Metrics
duration: 2min
completed: 2026-03-03
---

# Phase 6 Plan 03: Voice DB Foundation Summary

**PostgreSQL migration and Ecto schema adding four voice preference columns (voice_mode, vad_threshold, mic_device_id, speaker_device_id) with Accounts.update_user_voice_prefs/2 context function**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-03T18:03:44Z
- **Completed:** 2026-03-03T18:05:06Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Migration adds voice_mode (default "ptt"), vad_threshold (default -40), mic_device_id (nil), speaker_device_id (nil) to users table
- User schema extended with four fields matching migration defaults
- voice_preferences_changeset/2 validates voice_mode inclusion in ["ptt", "vad"] and vad_threshold in range -60 to -20
- Accounts.update_user_voice_prefs/2 and Accounts.get_voice_prefs/1 compile cleanly and are ready for Plans 01 and 04

## Task Commits

Each task was committed atomically:

1. **Task 1: DB migration for voice preference columns** - `5a02618` (feat)
2. **Task 2: User schema voice fields and Accounts context function** - `00b6298` (feat)

**Plan metadata:** (docs commit — see final)

## Files Created/Modified
- `priv/repo/migrations/20260303120000_add_voice_preferences_to_users.exs` - Ecto migration altering users table with four voice preference columns
- `lib/cromulent/accounts/user.ex` - Four new schema fields and voice_preferences_changeset/2 function
- `lib/cromulent/accounts.ex` - update_user_voice_prefs/2 and get_voice_prefs/1 context functions

## Decisions Made
- voice_mode stored as :string not Ecto.Enum — allows client-side extensibility without a future migration if a third mode is needed
- vad_threshold validated in range -60 to -20 dB — covers the practical VAD sensitivity range without allowing nonsensical values
- get_voice_prefs/1 reads from already-loaded user struct — no extra DB round-trip for the settings page render

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. The 15 pre-existing test failures are unrelated to these changes (confirmed by reverting and re-running tests).

## User Setup Required
None - no external service configuration required. Migration runs automatically via `mix ecto.migrate`.

## Next Phase Readiness
- Plan 06-01 (voice_mode for VoiceBar) can now reference user.voice_mode from the loaded user struct
- Plan 06-04 (VAD + device settings) can reference Accounts.update_user_voice_prefs/2 and Accounts.get_voice_prefs/1
- No blockers

---
*Phase: 06-voice-improvement*
*Completed: 2026-03-03*
