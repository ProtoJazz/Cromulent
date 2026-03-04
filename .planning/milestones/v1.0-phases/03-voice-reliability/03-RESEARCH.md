# Phase 3: Voice Reliability - Research

**Researched:** 2026-03-01
**Domain:** WebRTC TURN/STUN, Phoenix Presence duplicate-join guard, connection state UI
**Confidence:** HIGH (core patterns verified against official docs and official Coturn/RFC sources)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**TURN credential delivery**
- Credentials injected at join time via the existing `push_event("voice:join", ...)` payload — adds `ice_servers` key to what already passes `channel_id`, `user_token`, `user_id` to JS
- No extra HTTP round-trip; flows naturally with the existing join event
- 1-hour TTL for credentials
- TURN_SECRET stored as environment variable in `config/runtime.exs` (consistent with SECRET_KEY_BASE, DATABASE_URL)
- HMAC time-limited credential scheme: username = `"timestamp:user_id"`, password = `HMAC-SHA1(secret, username)` — RFC 8489 / Coturn standard

**TURN provider abstraction**
- Abstraction layer with pluggable providers selected via `TURN_PROVIDER` env var
- `TURN_PROVIDER=coturn` — HMAC auth using `TURN_URL` + `TURN_SECRET`
- `TURN_PROVIDER=metered` — REST API auth using `TURN_API_KEY` to call Metered.ca
- No `TURN_PROVIDER` set = STUN-only mode (current behavior, graceful default)
- Coturn and Metered.ca are the two concrete providers in this phase; abstraction makes adding more straightforward

**Double-join prevention**
- Guard lives in `VoiceChannel.join/3` — check Phoenix Presence for the user_id, reject with `{:error, %{reason: "already_in_channel"}}` if already tracked
- Rejected silently: client `receive("error")` already logs, no user-visible error popup
- Reconnect grace period: rely on Phoenix Presence timeout to clear the old entry; new join attempt succeeds once it clears — no special retry logic needed
- Cross-channel: LiveView `handle_event("join_voice")` checks if `voice_channel` is already assigned; if so, pushes `voice:leave` before `voice:join` to auto-leave the current channel first

**Connection state UI**
- Color-coded dot + text label in `VoiceBar`:
  - Yellow dot + "Connecting..." — between channel join and WebRTC channel success
  - Green dot + channel name — connected (channel join succeeded; peers connect as they arrive)
  - Red dot + "Disconnected" — channel join failed or peer connection dropped
- Three states only: connecting / connected / disconnected
- "Connected" triggers immediately on successful Phoenix Channel join (not waiting for a peer)
- No reconnect button — disconnected state shows the existing leave/disconnect button; user rejoins manually by clicking the channel again

**TURN deployment**
- Coturn added to `docker-compose.yml` for local development
- Separate `Dockerfile.coturn` for production deployment (Coolify-compatible), references existing `Dockerfile` conventions
- Self-hosted Coturn is the default recommended path; Metered.ca is the managed alternative

### Claude's Discretion
- Exact Elixir module structure for the provider abstraction (behaviour + implementations)
- Coturn container config details in docker-compose (image, ports, config file approach)
- How `voice.js` receives and applies the `ice_servers` payload from the join event
- Error handling when TURN credential generation fails

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VOIC-01 | User cannot join the same voice channel multiple times | Phoenix Presence `list/1` check before `track/3` in `VoiceChannel.join/3`; LiveView cross-channel auto-leave guard |
| VOIC-02 | Server includes a bundled TURN server (coturn) for NAT traversal | Coturn docker image (`coturn/coturn`), `use-auth-secret` config, HMAC-SHA1 credential generation with Erlang `:crypto`, Elixir behaviour pattern for provider abstraction |
</phase_requirements>

---

## Summary

