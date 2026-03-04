---
phase: 06-voice-improvement
plan: "01"
subsystem: ui
tags: [voice, webrtc, phoenix-channels, liveview, presence, ptt]

# Dependency graph
requires:
  - phase: 06-03
    provides: voice_mode field on User schema (used by voice_bar for PTT/VAD mode display)
provides:
  - Functional Mute button in VoiceBar (red when active, disables mic tracks)
  - Functional Deafen button in VoiceBar (red when active, silences all remote audio)
  - toggle_deafen handler in VoiceChannel updates Presence meta
  - toggle_mute / toggle_deafen LiveView events in channel_live.ex
  - setMute() and setDeafen() methods on VoiceRoom JS class
  - Mute blocks PTT transmission (activate() guard)
  - Muted/deafened icons in sidebar voice participant list
affects: [voice, webrtc, presence, ptt]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - LiveView push_event flows mute/deafen state to JS via voice:set_mute and voice:set_deafen
    - JS VoiceRoom methods call channel.push to update server-side Presence meta
    - Deafen auto-mutes mic but undeafen does NOT auto-unmute (one-way mute preservation)

key-files:
  created: []
  modified:
    - lib/cromulent_web/channels/voice_channel.ex
    - lib/cromulent_web/live/channel_live.ex
    - lib/cromulent_web/components/voice_bar.ex
    - lib/cromulent_web/components/sidebar.ex
    - lib/cromulent_web/components/layouts/app.html.heex
    - assets/js/voice.js
    - assets/js/app.js

key-decisions:
  - "setDeafen calls setMute internally — Presence must show both muted and deafened accurately, so setMute's channel.push(toggle_mute) fires for every deafen toggle"
  - "Mute guard added in PTT activate() closure — muted state prevents any PTT transmission even if key/button held down"
  - "voice_muted/voice_deafened reset to false on leave_voice — prevents stale state if user rejoins without page reload"
  - "Task 1 artifacts (toggle_deafen handler, VoiceBar mute/deafen buttons, sidebar icons) were already committed in cff57af as part of plan 06-04 execution in the prior session"

patterns-established:
  - "Mute/deafen state flows: VoiceBar button -> phx-click -> handle_event -> push_event -> JS handleEvent -> VoiceRoom method -> channel.push -> Presence.update"
  - "Deafen forces mute; unmute is independent from undeafen — consistent with Discord/Slack behavior"

requirements-completed: [VOIC-MUTE, VOIC-DEAFEN]

# Metrics
duration: 3min
completed: 2026-03-03
---

# Phase 6 Plan 01: Mute/Deafen Controls Summary

**End-to-end mute and deafen controls via LiveView push_event chain: VoiceBar buttons trigger handle_events, push JS events, VoiceRoom applies audio track/element muting and updates Presence meta via channel push**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-03T18:18:03Z
- **Completed:** 2026-03-03T18:21:08Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Mute button in VoiceBar toggles red, disables outgoing mic tracks, blocks PTT, updates Presence meta
- Deafen button in VoiceBar toggles red, silences all remote audio elements, auto-mutes mic, updates Presence meta
- Sidebar voice participant list shows mic-off icon for muted users, no-audio icon for deafened users
- PTT activate() guard prevents transmission when muted

## Task Commits

Each task was committed atomically:

1. **Task 1: toggle_deafen handler + LiveView events + VoiceBar buttons + sidebar icons** - `cff57af` (feat — committed in prior session as part of plan 06-04)
2. **Task 2: JS mute/deafen implementation in voice.js and app.js** - `a6d203d` (feat)

**Plan metadata:** see final metadata commit below

## Files Created/Modified

- `lib/cromulent_web/channels/voice_channel.ex` - Added toggle_deafen handler updating Presence meta
- `lib/cromulent_web/live/channel_live.ex` - Added voice_muted/voice_deafened assigns; toggle_mute/toggle_deafen handle_events; reset on leave
- `lib/cromulent_web/components/voice_bar.ex` - Added muted/deafened/voice_mode attrs; Mute + Deafen buttons with red active state; PTT/VAD conditional display
- `lib/cromulent_web/components/sidebar.ex` - Added voice_muted/voice_deafened attrs; updated voice_bar call; added muted/deafened icons in participant list
- `lib/cromulent_web/components/layouts/app.html.heex` - Passes voice_muted/voice_deafened assigns to sidebar
- `assets/js/voice.js` - Added this.muted/this.deafened fields; mute guard in enablePTT; setMute()/setDeafen() methods; cleanup in leave()
- `assets/js/app.js` - Added voice:set_mute and voice:set_deafen handleEvent handlers in VoiceRoom hook

## Decisions Made

- `setDeafen` calls `setMute` internally so Presence reflects both states accurately — two channel pushes (toggle_mute + toggle_deafen) fire per deafen toggle, which is correct
- Mute guard added at the top of PTT `activate()` — if muted, PTT key/button is silently ignored
- `voice_muted` and `voice_deafened` are reset to `false` on `leave_voice` to prevent stale state on rejoin
- Task 1 backend/UI artifacts were found already committed in `cff57af` (plan 06-04 apparently included them); only Task 2 JS work remained

## Deviations from Plan

None — plan executed as written. Task 1 artifacts were pre-committed in a prior session; Task 2 JS changes were the only new work in this session.

## Issues Encountered

- Task 1 code changes were already present in HEAD (`cff57af`) from the previous plan 06-04 session. Detected this when `git diff` showed the working tree clean after applying edits. Proceeded directly to Task 2 JS implementation.
- Test suite has 15 pre-existing failures (key :slug not found in nil — missing DB seeding for tests). These failures exist on HEAD before our changes and are out of scope.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Mute/deafen controls fully wired end-to-end
- Presence meta correctly reflects muted/deafened state for all subscribers
- VoiceBar shows PTT button for ptt mode, Voice Activity label for vad mode
- Ready for remaining Phase 6 plans

---
*Phase: 06-voice-improvement*
*Completed: 2026-03-03*
