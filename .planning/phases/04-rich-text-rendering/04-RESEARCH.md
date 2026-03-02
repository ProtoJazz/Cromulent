# Phase 4: Rich Text Rendering - Research

**Researched:** 2026-03-01
**Domain:** Elixir server-side markdown rendering, XSS sanitization, Open Graph metadata fetching, inline image embedding
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Image embed behavior**: Auto-embed any image URL (bare URLs ending in .jpg, .png, .gif, .webp, etc.) — no explicit markdown syntax required
- **Image embed scope**: All image URLs in a message embed inline (not just the first one)
- **Image display size**: Max ~400px wide x ~300px tall, maintaining aspect ratio
- **Broken image behavior**: Show a placeholder (broken-image icon in a subtle gray box); keep the URL text visible in the message
- **Image hosting**: Images are externally hosted — the server renders an `<img src="...">` tag pointing to the original URL

### Claude's Discretion

- Markdown rendering approach: server-side (Earmark) vs client-side JS library — Claude chooses what fits the Phoenix LiveView architecture
- Markdown feature depth: which subset of GFM to support (bold, italic, code, blockquotes, lists are in success criteria; tables/strikethrough are not required)
- Input experience: whether to upgrade the single-line input to a textarea, and whether to add a preview toggle
- Link preview fetch strategy: at send time (stored) vs on-demand (ephemeral), single vs multiple previews per message
- XSS sanitization approach: library choice and sanitization rules

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RTXT-01 | Messages render markdown formatting (bold, italic, code blocks, lists, blockquotes) | MDEx 0.11.6 with server-side rendering in `message_component.ex`; extend `parse_segments/1` pipeline |
| RTXT-02 | URLs in messages are automatically linked | MDEx `extension: [autolink: true]` converts bare URLs to `<a>` tags at render time |
| RTXT-03 | URLs display a preview card with title, description, and thumbnail (Open Graph) | Finch (already in `mix.exs`) + Floki (already in `:test` deps, promote to all) for OG fetch; ephemeral fetch via `Task.start_link` in RoomServer on message send |
| RTXT-04 | Image URLs display inline as embedded images | URL regex detection in `parse_segments/1`; render `<img>` tags via Phoenix Component with max-w and onerror fallback |
</phase_requirements>

## Summary

Phase 4 adds rich text rendering to the Cromulent chat application. The work decomposes into four tightly related areas: markdown rendering with XSS sanitization (RTXT-01 + RTXT-02), inline image embedding (RTXT-04), and link preview cards (RTXT-03). All rendering happens server-side in Phoenix Components, consistent with the project's established pattern.

**Markdown rendering:** The modern Elixir choice is MDEx 0.11.6 (Feb 2026), a Rust-backed library that is ~19x faster than Earmark, has native Phoenix LiveView HEEx integration, built-in XSS sanitization via ammonia, and a clean extension API for autolinks. The existing `parse_segments/1` pipeline in `message_component.ex` already splits text by `@mentions`; it should be extended to also detect image URLs and, after that extraction, pass remaining text through MDEx for markdown conversion. The rendered HTML is then emitted using `Phoenix.HTML.raw/1` inside the template — safe because MDEx's sanitize pass already removed dangerous tags.

**Image embedding (RTXT-04):** Image URLs are detected by regex in the `parse_segments/1` phase (before markdown rendering) and emitted as `{:image, url}` segment tuples. The message component renders each as a constrained `<img>` with Tailwind classes (`max-w-[400px] max-h-[300px] object-contain`) and an `onerror` handler that swaps in a broken-image placeholder. No new dependency is needed.

**Link preview cards (RTXT-03):** At send time (after `create_message` succeeds), RoomServer fires `Task.start_link` to asynchronously fetch OG metadata using the already-present Finch HTTP client and Floki HTML parser. If successful, RoomServer broadcasts an `{:link_preview, message_id, preview_map}` PubSub message; ChannelLive patches the relevant message in its `messages` list, and the message component renders a Discord/Slack-style preview card. No database table is required for the phase's scope — previews are ephemeral per-process. Floki must be promoted from `:test`-only to all environments.