This phase addresses two independent but sequenced voice reliability problems. The first is preventing duplicate channel presence caused by rapid reconnects or browser tab interactions — solved purely in Elixir on the server using Phoenix Presence's existing `list/1` API to gate the `join/3` callback. The second is NAT traversal via a TURN relay server — solved by adding credential generation in Elixir (HMAC-SHA1, no new deps) and shipping Coturn in docker-compose for local dev.

The codebase is already well-prepared for both changes. `VoiceChannel.join/3` is minimal and easy to add a Presence guard. The `push_event("voice:join", ...)` payload in `channel_live.ex` already passes structured data to the JS hook — adding `ice_servers` is a one-field extension. The `VoiceRoom` hook in `app.js` destructures that payload, so receiving and using `ice_servers` requires minimal wiring. `VoiceBar` is a simple Phoenix component with a hardcoded green dot — the state display upgrade is a straightforward prop + conditional render.

**Primary recommendation:** Use the Elixir behaviour pattern for the TURN provider abstraction (one `@behaviour` module, two `@behaviour` implementations: `Coturn` and `Metered`), selected at runtime by reading `TURN_PROVIDER` from the environment. This is idiomatic Elixir, requires zero new dependencies (`:crypto` is built-in, Finch is already started), and is safe to extend later.

---

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---------------|---------|---------|--------------|
| Phoenix Presence (built-in) | Phoenix 1.7.x | Tracking active voice channel members, duplicate-join guard | Already in use in `VoiceChannel`; provides per-topic presence lists by key |
| Erlang `:crypto` (OTP built-in) | OTP 26+ | HMAC-SHA1 credential generation | Built into OTP, zero deps; `:crypto.mac(:hmac, :sha, key, data)` |
| `Base` (Elixir stdlib) | Elixir 1.14+ | Base64-encode HMAC output for TURN password | Standard library, no install |
| Coturn Docker image | `coturn/coturn:4.6` | Local TURN server for dev | Official image; `use-auth-secret` mode matches the HMAC credential scheme |
| Finch (already started) | `~> 0.13` | HTTP client for Metered.ca REST API | Already in `Cromulent.Finch` supervisor child; no new dep |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|---------------|---------|---------|-------------|
| Metered.ca REST API | v2 | Managed TURN credential fetching | When `TURN_PROVIDER=metered`; replaces self-hosting burden |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Erlang `:crypto` HMAC | `ex_stun` library | `ex_stun` is a full STUN implementation; overkill for credential generation only — `:crypto` is built-in and sufficient |
| Finch for Metered HTTP | HTTPoison | Finch is already in the supervisor; no reason to add a second HTTP client |
| Elixir behaviour | Application env + case | Behaviour provides compile-time callback enforcement; cleaner for two implementations that will diverge |

**Installation:** No new dependencies needed. `:crypto` is OTP built-in. `Finch` is already in `mix.exs`. Coturn is infrastructure only.

---

## Architecture Patterns

### Recommended Project Structure

New files this phase creates:

```
lib/cromulent/
├── turn/
│   ├── provider.ex          # @behaviour definition — get_ice_servers/1
│   ├── coturn.ex            # @behaviour Cromulent.Turn.Provider — HMAC impl
│   └── metered.ex           # @behaviour Cromulent.Turn.Provider — REST API impl
priv/coturn/
└── turnserver.conf          # Coturn config file, mounted into container
docker-compose.yml           # +coturn service
Dockerfile.coturn            # Standalone Coturn image for Coolify
config/runtime.exs           # +TURN_PROVIDER, TURN_SECRET, TURN_URL, TURN_API_KEY reads
```

Modified files:

```
lib/cromulent_web/channels/voice_channel.ex   # +Presence guard in join/3
lib/cromulent_web/live/channel_live.ex         # +cross-channel auto-leave in handle_event("join_voice")
                                               # +TURN credential fetch + ice_servers in push_event
lib/cromulent_web/components/voice_bar.ex      # +connection_state prop, dynamic dot + label
assets/js/app.js                               # +ice_servers consumed in voice:join handler
assets/js/voice.js                             # +VoiceRoom accepts iceServers param; no hardcoded constant
```

