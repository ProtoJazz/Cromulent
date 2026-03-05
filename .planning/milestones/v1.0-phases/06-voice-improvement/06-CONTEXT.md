# Phase 6: Voice Improvement - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Polish the voice experience with mute/deafen controls, speaking indicators in the sidebar, voice activity detection (VAD) as an alternative to PTT, and audio device selection with a mic test. All building on the WebRTC infrastructure from Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Mute/Deafen Controls
- Mute disables the mic track entirely (no audio sent) — same pattern as PTT already uses
- Deafen stops all incoming audio AND auto-mutes the user's mic — both directions cut off
- Mute and deafen buttons go in the VoiceBar alongside the PTT button
- Mute state is visible to others — show muted/deafened icons in member sidebar for voice participants
- Mute blocks PTT: if muted, pressing PTT does nothing — must unmute first
- No keyboard shortcuts for mute/deafen — click only

### Speaking Indicators
- Speaking indicators live in the main left sidebar (channel nav), not the members sidebar
- Show participants under the voice channel name in the sidebar at all times (not just when you're in it)
- Active speaker shown with a green ring/glow around their avatar
- Driven by existing `ptt_state` events the server already broadcasts

### Sidebar Sort (Voice Room Priority)
- Members sidebar should sort voice room participants to the top of the Online section
- Users in the current voice channel appear first, then the rest of the server below

### Voice Activity Detection (VAD)
- User picks their mode: "Push to Talk" or "Voice Activity" — toggle in user settings
- Mode is persisted to DB (stored on the user's settings, applies everywhere)
- Adjustable sensitivity slider on the settings page — stored with their preference
- When VAD is active, it replaces PTT; mic opens automatically when audio level exceeds threshold

### Audio Device Selection
- Device picker lives in the user settings page (before joining voice)
- User selects mic and speaker from browser-enumerated devices
- Selection is stored and used next time they join a voice channel
- Settings page includes a "Test Mic" button that shows a live audio level visualizer

### Claude's Discretion
- VAD threshold default value and dBFS level used as starting point for slider
- Exact VoiceBar button layout and icon choices (mic icon, headphone icon)
- Audio level visualizer implementation (bar graph, ring, etc.) for the mic test
- How device preference is stored (DB column vs user preferences table)

</decisions>

<specifics>
## Specific Ideas

- Green ring/glow on speaking avatar should feel like Discord's speaker indicator — recognizable pattern
- Mic test visualizer is on the settings page, not a modal — inline with the device picker

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VoiceChannel` (Elixir): already handles `toggle_mute`, tracks `muted`/`deafened` in Presence meta — only needs UI wired up
- `VoiceBar` component (`voice_bar.ex`): existing PTT button and disconnect button — add mute/deafen buttons here
- `voice.js` VoiceRoom class: `enablePTT()`, `localStream.getTracks()`, `playRemoteAudio()` — all reusable for mute/VAD logic
- Members sidebar (`members_sidebar.ex`): already receives `voice_presences` map — add sorting logic here
- `user_settings_live.ex`: existing settings page — add voice preferences section here

### Established Patterns
- Presence meta already tracks `muted: false, deafened: false` — update these on toggle
- PTT disables mic tracks via `localStream.getTracks().forEach(t => t.enabled = false)` — mute follows same pattern
- `ptt_state` broadcast (`voice_channel.ex` line 68) — reuse for VAD state signaling
- `voice_state_changed` LiveView event already handles connection state from JS — pattern for other JS→LiveView events
- Tailwind + Heroicons used throughout for icons

### Integration Points
- VoiceBar → `channel_live.ex`: new mute/deafen events need `handle_event` handlers on the LiveView
- `voice.js`: VAD needs `AudioContext` + `AnalyserNode` to measure mic levels
- Settings page: needs new DB columns (or preferences map) for `voice_mode`, `vad_threshold`, `mic_device_id`, `speaker_device_id`
- Sidebar (`sidebar.ex`): needs Presence data for voice participants to show under channel name
- `members_sidebar.ex`: needs sorting logic — voice room members first, then server

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-voice-improvement*
*Context gathered: 2026-03-01*