**Primary recommendation:** Use MDEx for all markdown + autolink rendering with sanitization enabled via `features: [sanitize: true]`; handle image embedding with a regex segment detector; implement link previews as ephemeral async fetches at send time using Finch + Floki.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MDEx | ~> 0.11 (0.11.6 current) | Markdown → HTML with autolinks, XSS sanitization | Rust-backed, 19x faster than Earmark, built-in ammonia sanitizer, native Phoenix LiveView support, actively maintained (Feb 2026) |
| Finch | ~> 0.13 (already in mix.exs) | HTTP client for OG metadata fetching | Already present (used by Swoosh); zero new dependency cost |
| Floki | ~> 0.36 | HTML parser for extracting OG meta tags | Already in mix.exs (`:test` only); must promote to all envs |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| html_sanitize_ex | ~> 1.4 (1.4.4 stable) | Custom scrubber if MDEx sanitization gaps found | Use only if MDEx's ammonia-based sanitize misses required attributes (unlikely) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MDEx | Earmark 1.4.48 | Earmark is pure Elixir (no Rust), simpler deps, but 19x slower and no built-in sanitizer — would require adding html_sanitize_ex separately |
| MDEx | Client-side JS (marked.js, etc.) | Breaks server-side rendering pattern; requires LiveView hooks; no sanitization without additional JS library |
| Finch + Floki (DIY) | `open_graph` hex package (v0.0.6) | `open_graph` is minimally maintained (3 years between v0.0.5 and v0.0.6), low adoption; Finch + Floki is more control and already in the project |

**Installation:**
```bash
# In mix.exs deps:
{:mdex, "~> 0.11"},
# Promote floki from test-only to all:
{:floki, ">= 0.30.0"},
```

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── cromulent/
│   ├── messages/
│   │   ├── message.ex            # Existing schema (no changes)
│   │   ├── mention_parser.ex     # Existing (no changes)
│   │   └── link_preview.ex       # NEW: OG fetch logic using Finch + Floki
│   └── chat/
│       └── room_server.ex        # MODIFIED: broadcast link_preview after send
└── cromulent_web/
    └── components/
        └── message_component.ex  # MODIFIED: parse_segments, render markdown + images + preview card
```

### Pattern 1: Extended parse_segments/1 Pipeline

**What:** The existing `parse_segments/1` function is extended to emit three segment types: `{:mention, token}`, `{:image, url}`, and `{:markdown, text}`. Markdown text is then passed to MDEx at render time.

**When to use:** Always — this extends the established pattern without breaking mention rendering.

**Example:**
```elixir
# Source: existing message_component.ex + MDEx docs
defp parse_segments(body) do
  image_url_regex = ~r/https?:\/\/\S+\.(?:jpg|jpeg|png|gif|webp|svg)/i
  mention_regex = ~r/@([\w]+)/

  # 1. Split on image URLs first
  body
  |> split_images(image_url_regex)
  |> Enum.flat_map(fn
    {:image, url} -> [{:image, url}]
    text ->
      # 2. Within non-image text, split on @mentions
      mention_regex
      |> Regex.split(text, include_captures: true, trim: false)
      |> Enum.map(fn part ->
        case Regex.run(~r/^@([\w]+)$/, part, capture: :all_but_first) do
          [token] -> {:mention, token}
          nil -> {:markdown, part}
        end
      end)
  end)
  |> Enum.reject(&match?({:markdown, ""}, &1))
end
```

### Pattern 2: MDEx Rendering with Sanitization

**What:** Markdown text segments are rendered through MDEx with autolink enabled and sanitization enabled. Result is passed to `Phoenix.HTML.raw/1`.

**When to use:** For all `{:markdown, text}` segments in the message component.

**Example:**
```elixir
# Source: MDEx docs (hexdocs.pm/mdex, mdelixir.dev)
defp render_markdown(text) do
  MDEx.to_html!(text,
    extension: [autolink: true, strikethrough: false, table: false],
    parse: [relaxed_autolinks: true],
    features: [sanitize: true]
  )
  |> Phoenix.HTML.raw()