### Pattern 1: TURN Provider Behaviour

**What:** A `@behaviour` module declares a single callback. Two implementation modules (`Coturn`, `Metered`) each `@behaviour` it. The caller reads `TURN_PROVIDER` env at runtime to select which module to dispatch to.

**When to use:** Any time you have two concrete implementations of the same interface that are selected at deploy time.

```elixir
# Source: https://www.djm.org.uk/posts/writing-extensible-elixir-with-behaviours-adapters-pluggable-backends/
# lib/cromulent/turn/provider.ex
defmodule Cromulent.Turn.Provider do
  @callback get_ice_servers(user_id :: integer()) ::
    {:ok, list(map())} | {:error, term()}
end

# lib/cromulent/turn/coturn.ex
defmodule Cromulent.Turn.Coturn do
  @behaviour Cromulent.Turn.Provider

  @impl true
  def get_ice_servers(user_id) do
    ttl = System.system_time(:second) + 3600
    username = "#{ttl}:#{user_id}"
    secret = System.get_env("TURN_SECRET")
    password = :crypto.mac(:hmac, :sha, secret, username) |> Base.encode64()
    turn_url = System.get_env("TURN_URL")
    {:ok, [
      %{urls: "stun:stun.l.google.com:19302"},
      %{urls: turn_url, username: username, credential: password}
    ]}
  end
end

# lib/cromulent/turn/metered.ex
defmodule Cromulent.Turn.Metered do
  @behaviour Cromulent.Turn.Provider

  @impl true
  def get_ice_servers(_user_id) do
    api_key = System.get_env("TURN_API_KEY")
    url = "https://cromulent.metered.live/api/v2/turn/credentials?secretKey=#{api_key}"
    # ... Finch.request + JSON parse → transform to iceServers array
    # Returns {:ok, [%{urls: ..., username: ..., credential: ...}, ...]}
  end
end
```

### Pattern 2: Provider Dispatch

**What:** Read `TURN_PROVIDER` env once per `join_voice` event; dispatch to the correct module or fall back to STUN-only.

```elixir
# In channel_live.ex handle_event("join_voice", ...)
defp get_ice_servers(user_id) do
  case System.get_env("TURN_PROVIDER") do
    "coturn"  -> Cromulent.Turn.Coturn.get_ice_servers(user_id)
    "metered" -> Cromulent.Turn.Metered.get_ice_servers(user_id)
    _         -> {:ok, [%{urls: "stun:stun.l.google.com:19302"}]}
  end
end
```

### Pattern 3: Phoenix Presence Duplicate-Join Guard

**What:** Call `Presence.list(socket)` before `Presence.track/3`. If the user_id key already exists in the returned map, reject with an error tuple. Phoenix Presence `list/1` returns a map keyed by the tracked key string.

```elixir
# Source: https://hexdocs.pm/phoenix/Phoenix.Presence.html
# In VoiceChannel.join/3
presences = CromulentWeb.Presence.list("voice:#{channel_id}")

case Map.has_key?(presences, to_string(socket.assigns.current_user.id)) do
  true  -> {:error, %{reason: "already_in_channel"}}
  false ->
    send(self(), :after_join)
    {:ok, assign(socket, :channel_id, channel_id)}
end
```

**Key detail:** `Presence.list/1` accepts a topic string OR a socket. Using the topic string `"voice:#{channel_id}"` checks the global presence for that topic, not just the current socket's tracking. This is the correct scope for a duplicate-join guard.

### Pattern 4: Connection State via LiveView assigns + VoiceBar prop

**What:** VoiceBar receives a `connection_state` atom (`:connecting`, `:connected`, `:disconnected`). State transitions are driven by the JS hook pushing events back to the LiveView, or by the server detecting a channel join failure.

