# Phase 6: Voice Improvement - Research

**Researched:** 2026-03-03
**Domain:** WebRTC audio controls, Web Audio API, Phoenix Presence, Ecto schema extension
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Mute/Deafen Controls**
- Mute disables the mic track entirely (no audio sent) — same pattern as PTT already uses
- Deafen stops all incoming audio AND auto-mutes the user's mic — both directions cut off
- Mute and deafen buttons go in the VoiceBar alongside the PTT button
- Mute state is visible to others — show muted/deafened icons in member sidebar for voice participants
- Mute blocks PTT: if muted, pressing PTT does nothing — must unmute first
- No keyboard shortcuts for mute/deafen — click only

**Speaking Indicators**
- Speaking indicators live in the main left sidebar (channel nav), not the members sidebar
- Show participants under the voice channel name in the sidebar at all times (not just when you're in it)
- Active speaker shown with a green ring/glow around their avatar
- Driven by existing `ptt_state` events the server already broadcasts

**Sidebar Sort (Voice Room Priority)**
- Members sidebar should sort voice room participants to the top of the Online section
- Users in the current voice channel appear first, then the rest of the server below

**Voice Activity Detection (VAD)**
- User picks their mode: "Push to Talk" or "Voice Activity" — toggle in user settings
- Mode is persisted to DB (stored on the user's settings, applies everywhere)
- Adjustable sensitivity slider on the settings page — stored with their preference
- When VAD is active, it replaces PTT; mic opens automatically when audio level exceeds threshold

**Audio Device Selection**
- Device picker lives in the user settings page (before joining voice)
- User selects mic and speaker from browser-enumerated devices
- Selection is stored and used next time they join a voice channel
- Settings page includes a "Test Mic" button that shows a live audio level visualizer

### Claude's Discretion
- VAD threshold default value and dBFS level used as starting point for slider
- Exact VoiceBar button layout and icon choices (mic icon, headphone icon)
- Audio level visualizer implementation (bar graph, ring, etc.) for the mic test
- How device preference is stored (DB column vs user preferences table)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

## Summary

Phase 6 polishes the voice experience by wiring up five features that either partially exist in the codebase or require new client-side Web Audio API work. The backend already has substantial scaffolding: `toggle_mute` is handled in `VoiceChannel`, Presence already tracks `muted`/`deafened`, `ptt_state` broadcasts already flow to all subscribers, and `voice_presences` already feeds both sidebars. The primary work is: (1) wiring mute/deafen buttons through the VoiceBar to the channel, (2) tracking active speakers in LiveView assigns so the sidebar can render the green ring, (3) implementing VAD using the Web Audio API `AnalyserNode`, (4) building device enumeration and mic-test UI in settings, and (5) adding DB-persisted user voice preferences (voice_mode, vad_threshold, mic_device_id, speaker_device_id).

The codebase follows consistent patterns: Phoenix Channel handles server-side voice events; `user_auth.ex` on_mount hook manages all shared LiveView assigns via `attach_hook`; components receive data as attrs and render reactively. All new features fit naturally into these patterns with no architectural changes required.

**Primary recommendation:** Add voice preferences as columns on the `users` table (consistent with existing schema, avoids a join, simpler changeset). Use `AudioContext` + `AnalyserNode` for both VAD and the mic-test visualizer — the same Web Audio graph serves both use cases.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | already in use | Reactive UI, server-side state | Project standard |
| Phoenix Channel | already in use | Real-time WebSocket messaging for voice | Project standard |
| Phoenix Presence | already in use | Distributed user presence with metadata | Project standard |
| Ecto | already in use | DB schema and changesets | Project standard |
| Web Audio API (browser) | native | `AudioContext`, `AnalyserNode`, `MediaStreamSource` | No library needed — built into all modern browsers |
| `navigator.mediaDevices` (browser) | native | `getUserMedia`, `enumerateDevices` | Already used in `voice.js` join() |
| Tailwind CSS | already in use | Styling | Project standard |
| Heroicons / inline SVG | already in use | Icons in VoiceBar and sidebar | Project standard |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `MediaStreamAudioSourceNode` | Web Audio API | Connect mic stream to analyser | VAD and mic test visualiser |
| `AnalyserNode` | Web Audio API | Measure RMS / dBFS of audio | VAD threshold comparison |
| `requestAnimationFrame` | browser native | Drive visualiser loop | Mic test animation |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Web Audio API AnalyserNode | `hark` npm library | hark adds 8KB and an npm dep; AnalyserNode is already in the browser and sufficient |
| Users table columns | New `user_preferences` table | Extra table, join overhead; columns on users simpler for 4 scalar prefs |
| DB-stored device IDs | localStorage | localStorage doesn't survive settings page on other devices; DB persists everywhere |

**Installation:** No new npm or hex dependencies required. All features use existing stack.

---

## Architecture Patterns

### Existing Patterns to Follow

**JS → LiveView event (client to server):**
```javascript
// Source: existing voice_state_changed in app.js / channel_live.ex
this.pushEvent("voice_state_changed", { state: "connected" })
```
Pattern for new events: `mute_toggled`, `deafen_toggled`

**LiveView → JS event (server to client):**
```javascript
// Source: existing voice:join in app.js
this.handleEvent("voice:join", ({ channel_id, ... }) => { ... })
```
Pattern for new events: `voice:mute_changed` carrying `{muted: true/false}`

**Presence update (mute state visible to all):**
```elixir
# Source: voice_channel.ex line 49-53 — existing toggle_mute handler
def handle_in("toggle_mute", %{"muted" => muted}, socket) do
  Presence.update(socket, socket.assigns.current_user.id, fn meta ->
    Map.put(meta, :muted, muted)
  end)
  {:noreply, socket}
end
```
Deafen follows the same pattern: `handle_in("toggle_deafen", ...)`.

**Presence diff → LiveView assign update:**
```elixir
# Source: user_auth.ex line 273-283 — handle_presence_info for voice:channel_id
defp handle_presence_info(
       %Phoenix.Socket.Broadcast{event: "presence_diff", topic: "voice:" <> channel_id},
       socket
     ) do
  users =
    CromulentWeb.Presence.list("voice:#{channel_id}")
    |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta end)

  voice_presences = Map.put(socket.assigns.voice_presences, channel_id, users)
  {:cont, Phoenix.Component.assign(socket, :voice_presences, voice_presences)}
end
```
When muted/deafened toggles, Presence emits a diff → this handler fires → `voice_presences` updates → sidebar re-renders showing the muted icon. No new plumbing needed.

**ptt_state broadcast (speaking indicator):**
```elixir
# Source: voice_channel.ex line 74-80
def handle_in("ptt_state", %{"active" => active}, socket) do
  broadcast_from!(socket, "ptt_state", %{
    user_id: socket.assigns.current_user.id,
    active: active
  })
  {:noreply, socket}
end
```
The `ptt_state` event is already broadcast. The speaking indicator needs the LiveView to subscribe to `ptt_state` events from the voice channel and maintain a `speaking_users` MapSet assign. The sidebar then checks `MapSet.member?(speaking_users, user_id)` to apply the green ring.

**Sidebar channel list rendering (with participants):**
```heex
<!-- Source: sidebar.ex lines 203-212 — voice presences already rendered -->
<%= if users = @voice_presences[ch.id] do %>
  <ul class="ml-7 mt-0.5 space-y-0.5">
    <li :for={user <- users} ...>
```
Speaking indicator: wrap each participant's avatar `div` with a conditional `ring-2 ring-green-400` class when `user.user_id` is in `@speaking_users`.

### Recommended Structure for New Code

```
lib/cromulent_web/
├── live/
│   └── user_settings_live.ex          # Add voice preferences section
├── components/
│   └── voice_bar.ex                   # Add mute/deafen buttons
│   └── sidebar.ex                     # Add speaking ring, muted/deafened icons
│   └── members_sidebar.ex             # Add voice-first sort
└── channels/
    └── voice_channel.ex               # Add toggle_deafen handler

lib/cromulent/
└── accounts/
    └── user.ex                        # Add voice preference fields to schema

priv/repo/migrations/
└── YYYYMMDD_add_voice_preferences_to_users.exs

assets/js/
├── voice.js                           # Add mute(), deafen(), VAD logic
├── hooks/
│   └── voice_settings.js              # New: device enum + mic test hook
└── app.js                             # Register VoiceSettings hook
```

### Pattern 1: Mute Track Enable/Disable

The PTT pattern already shows the mechanism. Mute follows identically:

```javascript
// Source: voice.js enablePTT() — existing pattern
this.localStream.getTracks().forEach(t => t.enabled = false)  // mute
this.localStream.getTracks().forEach(t => t.enabled = true)   // unmute
```

Mute state must be stored on the VoiceRoom instance so PTT respects it:
```javascript
// New logic in voice.js activate() (PTT)
const activate = () => {
  if (this.muted) return  // mute blocks PTT
  // ... rest of PTT activate
}
```

### Pattern 2: Deafen (Stop Remote Audio)

```javascript
// Deafen: disable all remote audio elements
deafen() {
  this.deafened = true
  this.muted = true  // deafen auto-mutes
  this.localStream.getTracks().forEach(t => t.enabled = false)
  document.querySelectorAll('audio[id^="audio-"]').forEach(a => a.muted = true)
  this.channel.push("toggle_deafen", { deafened: true })
  this.channel.push("toggle_mute", { muted: true })
}

undeafen() {
  this.deafened = false
  document.querySelectorAll('audio[id^="audio-"]').forEach(a => a.muted = false)
  this.channel.push("toggle_deafen", { deafened: false })
  // Note: unmuting mic is separate user action
}
```

### Pattern 3: VAD with AnalyserNode

```javascript
// In voice.js — enableVAD(threshold = -40 /* dBFS */)
enableVAD(threshold = -40) {
  const audioCtx = new AudioContext()
  const source = audioCtx.createMediaStreamSource(this.localStream)
  const analyser = audioCtx.createAnalyser()
  analyser.fftSize = 1024
  source.connect(analyser)

  const buffer = new Float32Array(analyser.fftSize)
  let speaking = false

  const tick = () => {
    if (!this.vadActive) return
    analyser.getFloatTimeDomainData(buffer)
    // RMS → dBFS
    const rms = Math.sqrt(buffer.reduce((s, v) => s + v * v, 0) / buffer.length)
    const dBFS = 20 * Math.log10(rms || 0.000001)

    if (dBFS > threshold && !speaking) {
      speaking = true
      this.localStream.getTracks().forEach(t => t.enabled = true)
      this.channel.push("ptt_state", { active: true })
    } else if (dBFS <= threshold && speaking) {
      speaking = false
      this.localStream.getTracks().forEach(t => t.enabled = false)
      this.channel.push("ptt_state", { active: false })
    }
    requestAnimationFrame(tick)
  }
  requestAnimationFrame(tick)
}
```

**Default threshold recommendation:** -40 dBFS. This is a well-established starting point for VAD — below ambient room noise (~-50 dBFS) and above normal speech (~-20 to -30 dBFS). Slider range: -60 dBFS (most sensitive) to -20 dBFS (least sensitive).

### Pattern 4: Device Enumeration

```javascript
// In VoiceSettings LiveView hook (assets/js/hooks/voice_settings.js)
async mounted() {
  // Must call getUserMedia first or device labels are empty strings (privacy restriction)
  await navigator.mediaDevices.getUserMedia({ audio: true, video: false })
  const devices = await navigator.mediaDevices.enumerateDevices()
  const audioInputs = devices.filter(d => d.kind === 'audioinput')
  const audioOutputs = devices.filter(d => d.kind === 'audiooutput')
  this.pushEvent("devices_loaded", { inputs: audioInputs.map(d => ({id: d.deviceId, label: d.label})), outputs: audioOutputs.map(d => ({id: d.deviceId, label: d.label})) })
}
```

**Critical pitfall:** Browser returns empty `label` strings for all devices until the user has granted microphone permission. Always call `getUserMedia` first before `enumerateDevices`.

### Pattern 5: Speaking Users Tracking in LiveView

The `ptt_state` event is a Phoenix Channel event (not a PubSub broadcast currently). The LiveView doesn't receive it directly. Two options:

**Option A (recommended):** Change `ptt_state` handler in `voice_channel.ex` to use `broadcast!` instead of `broadcast_from!` so it also goes to the topic, then subscribe the LiveView to `voice:channel_id` and handle the `ptt_state` message. However, the LiveView already subscribes to `voice:channel_id` (user_auth.ex line 298).

Wait — `broadcast_from!` broadcasts to all subscribers on the topic EXCEPT the sender. The LiveView process is subscribed to `voice:channel_id` PubSub topic and WOULD receive the event. Let's confirm: `Phoenix.PubSub.subscribe(Cromulent.PubSub, "voice:#{ch.id}")` in user_auth.ex line 222-224. Yes — the LiveView receives `%Phoenix.Socket.Broadcast{event: "ptt_state", ...}` messages.

Add a clause to `handle_presence_info` in user_auth.ex:
```elixir
defp handle_presence_info(
       %Phoenix.Socket.Broadcast{event: "ptt_state", payload: %{user_id: user_id, active: active}},
       socket
     ) do
  speaking_users =
    if active do
      MapSet.put(socket.assigns.speaking_users, to_string(user_id))
    else
      MapSet.delete(socket.assigns.speaking_users, to_string(user_id))
    end
  {:cont, Phoenix.Component.assign(socket, :speaking_users, speaking_users)}
end
```

Initialize `speaking_users: MapSet.new()` in the `ensure_authenticated` mount assigns.

### Pattern 6: DB Storage for User Voice Preferences

Add columns to the `users` table (matches project pattern — no new table, no join):

```elixir
# New migration
alter table(:users) do
  add :voice_mode, :string, default: "ptt", null: false
  add :vad_threshold, :integer, default: -40, null: false
  add :mic_device_id, :string
  add :speaker_device_id, :string
end
```

Add fields to `User` schema and a new `voice_preferences_changeset/2`:
```elixir
field :voice_mode, :string, default: "ptt"
field :vad_threshold, :integer, default: -40
field :mic_device_id, :string
field :speaker_device_id, :string
```

Store `voice_mode` as string `"ptt"` or `"vad"` — simple, no Ecto.Enum needed.

### Pattern 7: Members Sidebar Sorting

```elixir
# In members_sidebar.ex — sort voice participants to top of online section
voice_user_ids = MapSet.new(Map.keys(voice_channel_by_user))

online_members_sorted =
  online_members
  |> Enum.sort_by(fn member ->
    if MapSet.member?(voice_user_ids, member.id), do: 0, else: 1
  end)
```

### Anti-Patterns to Avoid

- **Using `broadcast!` instead of `broadcast_from!` for `ptt_state`**: Would echo back to the sender's LiveView, causing the sender to see themselves as "speaking" in their own sidebar (fine actually, Discord does this). Not an anti-pattern, but be intentional.
- **Calling `enumerateDevices` without prior `getUserMedia`**: Returns empty labels. Always request mic permission first.
- **Storing device IDs without considering they may change**: Device IDs change across browser sessions or when hardware changes. Store them but handle gracefully when the stored ID no longer exists in the device list (fall back to default).
- **Running the VAD analyser continuously after leaving voice**: The `AudioContext` and `requestAnimationFrame` loop must be stopped on `leave()`. Store references and call `audioCtx.close()`.
- **PTT button visible when in VAD mode**: When `voice_mode == "vad"`, the VoiceBar should hide the PTT button and show VAD mode indicator instead.
- **Assuming `toggle_deafen` exists on the server**: It doesn't yet. The `voice_channel.ex` has `toggle_mute` but NOT `toggle_deafen` — this handler must be added.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio level measurement | Custom FFT / waveform analysis | `AnalyserNode.getFloatTimeDomainData()` | Browser does the DSP |
| Device listing | Custom browser fingerprinting | `navigator.mediaDevices.enumerateDevices()` | Standard Web API |
| Presence with metadata | Custom ETS-based state | Phoenix Presence + `Presence.update/3` | Already in use, handles distributed state |
| Speaking state distribution | Custom PubSub channel | Existing `ptt_state` broadcast + existing PubSub subscription | LiveView already subscribes to voice topic |
| Green ring CSS | Custom JS animation | Tailwind `ring-2 ring-green-400` conditional class | One conditional class, no JS |

**Key insight:** The hardest parts (WebRTC, Presence, PubSub subscribe) are already built. Phase 6 is primarily wiring existing infrastructure to the UI.

---

## Common Pitfalls

### Pitfall 1: `enumerateDevices` Returns Empty Labels
**What goes wrong:** Device dropdowns show "Microphone (Generic)" or blank instead of "Blue Yeti USB".
**Why it happens:** Browser privacy — device labels are hidden until microphone permission granted.
**How to avoid:** Always call `getUserMedia({ audio: true })` first in the VoiceSettings hook `mounted()`, then call `enumerateDevices`.
**Warning signs:** Device labels appear as empty strings in the console.

### Pitfall 2: VAD AudioContext Not Closed on Leave
**What goes wrong:** Audio keeps processing after user leaves voice; memory leak; mic light stays on.
**Why it happens:** `requestAnimationFrame` callback holds a reference to the AudioContext.
**How to avoid:** In `VoiceRoom.leave()`, set `this.vadActive = false` and call `this.vadAudioCtx?.close()`.
**Warning signs:** Mic indicator stays green after leaving voice channel.

### Pitfall 3: Muted User Can Still PTT
**What goes wrong:** User who is muted presses PTT and audio goes through (or vice versa — PTT re-enables track while mute should block it).
**Why it happens:** PTT's `activate()` calls `getTracks().forEach(t => t.enabled = true)` without checking mute state.
**How to avoid:** Add `if (this.muted) return` at top of `activate()`. Store `this.muted` on VoiceRoom instance.
**Warning signs:** Muted user shows as speaking (green ring) in sidebar.

### Pitfall 4: Speaker Device Selection Requires setSinkId
**What goes wrong:** Speaker device selection has no effect — audio still plays through default device.
**Why it happens:** `HTMLAudioElement.setSinkId()` must be called on each audio element. `playRemoteAudio()` creates new elements but doesn't set the sink.
**How to avoid:** After creating `audio` in `playRemoteAudio()`, call `audio.setSinkId(this.speakerDeviceId)` if stored. Check browser support: `typeof audio.setSinkId !== 'undefined'`.
**Warning signs:** Changing speaker device has no effect on remote audio playback. Note: `setSinkId` is Chromium-only (not Firefox) as of early 2026.

### Pitfall 5: Speaking Users Not Cleared on Voice Leave
**What goes wrong:** After the last person leaves a voice channel, their avatar still shows the green speaking ring.
**Why it happens:** `speaking_users` MapSet is never cleared when presence leaves.
**How to avoid:** In the `presence_diff` handler for voice, when `voice_presences` is updated, also filter `speaking_users` to remove any user_id no longer in voice.
**Warning signs:** Ghost speaking rings on users who have left.

### Pitfall 6: Deafen Without Mute
**What goes wrong:** User hears nothing but still broadcasts audio (odd UX, contradicts the decision that deafen auto-mutes).
**Why it happens:** Only the audio element `.muted = true` is set but the mic track is not disabled.
**How to avoid:** `deafen()` must set both `this.muted = true` (mic) and mute all remote audio elements. Must also push `toggle_mute` to the channel so others see them as muted.
**Warning signs:** Presence shows `deafened: true, muted: false`.

### Pitfall 7: Device IDs Stale Across Browser Sessions
**What goes wrong:** Saved `mic_device_id` from last session is no longer valid; `getUserMedia` throws `OverconstrainedError`.
**Why it happens:** Device IDs can change when hardware is reconnected or user switches browsers.
**How to avoid:** Wrap `getUserMedia({ audio: { deviceId: { exact: savedId } } })` in try/catch and fall back to `getUserMedia({ audio: true })` on error.
**Warning signs:** Voice join fails silently with `OverconstrainedError` in console.

---

## Code Examples

### Muted/Deafened Icon in Sidebar

```heex
<%!-- In sidebar.ex voice participant list -->
<li :for={user <- users} class="flex items-center px-2 py-1 text-xs text-gray-400">
  <%!-- Avatar with speaking ring -->
  <div class={[
    "w-5 h-5 rounded-full bg-gray-600 flex items-center justify-center text-white text-[10px] font-medium mr-2 flex-shrink-0",
    MapSet.member?(@speaking_users, to_string(user.user_id)) && "ring-2 ring-green-400"
  ]}>
    {user.email |> String.first() |> String.upcase()}
  </div>
  <span class="truncate flex-1">{user.email}</span>
  <%!-- Muted icon -->
  <%= if user.muted do %>
    <svg class="w-3 h-3 text-gray-500 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
      <%!-- mic-off path -->
    </svg>
  <% end %>
  <%!-- Deafened icon -->
  <%= if user.deafened do %>
    <svg class="w-3 h-3 text-gray-500 flex-shrink-0" ...>
      <%!-- headphone-off path -->
    </svg>
  <% end %>
</li>
```

### Passing speaking_users to sidebar

```heex
<%!-- In app.html.heex -->
<.sidebar
  ...
  speaking_users={assigns[:speaking_users] || MapSet.new()}
/>
```

### VoiceBar with Mute/Deafen Buttons

```heex
<%!-- In voice_bar.ex — three action buttons -->
<div class="flex gap-2 mt-2">
  <%!-- Mute button -->
  <button
    phx-click="toggle_mute"
    class={["flex-1 py-1.5 rounded text-sm font-medium",
      if(@muted, do: "bg-red-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")
    ]}
    title={if @muted, do: "Unmute", else: "Mute"}
  >
    <%!-- mic icon or mic-off icon -->
  </button>
  <%!-- Deafen button -->
  <button
    phx-click="toggle_deafen"
    class={["flex-1 py-1.5 rounded text-sm font-medium",
      if(@deafened, do: "bg-red-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600")
    ]}
    title={if @deafened, do: "Undeafen", else: "Deafen"}
  >
    <%!-- headphone icon or headphone-off icon -->
  </button>
</div>
<%!-- PTT or VAD indicator — conditional on voice mode -->
<%= if @voice_mode == "ptt" do %>
  <button id="ptt-button" ...>Push to Talk</button>
<% else %>
  <div class="text-center text-xs text-gray-400 mt-1">Voice Activity</div>
<% end %>
```

### toggle_mute/toggle_deafen LiveView events

```elixir
# In channel_live.ex — new handle_event clauses
def handle_event("toggle_mute", _params, socket) do
  muted = !socket.assigns[:voice_muted]
  {:noreply,
   socket
   |> assign(:voice_muted, muted)
   |> push_event("voice:set_mute", %{muted: muted})}
end

def handle_event("toggle_deafen", _params, socket) do
  deafened = !socket.assigns[:voice_deafened]
  muted = deafened || socket.assigns[:voice_muted]  # deafen forces mute
  {:noreply,
   socket
   |> assign(:voice_deafened, deafened)
   |> assign(:voice_muted, muted)
   |> push_event("voice:set_deafen", %{deafened: deafened, muted: muted})}
end
```

### voice.js handling mute/deafen events from server

```javascript
// In VoiceRoom hook (app.js) — new handleEvent calls
this.handleEvent("voice:set_mute", ({ muted }) => {
  if (voiceRoom) voiceRoom.setMute(muted)
})
this.handleEvent("voice:set_deafen", ({ deafened, muted }) => {
  if (voiceRoom) voiceRoom.setDeafen(deafened, muted)
})
```

### User Voice Preferences in Settings

```elixir
# user_settings_live.ex — handle_event for saving voice prefs
def handle_event("save_voice_prefs", params, socket) do
  case Accounts.update_user_voice_prefs(socket.assigns.current_user, params) do
    {:ok, _user} -> {:noreply, put_flash(socket, :info, "Voice preferences saved.")}
    {:error, _cs} -> {:noreply, put_flash(socket, :error, "Could not save preferences.")}
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| Custom silence detection loops | Web Audio API `AnalyserNode` | Standard since 2014, all modern browsers |
| `setSinkId` not available | `setSinkId` available in Chrome/Edge | Firefox still doesn't support as of 2026 — plan for graceful degradation |
| Manual presence diffs | Phoenix Presence built-in | Already in use |

**Deprecated/outdated:**
- Using `enabled = false` on tracks for PTT is correct — do NOT use `stop()` as that requires getting a new stream. The codebase already uses `enabled` correctly.
- `enumerateDevices` without permission: deprecated behavior that filled in labels. Now requires permission grant first.

---

## Open Questions

1. **Firefox `setSinkId` support**
   - What we know: `setSinkId` is a Chrome/Edge API. Firefox does not implement it as of early 2026.
   - What's unclear: Is the Electron client always Chromium? (Yes — Electron uses Chromium, so Electron users get speaker selection. Browser users on Firefox won't.)
   - Recommendation: Implement `setSinkId` with a feature detect (`typeof audio.setSinkId !== 'undefined'`). Hide the speaker selector or show a note on unsupported browsers.

2. **VAD mode in Electron — PTT daemon interaction**
   - What we know: The Electron PTT daemon (Rust evdev or uiohook-napi) listens for keypress and calls activate/deactivate. When VAD mode is active, PTT should be disabled.
   - What's unclear: Whether the Electron PTT listener needs to be explicitly disabled, or if checking `this.muted` / `this.vadActive` in `activate()` is sufficient.
   - Recommendation: When switching to VAD mode, call `voiceRoom.disablePTT()` which removes the key/button listeners. Cleaner than checking a flag in every activate() call.

3. **speaking_users MapSet serialization in LiveView assigns**
   - What we know: LiveView diffs assigns and sends only changed values to the client. MapSet is a struct.
   - What's unclear: Whether passing `MapSet` through to a component attr causes unnecessary full re-renders.
   - Recommendation: Convert to a plain list of string IDs before passing as an attr: `MapSet.to_list(speaking_users)`. The component then does `Enum.member?(@speaking_user_ids, ...)`. Simpler serialization.

---

## Validation Architecture

> `workflow.nyquist_validation` is not set in `.planning/config.json` — skip this section.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase analysis — `voice_channel.ex`, `voice.js`, `voice_bar.ex`, `members_sidebar.ex`, `sidebar.ex`, `user_auth.ex`, `channel_live.ex`, `user_settings_live.ex`, `user.ex`, `feature_flags/flags.ex`
- MDN Web Docs (Web Audio API AnalyserNode, MediaDevices.enumerateDevices, HTMLMediaElement.setSinkId) — browser standard APIs, stable and well-documented

### Secondary (MEDIUM confidence)
- Web Audio API VAD threshold conventions — -40 dBFS is widely cited starting point in audio processing literature
- `setSinkId` browser compatibility — Chromium-only status verified via MDN compatibility table pattern (known limitation as of training knowledge, consistent with codebase being Electron/Chrome-first)

### Tertiary (LOW confidence — validate before implementing)
- Firefox `setSinkId` status in March 2026 — knowledge cutoff August 2025; verify current MDN compatibility table

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — confirmed by direct codebase reading; no new dependencies needed
- Architecture: HIGH — all patterns confirmed by reading existing working code
- Pitfalls: HIGH for browser API pitfalls (well-established); MEDIUM for VAD threshold (heuristic default)
- Speaking indicator approach: HIGH — confirmed LiveView subscribes to voice PubSub topic in user_auth.ex

**Research date:** 2026-03-03
**Valid until:** 2026-04-03 (stable APIs; reassess if Firefox ships setSinkId)
