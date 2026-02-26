# Stack Research

**Domain:** Chat and voice application enhancements (notifications, rich text, voice reliability)
**Researched:** 2026-02-26
**Confidence:** HIGH for Elixir/Phoenix libraries, MEDIUM for Electron notification patterns

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **earmark** | 1.4.46+ | Markdown parsing and HTML generation | De facto standard Elixir markdown parser, pure Elixir (no external deps), Phoenix-friendly HTML output, actively maintained, handles GitHub-flavored markdown |
| **coturn** | 4.6+ | TURN/STUN server for WebRTC NAT traversal | Industry-standard open-source TURN server, Docker-friendly, integrates with Phoenix Channels via ICE candidate exchange, essential for restrictive NAT/firewall scenarios |
| **linkify** | 0.5+ | URL detection and link parsing in text | Elixir-native library for URL extraction, configurable schemes, integrates with markdown rendering pipeline, used by Pleroma/Akkoma (proven in production chat apps) |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **makeup** | 1.1+ | Code syntax highlighting | Use for syntax-highlighted code blocks in markdown, supports 20+ languages via Makeup.Lexers, generates HTML with CSS classes |
| **makeup_elixir** | 0.16+ | Elixir syntax highlighting lexer | Use with Makeup for Elixir code blocks, maintained by same team as core Makeup |
| **makeup_js** | 0.1+ | JavaScript syntax highlighting | Use with Makeup for JS/TS code blocks |
| **html_sanitize_ex** | 1.4+ | HTML sanitization for user content | Prevent XSS when rendering markdown, allowlist-based, configurable tag/attribute rules, essential for user-generated rich text |

### Frontend/Electron Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **Tribute.js** | 5.1.3+ | @mention autocomplete UI | Lightweight autocomplete library (8KB), framework-agnostic, works with LiveView phx-hooks, handles @ trigger, keyboard navigation, and custom search |
| **Howler.js** | 2.2.4+ | Cross-browser audio playback | Robust Web Audio API wrapper, handles audio sprites, volume control, preloading, better than raw HTMLAudioElement for notification sounds |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **ExVCR** | HTTP interaction recording for tests | Record URL unfurling responses, test link preview extraction without hitting external sites, integrates with ExUnit |

## Installation

**Elixir (mix.exs dependencies):**

```elixir
defp deps do
  [
    # Existing dependencies...

    # Rich text and markdown
    {:earmark, "~> 1.4"},
    {:html_sanitize_ex, "~> 1.4"},
    {:linkify, "~> 0.5"},

    # Code syntax highlighting
    {:makeup, "~> 1.1"},
    {:makeup_elixir, "~> 0.16"},
    {:makeup_js, "~> 0.1"},

    # Testing (optional)
    {:ex_vcr, "~> 0.14", only: :test}
  ]
end
```

**Frontend (assets/package.json):**

```json
{
  "dependencies": {
    "tributejs": "^5.1.3",
    "howler": "^2.2.4"
  }
}
```

**Docker (docker-compose.yml addition):**