The JS hook uses `this.pushEvent("voice_state_changed", %{state: "connected"})` after `receive("ok")`, and similarly for errors. The LiveView updates its assign; VoiceBar re-renders.

**Alternative considered:** Track state purely client-side in JS without notifying LiveView. Rejected because VoiceBar is a server-rendered component — it needs the assign to render the correct dot color. The push_event round-trip (JS → server → LiveView → re-render) is the correct LiveView pattern.

```elixir
# VoiceBar with state
attr :voice_channel, :any, required: true
attr :connection_state, :atom, default: :connecting  # :connecting | :connected | :disconnected

# Dot color logic:
# :connecting  → yellow  (bg-yellow-500)
# :connected   → green   (bg-green-500)
# :disconnected → red    (bg-red-500)
```

### Anti-Patterns to Avoid

- **Checking `VoiceState` Agent instead of Presence for duplicate-join:** `VoiceState` is an in-memory Agent that is a secondary bookkeeping tool. It does NOT represent live socket connections — a stale entry persists if the user crashes without calling `leave`. Presence is socket-lifecycle-aware and self-cleans. Use Presence as the authoritative guard.
- **Generating TURN credentials in the JS client:** The TURN_SECRET must never reach the browser. Credential generation belongs on the server, delivered via the already-trusted `push_event` payload.
- **Hardcoding `ICE_SERVERS` after this phase:** The existing `const ICE_SERVERS = {...}` at the top of `voice.js` must be removed. `VoiceRoom` should accept `iceServers` as a constructor parameter so the dynamic value from the join event payload is used.
- **Using `:crypto.hmac/3` (deprecated):** In OTP 24+, `:crypto.hmac/3` is deprecated in favor of `:crypto.mac(:hmac, :sha, key, data)`. Use the new form to avoid deprecation warnings.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HMAC-SHA1 for TURN credentials | Custom bit manipulation | `:crypto.mac(:hmac, :sha, key, data)` | OTP built-in, tested, correct |
| TURN server | Custom relay | Coturn (mature, RFC-compliant) | TURN has complex edge cases (symmetric NAT, relay address selection, rate limits) |
| HTTP client for Metered | Raw `:httpc` or manual socket | Finch (already in supervisor) | Connection pooling, TLS, error handling already handled |
| Presence-based duplicate detection | ETS table or Agent | `CromulentWeb.Presence.list/1` | Presence is socket-lifecycle-aware; ETS/Agent would leak stale entries |

**Key insight:** TURN relay and HMAC credential schemes are both specified by RFCs with many edge cases. Coturn implements all of them. The only application code needed is generating the HMAC-signed username/password pair — a 5-line function using OTP primitives.

---

## Common Pitfalls

### Pitfall 1: Presence Race Condition on Rapid Reconnect

**What goes wrong:** User rapidly disconnects and reconnects (e.g., browser refresh). The Presence entry from the first socket hasn't timed out yet. The guard rejects the new join with "already_in_channel". User appears stuck.

**Why it happens:** Phoenix Presence uses a distributed gossip protocol with a `presence_timeout` (default: 30 seconds in dev). The old socket's tracking persists for up to that duration after disconnect.

**How to avoid:** The decision is to rely on Presence timeout — users retry after it clears. Document this in code comments. Do NOT add instant-clear logic in `terminate/2` for the existing socket (it already fires `broadcast_from!("peer_left")` — adding Presence untrack there creates a different race).

**Warning signs:** If users frequently report "already_in_channel" errors in the browser console after refreshing, the Presence timeout may need tuning (configurable in `config/dev.exs` or `config/config.exs` for Presence).

### Pitfall 2: TURN Credential Expiry vs. Connection Duration

**What goes wrong:** A 1-hour TTL credential is generated at join time. If a user stays in a voice channel longer than 1 hour, the TURN relay may reject further ICE candidates using the expired credential, causing peer connections to fail without a clear error.