end
```

**Note:** `render: [unsafe: true]` is NOT used because message body is user-generated. Sanitization via `features: [sanitize: true]` uses ammonia (Rust) to strip dangerous tags/attributes.

### Pattern 3: Image Segment Rendering

**What:** `{:image, url}` segments render as constrained `<img>` with broken-image fallback via `onerror`.

**When to use:** Every `{:image, url}` segment in the message component template.

**Example:**
```heex
<% {:image, url} -> %>
  <div class="mt-1">
    <img
      src={url}
      class="max-w-[400px] max-h-[300px] object-contain rounded"
      onerror="this.onerror=null; this.style.display='none'; this.nextElementSibling.style.display='flex'"
    />
    <div class="hidden w-[200px] h-[120px] rounded bg-gray-600 items-center justify-center text-gray-400 text-xs">
      [image unavailable]
      <span class="block text-[10px] break-all mt-1">{url}</span>
    </div>
  </div>
```

### Pattern 4: Ephemeral Link Preview — Fetch at Send Time

**What:** After message creation succeeds, RoomServer spawns a fire-and-forget `Task` to fetch OG metadata. If found, it broadcasts `{:link_preview, message_id, preview}` which ChannelLive handles by patching the messages list.

**When to use:** Whenever a message body contains a non-image URL. Only one preview per message (the first URL) to avoid flooding. Feature is opt-out via `LINK_PREVIEWS=disabled` env var (ties into ADMN-01 pattern).

**Example flow:**
```elixir
# In RoomServer handle_cast {:broadcast_message, message, ...}:
if url = extract_first_link(message.body) do
  Task.start(fn ->
    case Cromulent.Messages.LinkPreview.fetch(url) do
      {:ok, preview} ->
        PubSub.broadcast(Cromulent.PubSub, topic(channel_id),
          {:link_preview, message.id, preview})
      _ -> :noop
    end
  end)
end

# In ChannelLive handle_info:
def handle_info({:link_preview, msg_id, preview}, socket) do
  messages = Enum.map(socket.assigns.messages, fn
    %{id: ^msg_id} = m -> Map.put(m, :link_preview, preview)
    m -> m
  end)
  {:noreply, assign(socket, :messages, messages)}
end
```

**Preview struct:**
```elixir
%{
  title: "Page Title",        # og:title || <title>
  description: "...",          # og:description || meta description
  image_url: "https://...",    # og:image (optional)
  url: "https://..."           # canonical URL
}
```

### Pattern 5: OG Metadata Fetch with Finch + Floki

**What:** `LinkPreview.fetch/1` uses the already-started `Cromulent.Finch` (started by Swoosh) to GET the URL, then Floki extracts meta tags.

**Example:**
```elixir
# Source: kiru.io blog, Finch docs, Floki docs
defmodule Cromulent.Messages.LinkPreview do
  def fetch(url) when is_binary(url) do
    with {:ok, %{body: body, status: status}} when status in 200..299 <-
           Finch.build(:get, url, [{"user-agent", "Cromulent Link Preview"}])
           |> Finch.request(Cromulent.Finch, receive_timeout: 5_000),
         {:ok, document} <- Floki.parse_document(body) do
      {:ok, extract_og(document, url)}
    else
      _ -> {:error, :fetch_failed}
    end
  end

  defp extract_og(document, fallback_url) do
    meta = fn property ->
      Floki.find(document, "meta[property='#{property}'], meta[name='#{property}']")
      |> Floki.attribute("content")
      |> List.first()
    end

    %{
      title: meta.("og:title") || (Floki.find(document, "title") |> Floki.text()),
      description: meta.("og:description") || meta.("description"),
      image_url: meta.("og:image"),
      url: meta.("og:url") || fallback_url
    }
  end
