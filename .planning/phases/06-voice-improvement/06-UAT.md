---
status: fixed
phase: 06-voice-improvement
source: [06-01-SUMMARY.md, 06-02-SUMMARY.md, 06-03-SUMMARY.md, 06-04-SUMMARY.md, 06-05-SUMMARY.md]
started: 2026-03-03T18:30:00.000Z
updated: 2026-03-04T00:00:00.000Z
---

## Tests

### 1. Mute Button Toggles Red and Silences Mic
expected: While in a voice channel, click the Mute button in the VoiceBar. Button turns red. Mic is disabled (others can't hear you). Click again to unmute; button returns to normal.
result: pass

### 2. Deafen Button Toggles Red and Silences Remote Audio
expected: While in a voice channel, click the Deafen button in the VoiceBar. Button turns red, and all remote participants are silenced (you can't hear them). Also auto-mutes your mic (Mute button also turns red). Clicking Deafen again re-enables remote audio, but your mic stays muted.
result: pass

### 3. Muted/Deafened Icons in Sidebar Participant List
expected: When another participant mutes themselves, a mic-off icon appears next to their name in the voice participant list in the left sidebar. When they deafen, a no-audio icon appears. Icons disappear when they unmute/undeafen.
result: pass

### 4. PTT Blocked When Muted
expected: While muted (Mute button red), press and hold the Push-to-Talk key. No audio should be transmitted — the PTT action is silently ignored as long as mute is active.
result: pass

### 5. Speaking Ring on Active Participants
expected: When a participant in your voice channel speaks (via PTT or VAD), a green ring appears around their avatar in the left sidebar. The ring disappears when they stop speaking.
result: pass

### 6. Voice Participants Sorted First in Members Sidebar
expected: Open the Members sidebar (right side). Users currently in a voice channel appear at the top of the Online section, above non-voice online users.
result: dropped
issue: Feature was wrong — members sidebar shows server-online members by presence; voice state is irrelevant to it. Reverted sort and "In voice" badge from members_sidebar.ex. VOIC-SORT requirement dropped.

### 7. Voice Settings Section in User Settings
expected: Go to Settings (gear icon or user menu). A "Voice Settings" section is visible with a PTT / VAD mode radio toggle, a microphone device dropdown, and a speaker device dropdown.
result: fixed
issue: Sensitivity slider appeared uninteractable — appearance-none CSS removed browser thumb rendering. Fixed with accent-indigo-600. Page still needs visual polish (separate concern).

### 8. VAD Sensitivity Slider and Mic Test Visualizer
expected: In Voice Settings, switch mode to VAD. A VAD sensitivity slider (range -60 to -20 dBFS) appears. Clicking the "Test Mic" button shows a live audio level bar that responds to your voice.
result: pass (after slider fix)

### 9. VAD Mode Auto-Opens Mic in Voice Channel
expected: In Voice Settings, select VAD mode and save. Join a voice channel. Speak above the threshold — your mic should activate automatically without pressing PTT.
result: fixed
issue: AudioContext created in async Phoenix Channel callback starts in suspended state. getFloatTimeDomainData returned zeros, VAD never triggered. Fixed with vadAudioCtx.resume() before starting rAF loop.

## Summary

total: 9
passed: 6
fixed: 2
dropped: 1
issues: 0

## Gaps

- Voice settings page needs visual polish (layout, spacing, section hierarchy)