**Why it happens:** TURN servers validate credential TTL on each allocation request, not just the first.

**How to avoid:** For this phase, the 1-hour TTL is intentional and acceptable (per CONTEXT.md decisions). Document the limitation. WebRTC connections typically survive without needing new ICE allocations after initial connection. A future phase could implement credential refresh.

**Warning signs:** Voice drops after exactly 1 hour for users on restrictive NATs.

### Pitfall 3: ICE Servers Payload Shape Mismatch

**What goes wrong:** The `ice_servers` key passed through `push_event` is a list of Elixir maps. Jason serializes these to JSON. JS receives them as plain objects. `RTCPeerConnection` requires the `iceServers` array to use `urls` (string or array of strings), `username` (string), and `credential` (string) — all lowercase. A naming mismatch (e.g., `url` vs `urls`) silently fails: the browser ignores unrecognized keys, STUN/TURN server is not used, but no error is thrown.

**Why it happens:** Different TURN providers use different field names. Metered returns `urls` arrays; the RTCPeerConnection spec uses `urls`.

**How to avoid:** In each provider implementation, normalize the output to the RTCPeerConnection `iceServers` format: `%{urls: "...", username: "...", credential: "..."}`. Test against `chrome://webrtc-internals` to verify TURN candidates appear.

**Warning signs:** WebRTC connects peer-to-peer even when testing behind a symmetric NAT simulator; TURN relay stats show 0 bytes in `chrome://webrtc-internals`.

### Pitfall 4: `:crypto.mac/4` vs. `:crypto.hmac/3`

**What goes wrong:** Elixir tutorials and Stack Overflow answers use `:crypto.hmac(:sha, key, data)` which was deprecated in OTP 24 and removed in OTP 26. The project uses OTP 26.1.2 — calling the old form will raise `UndefinedFunctionError`.

**Why it happens:** Most web resources were written before OTP 24.

**How to avoid:** Use `:crypto.mac(:hmac, :sha, key, data)` — the new form.

```elixir
# WRONG (OTP 26 raises UndefinedFunctionError)
:crypto.hmac(:sha, secret, username)

# CORRECT
:crypto.mac(:hmac, :sha, secret, username)
```

### Pitfall 5: Cross-Channel Auto-Leave Timing

**What goes wrong:** LiveView `handle_event("join_voice")` pushes `voice:leave` then immediately `voice:join`. The JS hook processes events in order, but if `voice:leave` tears down the socket before `voice:join` completes initialization, there may be a brief window where neither connection is active.

**Why it happens:** LiveView `push_event` calls are batched and sent together in the same socket message. The JS hook fires them sequentially. The existing JS `voice:leave` handler calls `voiceRoom.leave()` and `voiceSocket.disconnect()` synchronously — this is safe before the new `voice:join` initializes fresh instances.

**How to avoid:** The existing pattern in `app.js` already handles this correctly: `voice:join` checks `if (voiceRoom) { voiceRoom.leave() }` at the top before creating the new room. The server-side auto-leave just needs to push `voice:leave` first, then the new `voice:join`. Both arrive in the same batch; the JS processes them in order.

---

## Code Examples

Verified patterns from research and existing codebase:

### HMAC-SHA1 TURN Credential Generation (Coturn)

```elixir
# Source: Erlang OTP docs (https://www.erlang.org/doc/apps/crypto/crypto.html)
# + Coturn documentation (https://github.com/coturn/coturn/wiki/turnserver)
# Standard Coturn REST API / RFC 5389 time-limited credential scheme

def generate_coturn_credential(user_id) do
  ttl = System.system_time(:second) + 3600
  username = "#{ttl}:#{user_id}"
  secret = System.get_env("TURN_SECRET") || raise "TURN_SECRET not set"
  password = :crypto.mac(:hmac, :sha, secret, username) |> Base.encode64()
  turn_url = System.get_env("TURN_URL") || raise "TURN_URL not set"

  {:ok, [
    %{urls: "stun:stun.l.google.com:19302"},
    %{urls: turn_url, username: username, credential: password}
  ]}
end
```