end
```

### Anti-Patterns to Avoid

- **`render: [unsafe: true]` without sanitize:** Allows raw HTML from user messages through MDEx — never use without `features: [sanitize: true]` for user content.
- **`Phoenix.HTML.raw/1` on unsanitized input:** Calling `raw/1` directly on Earmark or string output without a sanitizer pass enables stored XSS.
- **Image embed via markdown `![](url)` only:** User decision is auto-detect bare image URLs, not require markdown image syntax.
- **Synchronous OG fetch in LiveView event handler:** Blocks the LiveView process for the duration of the HTTP request — always use `Task.start` for fire-and-forget.
- **Floki in `:test` only:** Floki must be promoted to all environments to be available in the OG fetch module at runtime.
- **Calling `Earmark.as_html/1`:** Earmark does not include sanitization; adds a second dependency for html_sanitize_ex. MDEx handles both.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown → HTML parsing | Custom regex markdown parser | MDEx `to_html!/2` | CommonMark compliance requires hundreds of edge cases (nested lists, code fences, escape sequences) |
| XSS sanitization | Custom HTML tag allowlist | MDEx `features: [sanitize: true]` (ammonia) or `html_sanitize_ex` | Sanitization must handle attribute injection, JavaScript URLs (`javascript:`), data URIs, event handlers — regex-based stripping is notoriously bypassable |
| URL → link conversion | Custom URL regex replacement | MDEx `extension: [autolink: true]` | URL regex matching is deceptively complex (trailing punctuation, parentheses, query strings) |
| HTTP client for OG fetch | Raw `:httpc` or `HTTPoison` | Finch (already present) | Connection pooling, timeouts, already supervised in the application |
| HTML parsing for OG tags | String scanning for meta tags | Floki | HTML is not regular; string scanning breaks on attribute order, whitespace, quoting variants |

**Key insight:** Markdown parsers and HTML sanitizers each represent years of edge case handling. The combination MDEx provides (parse + sanitize in one library call) is the entire value proposition.

## Common Pitfalls

### Pitfall 1: Image URL Detection Strips URLs from Markdown Rendering

**What goes wrong:** If the image URL regex splits the body but passes the full URL string into MDEx, MDEx's autolink will convert it to both an `<a>` tag AND the template emits an `<img>`. The URL appears twice.

**Why it happens:** Segment pipeline runs before MDEx, but image URLs match the autolink pattern.

**How to avoid:** Emit `{:image, url}` segments and do NOT pass image URL strings into MDEx. The split happens before markdown rendering, so image URLs never reach MDEx.

**Warning signs:** URLs appearing as both clickable links and embedded images.

### Pitfall 2: MDEx Sanitizer Strips Inline Code Backticks

**What goes wrong:** `features: [sanitize: true]` uses ammonia defaults which may strip `<code>` tags depending on version. Inline code becomes plain text.

**Why it happens:** Ammonia's default allowed tag set may not include `<code>` and `<pre>`.

**How to avoid:** Test inline code `` `example` `` and fenced code blocks through the full MDEx pipeline. If stripped, use `MDEx.to_html!(text, features: [sanitize: [allow_tags: ["code", "pre", "em", "strong", "ul", "ol", "li", "blockquote", "a", "p", "br"]]]])`. Verify in tests.

**Warning signs:** Backtick-wrapped text in messages shows as plain text without monospace styling.

### Pitfall 3: Floki Only in `:test` Deps

**What goes wrong:** `LinkPreview.fetch/1` compiles in dev/prod but Floki is not in the OTP release because it was declared `only: :test`.

**Why it happens:** mix.exs currently has `{:floki, ">= 0.30.0", only: :test}`.

**How to avoid:** Change to `{:floki, ">= 0.30.0"}` (remove `only: :test` restriction) before implementing link preview fetching.

**Warning signs:** `(UndefinedFunctionError) function Floki.parse_document/1 is undefined` in production/dev.

### Pitfall 4: OG Fetch Blocks LiveView on Send

**What goes wrong:** If OG fetch happens synchronously inside `handle_event("send_message", ...)`, the LiveView process blocks for up to the HTTP timeout (5s default Finch timeout). Chat feels frozen.

**Why it happens:** Finch.request/2 is a blocking call.

**How to avoid:** Always spawn OG fetch in `Task.start/1` from RoomServer, not from LiveView. The task runs in its own process; the LiveView event returns immediately.

**Warning signs:** `send_message` event handler takes 1-10 seconds to complete.

### Pitfall 5: Mixed Content (HTTP Image in HTTPS Page)

**What goes wrong:** `<img src="http://...">` embedded in an HTTPS-served page is blocked by browsers as mixed content. Broken image placeholder shows for all http:// images.

**Why it happens:** Most externally-hosted images use HTTPS but some don't.

**How to avoid:** Log this as a known limitation. Don't proxy images server-side (out of scope). The broken-image placeholder handles the UX gracefully per user decision.

**Warning signs:** All http:// image URLs show placeholder regardless of whether the image actually exists.

### Pitfall 6: XSS via og:image URL in Preview Card

**What goes wrong:** An attacker crafts a page with `<meta property="og:image" content="javascript:alert(1)">`. The preview card renders `<img src="javascript:alert(1)">`.

**Why it happens:** OG metadata is fetched from untrusted third-party pages.

**How to avoid:** Validate `image_url` extracted from OG metadata — only accept `https://` scheme. Strip any non-https image URLs from preview data before broadcasting.

