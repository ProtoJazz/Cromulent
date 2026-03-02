# Phase 4: Rich Text Rendering - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Messages display rich formatting with markdown, auto-linked URLs, link preview cards, and inline image embeds. Images are rendered from external URLs — no upload or server-side storage of images is in scope. User-generated markdown is sanitized to prevent XSS.

</domain>

<decisions>
## Implementation Decisions

### Image embed behavior
- Auto-embed any image URL (bare URLs ending in .jpg, .png, .gif, .webp, etc.) — no explicit markdown syntax required
- All image URLs in a message embed inline (not just the first one)
- Max display size: ~400px wide × ~300px tall, maintaining aspect ratio
- Broken image: show a placeholder (broken-image icon in a subtle gray box); keep the URL text visible in the message
- Images are externally hosted — the server renders an `<img src="...">` tag pointing to the original URL

### Claude's Discretion
- Markdown rendering approach: server-side (Earmark) vs client-side JS library — Claude chooses what fits the Phoenix LiveView architecture
- Markdown feature depth: which subset of GFM to support (bold, italic, code, blockquotes, lists are in success criteria; tables/strikethrough are not required)
- Input experience: whether to upgrade the single-line input to a textarea, and whether to add a preview toggle
- Link preview fetch strategy: at send time (stored) vs on-demand (ephemeral), single vs multiple previews per message
- XSS sanitization approach: library choice and sanitization rules

</decisions>

<specifics>
## Specific Ideas

No specific references — open to standard Discord/Slack-style image embedding behavior.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `parse_segments/1` in `lib/cromulent_web/components/message_component.ex`: already splits message body into `{:mention, token}` and plain text segments — this pipeline can be extended to also detect and split out image URLs and markdown spans
- `Finch` (already in `mix.exs`): used by Swoosh for email, can be reused for Open Graph metadata fetching for link previews

### Established Patterns
- Server-side rendering via Phoenix Components is the established pattern — no client-side rendering exists
- No markdown library is currently in `mix.exs` (neither Earmark nor any JS equivalent)
- Message body is stored as a plain `:string` in the `messages` table — rendering happens entirely at display time

### Integration Points
- `lib/cromulent_web/components/message_component.ex` — the `message/1` component's `<p class="break-words">` section (lines 86–99) is where rendered segments are displayed; this is the primary integration point
- Message body max length is 4000 chars (enforced in changeset) — relevant for any per-message rendering budget

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-rich-text-rendering*
*Context gathered: 2026-03-01*