### Phoenix Presence Duplicate-Join Guard

```elixir
# Source: https://hexdocs.pm/phoenix/Phoenix.Presence.html
# VoiceChannel.join/3 — check presence BEFORE allowing join

def join("voice:" <> channel_id, _params, socket) do
  channel = channel_id |> parse_id() |> Cromulent.Channels.get_channel()

  if channel && channel.type == :voice do
    presences = CromulentWeb.Presence.list("voice:#{channel_id}")
    user_key = to_string(socket.assigns.current_user.id)

    if Map.has_key?(presences, user_key) do
      {:error, %{reason: "already_in_channel"}}
    else
      send(self(), :after_join)
      {:ok, assign(socket, :channel_id, channel_id)}
    end
  else
    {:error, %{reason: "not found"}}
  end
end
```

### Injecting ice_servers into push_event

```elixir
# In channel_live.ex handle_event("join_voice", ...)
def handle_event("join_voice", %{"channel-id" => channel_id}, socket) do
  # Auto-leave current channel if already in one
  socket =
    if socket.assigns[:voice_channel] do
      socket |> push_event("voice:leave", %{})
    else
      socket
    end

  channel = Cromulent.Channels.get_channel(channel_id)
  Cromulent.VoiceState.join(socket.assigns.current_user.id, channel)

  ice_servers =
    case get_ice_servers(socket.assigns.current_user.id) do
      {:ok, servers} -> servers
      {:error, _} -> [%{urls: "stun:stun.l.google.com:19302"}]  # Graceful fallback
    end

  {:noreply,
   socket
   |> assign(:voice_channel, channel)
   |> assign(:voice_connection_state, :connecting)
   |> push_event("voice:join", %{
     channel_id: channel_id,
     user_token: socket.assigns.user_token,
     user_id: socket.assigns.user_id,
     ice_servers: ice_servers
   })}
end
```

### JS Hook: Consuming ice_servers and Reporting Connection State

```javascript
// In app.js VoiceRoom hook — voice:join handler
this.handleEvent("voice:join", ({ channel_id, user_token, user_id, ice_servers }) => {
  if (voiceRoom) {
    voiceRoom.leave()
    voiceRoom = null
  }
  if (voiceSocket) {
    voiceSocket.disconnect()
    voiceSocket = null
  }

  voiceSocket = new Socket("/socket", { params: { token: user_token } })
  voiceSocket.connect()

  voiceRoom = new VoiceRoom(channel_id, user_id, voiceSocket, ice_servers)
  voiceRoom.join()
    .then(() => {
      // Channel join success = "connected"
      this.pushEvent("voice_state_changed", { state: "connected" })
    })
    .catch(() => {
      this.pushEvent("voice_state_changed", { state: "disconnected" })
    })
})

// In voice.js VoiceRoom constructor — ice_servers as parameter
class VoiceRoom {
  constructor(channelId, userId, socket, iceServers) {
    this.iceServers = iceServers || [{ urls: "stun:stun.l.google.com:19302" }]
    // ...
  }
  createPeer(remoteUserId, isOfferer) {
    const peer = new RTCPeerConnection({ iceServers: this.iceServers })
    // ...
  }
}
```

### VoiceBar with Dynamic Connection State