**Warning signs:** Link preview image field contains non-https URL schemes.

## Code Examples

Verified patterns from official sources:

### MDEx Basic Markdown to HTML with Sanitization
```elixir
# Source: hexdocs.pm/mdex, mdelixir.dev
MDEx.to_html!("**bold** _italic_ `code`",
  extension: [autolink: true],
  features: [sanitize: true]
)
# => "<p><strong>bold</strong> <em>italic</em> <code>code</code></p>\n"
```

### MDEx Autolink Extension
```elixir
# Source: MDEx docs / web search verification
MDEx.to_html!("Visit https://example.com for info",
  extension: [autolink: true],
  parse: [relaxed_autolinks: true],
  features: [sanitize: true]
)
# => "<p>Visit <a href=\"https://example.com\">https://example.com</a> for info</p>\n"
```

### Finch OG Fetch Pattern
```elixir
# Source: kiru.io/blog/posts/2023/analyze-meta-tags-with-elixir + Finch docs
{:ok, resp} = Finch.build(:get, url, [{"user-agent", "Cromulent/1.0"}])
              |> Finch.request(Cromulent.Finch, receive_timeout: 5_000)
{:ok, doc} = Floki.parse_document(resp.body)
og_title = Floki.find(doc, "meta[property='og:title']")
           |> Floki.attribute("content")
           |> List.first()
```

### Custom html_sanitize_ex Scrubber (fallback)
```elixir
# Source: github.com/rrrene/html_sanitize_ex
defmodule Cromulent.MarkdownScrubber do
  use HtmlSanitizeEx
  allow_tag_with_these_attributes("p", [])
  allow_tag_with_these_attributes("strong", [])
  allow_tag_with_these_attributes("em", [])
  allow_tag_with_these_attributes("code", [])
  allow_tag_with_these_attributes("pre", [])
  allow_tag_with_these_attributes("ul", [])
  allow_tag_with_these_attributes("ol", [])
  allow_tag_with_these_attributes("li", [])
  allow_tag_with_these_attributes("blockquote", [])
  allow_tag_with_these_attributes("br", [])
  allow_tag_with_uri_attributes("a", ["href"], ["https", "http", "mailto"])
end
```