```yaml
services:
  coturn:
    image: coturn/coturn:4.6-alpine
    network_mode: host
    volumes:
      - ./coturn.conf:/etc/coturn/turnserver.conf
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **earmark** | Cmark (C-based via NIF) | Use Cmark if markdown parsing is a bottleneck (rare), but earmark is fast enough for chat messages and avoids NIF compilation complexity for self-hosters |
| **Tribute.js** | Custom LiveView autocomplete with phx-change | Build custom if you need server-side search with DB queries for large user counts, but Tribute.js is simpler for client-side filtering of known channel members |
| **Makeup** | Pygments via Python port | Use Makeup for native Elixir solution, avoid external process overhead and deployment complexity |
| **coturn** | Managed TURN (xirsys.com or Twilio) | Use managed TURN if self-hosting coturn is too complex, but coturn is the self-hostable standard and aligns with project goals |
| **linkify** | Custom regex URL detection | Use linkify for battle-tested URL detection, regex is error-prone for edge cases (ports, query params, unicode) |
| **Howler.js** | Raw Web Audio API / HTMLAudioElement | Use Howler.js unless you need zero dependencies, it handles browser autoplay policies and audio context quirks |
| **Custom unfurl (Finch + Floki)** | unfurl hex package | Build custom because Finch and Floki are already in the stack (Floki for tests, Finch for Swoosh), and link unfurling logic is simple enough to own |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **markdown-it or marked (JS, server-side rendering)** | Client-side markdown parsing creates XSS risk if user controls input, also duplicates work already happening server-side in Elixir | **earmark** on server with html_sanitize_ex, then send rendered HTML to client |
| **react-mentions or @tiptap** | Requires React or a rich text editor framework, doesn't integrate with LiveView's server-rendered approach, massive dependency overhead | **Tribute.js** for vanilla JS autocomplete that works with plain textareas |
| **node-notifier (npm)** | Redundant with Electron's built-in Notification API (available in renderer via window.Notification), adds native compilation dependency | Native **Electron Notification API** via preload.js IPC bridge |
| **Showdown.js** | Not actively maintained | **earmark** (server-side) |
| **twilio-video or agora.io SDKs** | SFU/MCU solutions for large-scale video, massive overkill for small-group peer-to-peer audio | Existing WebRTC with **coturn** TURN server for NAT traversal |
| **Prism.js** | Large bundle size (300KB+ with languages), client-side only, when server-side highlighting avoids shipping language packs to browser | **Makeup** on server, emit pre-highlighted HTML with CSS classes |

## Stack Patterns by Feature

### @Mention Autocomplete

**Server-side (Phoenix):**
- No new backend libraries needed
- Expose user/group list via LiveView assign: `socket.assigns.mentionable_users`
- Pass data to hook via `data-*` attributes or `phx-hook` element dataset

**Client-side (assets/js):**
- **Tribute.js** attached to message input via LiveView hook
- Configure tribute with `trigger: '@'`, populate from hook's `el.dataset`
- Keyboard navigation (up/down/enter/escape) handled by Tribute.js out of the box

### Desktop Notifications

**Electron:**
- Use native **Electron Notification API** (no additional library needed)
- Listen for Phoenix Channel events in the renderer process
- Create notification via preload bridge
- Focus window on notification click

**Browser fallback:**
- Use **Web Notifications API** (`window.Notification`) for browser users
- Request permission on first mention event
- Graceful degradation: if permission denied, show in-app indicator only

### Rich Text / Markdown Rendering

**Server-side rendering pipeline:**
- **earmark** parses markdown to HTML
- **html_sanitize_ex** sanitizes output (allowlist safe tags)
- **linkify** detects and auto-links bare URLs
- **Makeup** highlights code blocks

### TURN Server Integration

**Infrastructure (Docker):**
- Run **coturn** as a separate container alongside PostgreSQL
- Minimal configuration with static-auth-secret for credential generation

**Phoenix integration:**
- Generate time-limited TURN credentials using HMAC-SHA1
- Pass credentials to client via `push_event` when joining voice

### Notification Sounds

**Asset management:**
- Store sound files in `priv/static/sounds/` (e.g., `mention.mp3`, `message.mp3`, `join.mp3`)
- Phoenix serves from `/sounds/` via static plug
- Use short audio clips (under 1 second, under 50KB each)

**Client-side:**
- **Howler.js** for cross-browser audio playback
- Preload sounds on page load
- Respect browser tab visibility: only play sounds when window is not focused

## Security Considerations

| Component | Risk | Mitigation |
|-----------|------|-----------|
| **Markdown rendering** | XSS via unsanitized HTML | Always pipe earmark output through `html_sanitize_ex` before rendering |
| **Link unfurling** | SSRF (fetching internal URLs) | Validate URL scheme (https only in production), block private IP ranges, set request timeout |
| **TURN server** | Unauthorized relay usage | Use static-auth-secret with time-limited credentials (24h TTL), firewall relay ports |
| **@mention autocomplete** | Exposing hidden users | Filter mentionable users by channel membership before passing to Tribute.js |
| **Notification sounds** | Audio autoplay blocked | Howler.js handles browser autoplay policies, first interaction unlocks audio context |

## Configuration Patterns

### Feature Toggle Integration

```elixir
# config/runtime.exs
config :cromulent, :features,
  rich_text_enabled: System.get_env("RICH_TEXT_ENABLED", "true") == "true",
  notifications_enabled: System.get_env("NOTIFICATIONS_ENABLED", "true") == "true",
  turn_server_enabled: System.get_env("TURN_SERVER_ENABLED", "true") == "true",
  link_previews_enabled: System.get_env("LINK_PREVIEWS_ENABLED", "true") == "true"
```

## Sources

**HIGH CONFIDENCE:**
- **earmark** - Standard Elixir markdown parser used by ExDoc, maintained by the Elixir community
- **coturn** - Industry-standard open-source TURN server, recommended by WebRTC documentation
- **Electron Notification API** - Built into Electron, documented in official Electron docs
- **Tribute.js** - Active project by ZURB, widely used for @mention UIs
- **Howler.js** - Gold standard for web audio

**MEDIUM CONFIDENCE:**
- **linkify** - Used by Pleroma/Akkoma fediverse projects, less mainstream but proven
- **makeup** - Official Elixir syntax highlighting, powers ExDoc code display
- **html_sanitize_ex** - Well-maintained sanitizer, standard choice in Phoenix community

---
*Stack research for: Cromulent milestone - notifications, rich text, voice reliability*
*Researched: 2026-02-26*