```elixir
# lib/cromulent_web/components/voice_bar.ex
attr :voice_channel, :any, required: true
attr :connection_state, :atom, default: :connecting

def voice_bar(assigns) do
  ~H"""
  <div class="px-3 py-3 border-t border-gray-700 bg-gray-900">
    <div class="flex items-center justify-between mb-2">
      <div class="flex items-center gap-2 min-w-0">
        <div class={[
          "w-2 h-2 rounded-full flex-shrink-0",
          @connection_state == :connecting && "bg-yellow-500",
          @connection_state == :connected && "bg-green-500",
          @connection_state == :disconnected && "bg-red-500"
        ]}></div>
        <span class={[
          "text-sm font-medium truncate",
          @connection_state == :connecting && "text-yellow-500",
          @connection_state == :connected && "text-green-500",
          @connection_state == :disconnected && "text-red-500"
        ]}>
          <%= case @connection_state do %>
            <% :connecting -> %> Connecting...
            <% :connected -> %> {@voice_channel.name}
            <% :disconnected -> %> Disconnected
          <% end %>
        </span>
      </div>
      <%!-- existing leave button --%>
    </div>
  </div>
  """
end
```

### Coturn docker-compose Service

```yaml
# Source: https://hub.docker.com/r/coturn/coturn
# + https://github.com/coturn/coturn/blob/master/docker/docker-compose-all.yml
coturn:
  image: coturn/coturn:4.6
  restart: unless-stopped
  ports:
    - "3478:3478/tcp"
    - "3478:3478/udp"
    - "49152-49200:49152-49200/udp"  # Relay port range (keep small for local dev)
  volumes:
    - ./priv/coturn/turnserver.conf:/etc/coturn/turnserver.conf:ro
  network_mode: host  # Simplest for local dev — avoids Docker NAT issues with TURN
```

### Coturn turnserver.conf (local dev)

```
# priv/coturn/turnserver.conf
listening-port=3478
realm=cromulent.local
use-auth-secret
static-auth-secret=${TURN_SECRET}
log-file=stdout
no-tls
no-dtls
```

**Note on relay port range:** 49152-49200 is a 48-port range, sufficient for local dev (one pair per simultaneous peer connection). Production should use a wider range (49152-65535) or whatever the cloud firewall allows.

### Metered.ca HTTP Call Pattern (Finch)

```elixir
# lib/cromulent/turn/metered.ex
# Source: https://www.metered.ca/docs/turn-rest-api/get-credentials-v2/
# Finch already started as Cromulent.Finch in application.ex

defmodule Cromulent.Turn.Metered do
  @behaviour Cromulent.Turn.Provider

  @impl true
  def get_ice_servers(_user_id) do
    api_key = System.get_env("TURN_API_KEY") || raise "TURN_API_KEY not set"
    url = "https://cromulent.metered.live/api/v2/turn/credentials?secretKey=#{api_key}"

    case Finch.build(:get, url) |> Finch.request(Cromulent.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        servers = Jason.decode!(body)
        # Metered returns username/password/urls — map to iceServers format
        ice_servers = Enum.map(servers["data"], fn cred ->
          %{urls: "turn:cromulent.metered.live", username: cred["username"], credential: cred["password"]}
        end)
        {:ok, [%{urls: "stun:stun.l.google.com:19302"} | ice_servers]}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `:crypto.hmac(:sha, key, data)` | `:crypto.mac(:hmac, :sha, key, data)` | OTP 24 (removed OTP 26) | Must use new form — old form raises `UndefinedFunctionError` on OTP 26.1.2 |
| `RTCPeerConnection` with single STUN only | STUN + TURN with time-limited credentials | WebRTC best practice | Required for users behind symmetric NAT or corporate firewalls |
| Coturn `lt-cred-mech` (long-term static users) | `use-auth-secret` (HMAC time-limited) | Coturn 4.x | No user database needed; credentials generated server-side on demand |

**Deprecated/outdated:**
- `:crypto.hmac/3`: Removed in OTP 26. Use `:crypto.mac(:hmac, algorithm, key, data)`.
- Coturn `lt-cred-mech` with static user DB: Still works but requires managing a user list. `use-auth-secret` is the correct REST API / time-limited credential mode that matches the HMAC scheme chosen.

---

## Open Questions

1. **Metered.ca `appname` subdomain format**
   - What we know: Metered API URL is `https://<appname>.metered.live/api/v2/turn/credentials` — the appname is assigned when you create a Metered account
   - What's unclear: The Metered provider implementation will need `TURN_API_URL` (the full base URL) rather than constructing it from appname
   - Recommendation: Have the Metered provider read `TURN_API_URL` from environment (e.g., `https://yourapp.metered.live`) and append the path — this is more flexible than hardcoding the subdomain format