### Image Broken-Image Fallback (HEEx)
```heex
<%# Source: MDN onerror pattern + Tailwind %>
<img
  src={url}
  class="max-w-[400px] max-h-[300px] object-contain rounded mt-1"
  onerror="this.style.display='none'; this.nextElementSibling.style.removeProperty('display')"
/>
<div style="display:none" class="flex w-48 h-24 rounded bg-gray-600 items-center justify-center text-xs text-gray-400 mt-1">
  Image unavailable
</div>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Earmark + html_sanitize_ex (two deps) | MDEx (markdown + sanitize in one) | MDEx reached stability ~2024 | Fewer deps, faster, native LiveView support |
| Client-side markdown (marked.js) | Server-side MDEx | Established in Phoenix community | Consistent with LiveView SSR pattern, no JS bundle cost |
| Inline Task.async for async work in LiveView | LiveView `assign_async/3` / `start_async/4` | LiveView 0.20.0 (2023) | For previews, RoomServer `Task.start` is simpler since it's not LiveView-owned work |

**Deprecated/outdated:**
- `Earmark.as_ast/2`: Deprecated in Earmark — use `EarmarkParser.as_ast/2` if using Earmark at all (moot since MDEx is preferred)
- `{:floki, only: :test}`: Must change to all-env before using Floki in LinkPreview module

## Open Questions

1. **MDEx sanitize: does it allow `<code>` and `<pre>` by default?**
   - What we know: Sanitization uses ammonia (Rust). Default allowed tags not enumerated in fetched docs.
   - What's unclear: Whether `code`, `pre`, `blockquote` are in ammonia's default allowlist.
   - Recommendation: Write a test in Wave 0: `MDEx.to_html!("` `` `code` `` `", features: [sanitize: true])` and assert it contains `<code>`. If not, use explicit `allow_tags` option.

2. **Link preview: one preview per message or all URLs?**
   - What we know: Context.md leaves this to Claude's discretion; Slack/Discord show one preview per message.
   - What's unclear: Whether multiple previews add meaningful UX value vs. visual clutter.
   - Recommendation: Implement single preview (first URL) to keep scope tight. Multi-preview can be added later.

3. **ADMN-01 feature toggle for link previews**
   - What we know: ADMN-01 (Phase 5) covers feature toggles via env vars. Link previews are a good candidate.
   - What's unclear: Whether Phase 4 should pre-plumb the `LINK_PREVIEWS` env var check or leave it for Phase 5.
   - Recommendation: Add `System.get_env("LINK_PREVIEWS") != "disabled"` guard in RoomServer at fetch time. Simple one-liner, doesn't require Phase 5's full config system.

## Sources

### Primary (HIGH confidence)
- [hexdocs.pm/mdex](https://hexdocs.pm/mdex/MDEx.html) — API functions, sanitize option, autolink extension, render options
- [hex.pm/packages/mdex](https://hex.pm/packages/mdex) — version 0.11.6, released Feb 24 2026
- [mdelixir.dev](https://mdelixir.dev/) — feature list, sanitization strategy, LiveView integration
- [hex.pm/packages/earmark](https://hex.pm/packages/earmark) — version 1.4.48, June 2025 (for comparison)
- [hex.pm/packages/html_sanitize_ex](https://hex.pm/packages/html_sanitize_ex) — version 1.4.4, November 2025
- [github.com/rrrene/html_sanitize_ex](https://github.com/rrrene/html_sanitize_ex) — custom scrubber API with code examples
- Codebase read: `lib/cromulent_web/components/message_component.ex` — parse_segments, existing segment types
- Codebase read: `lib/cromulent_web/live/channel_live.ex` — message send flow, handle_info patterns
- Codebase read: `lib/cromulent/chat/room_server.ex` — broadcast pattern, Task usage context
- Codebase read: `mix.exs` — Finch present, Floki test-only, no markdown library

### Secondary (MEDIUM confidence)
- [kiru.io blog: Analyze Meta Tags With Elixir](https://kiru.io/blog/posts/2023/analyze-meta-tags-with-elixir/) — Finch + Floki OG extraction pattern (2023, verified against Finch and Floki docs)
- [MDEx forum thread](https://elixirforum.com/t/mdex-fast-and-extensible-markdown/70540) — 19x faster than Earmark benchmark claim (community, not official)
- [Slack link unfurling architecture](https://medium.com/slack-developer-blog/everything-you-ever-wanted-to-know-about-unfurling-but-were-afraid-to-ask-or-how-to-make-your-e64b4bb9254) — fetch-at-send-time with caching pattern

### Tertiary (LOW confidence)
- MDEx ammonia default allowed tag set — not explicitly documented in fetched pages; needs empirical validation in Wave 0 test

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — MDEx version verified on hex.pm (Feb 2026), Finch and Floki in mix.exs confirmed by file read, html_sanitize_ex version verified
- Architecture: HIGH — parse_segments extension pattern follows existing code structure; OG fetch pattern verified against Finch + Floki docs
- Pitfalls: MEDIUM-HIGH — Floki test-only pitfall confirmed by reading mix.exs; XSS via OG metadata is established security concern; MDEx sanitize tag coverage is LOW pending test validation

**Research date:** 2026-03-01
**Valid until:** 2026-04-01 (MDEx is actively maintained, API stable as of 0.11.x)