2. **Connection state reporting: JS hook → LiveView → VoiceBar**
   - What we know: The `voice_state_changed` pushEvent from JS to LiveView will update the `voice_connection_state` assign; LiveView re-renders VoiceBar with the new prop
   - What's unclear: The exact `handle_event("voice_state_changed", ...)` wiring in LiveView — straightforward pattern but not yet sketched for the failure case (channel join error vs. peer disconnect after success)
   - Recommendation: Two paths: (a) `receive("error")` in JS triggers `voice_state_changed: disconnected`, and (b) `peer.onconnectionstatechange` for `"failed"` state also triggers `voice_state_changed: disconnected`

3. **Coturn `network_mode: host` in docker-compose**
   - What we know: `network_mode: host` avoids Docker NAT complications that can break TURN relay (TURN must advertise a real IP, not a Docker bridge IP)
   - What's unclear: On Mac/Windows Docker, `network_mode: host` behaves differently and may not work. This is a Linux-specific optimization.
   - Recommendation: Document in docker-compose comments that `network_mode: host` is Linux-only; Mac/Windows devs may need to use `TURN_URL=stun:stun.l.google.com:19302` only (STUN-only mode) until further testing

---

## Sources

### Primary (HIGH confidence)
- Phoenix Presence official docs (https://hexdocs.pm/phoenix/Phoenix.Presence.html) — `list/1` return structure, `track/3` API
- Erlang OTP `:crypto` docs (https://www.erlang.org/doc/apps/crypto/crypto.html) — `:crypto.mac/4` form for OTP 24+
- Coturn wiki (https://github.com/coturn/coturn/wiki/turnserver) — `use-auth-secret`, credential format
- Coturn official turnserver.conf (https://github.com/coturn/coturn/blob/master/docker/coturn/turnserver.conf) — config file options
- Phoenix LiveView JS interop docs (https://hexdocs.pm/phoenix_live_view/js-interop.html) — `handleEvent`, `pushEvent` hook patterns
- Metered.ca REST API docs (https://www.metered.ca/docs/turn-rest-api/get-credentials-v2/) — endpoint, response format
- Elixir behaviour pattern (https://www.djm.org.uk/posts/writing-extensible-elixir-with-behaviours-adapters-pluggable-backends/) — `@behaviour`, `@callback`, runtime selection pattern

### Secondary (MEDIUM confidence)
- Coturn Docker Hub (https://hub.docker.com/r/coturn/coturn) — image name `coturn/coturn`, version `4.6`
- Coturn docker-compose example (https://github.com/coturn/coturn/blob/master/docker/docker-compose-all.yml) — port mapping patterns
- TURN REST API draft (https://www.ietf.org/proceedings/87/slides/slides-87-behave-10.pdf) — `timestamp:username` format spec

### Tertiary (LOW confidence — verified against multiple sources)
- `network_mode: host` for Coturn in docker-compose: documented in multiple blog posts as the recommended approach for Linux dev, but Mac/Windows behavior not confirmed

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are built-in or already in the project; Coturn is the official image
- Architecture: HIGH — Presence list/1 API verified from official docs; HMAC credential scheme verified from Coturn wiki + RFC references; Behaviour pattern verified from official Elixir patterns
- Pitfalls: HIGH — `:crypto.hmac` deprecation is a documented OTP change; TURN credential TTL is a known WebRTC ops concern; ICE server field naming is verified from MDN/WebRTC specs

**Research date:** 2026-03-01
**Valid until:** 2026-06-01 (stable domain — Coturn, Phoenix Presence, OTP crypto APIs change slowly)
