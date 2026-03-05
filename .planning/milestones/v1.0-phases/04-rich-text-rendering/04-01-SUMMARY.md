---
phase: 04-rich-text-rendering
plan: 01
subsystem: ui
tags: [mdex, markdown, phoenix-component, heex, xss-sanitization, image-embedding]

# Dependency graph
requires: []
provides:
  - Server-side markdown rendering in MessageComponent via MDEx 0.11.6
  - Three-segment parse pipeline: {:mention, token}, {:image, url}, {:markdown, text}
  - Inline image embedding with broken-image fallback
  - XSS-safe HTML output via MDEx.Document.default_sanitize_options()
  - Bare URL autolink via MDEx extension: [autolink: true]
affects: [04-02-link-previews, any phase touching message rendering]

# Tech tracking
tech-stack:
  added:
    - mdex 0.11.6 (Rust NIF via rustler_precompiled for comrak markdown rendering)
    - lumis 0.1.1, nimble_parsec 1.4.2, rustler_precompiled 0.8.4 (mdex transitive deps)
    - floki 0.38.0 promoted from test-only to all environments
  patterns:
    - Three-phase segment pipeline: image split -> mention split -> markdown remainder
    - MDEx.to_html!/2 with sanitize: MDEx.Document.default_sanitize_options() for XSS safety
    - Phoenix.HTML.raw/1 wrapping MDEx output for safe HEEx rendering
    - Image URL regex extracted before MDEx to prevent duplicate anchor tag rendering

key-files:
  created:
    - test/cromulent_web/components/message_component_test.exs
  modified:
    - mix.exs
    - mix.lock
    - lib/cromulent_web/components/message_component.ex
    - config/test.exs

key-decisions:
  - "MDEx 0.11 uses sanitize: MDEx.Document.default_sanitize_options() not features: [sanitize: true] — API changed from pre-0.11"
  - "Image URL regex splits BEFORE MDEx processing — prevents image URLs being double-rendered as both <img> and <a href>"
  - "MDEx default_sanitize_options() allows code, pre, strong, em, a, blockquote etc — explicit allow_tags not needed"
  - "config/test.exs fixed to use password: example and port: 5469 to match dev postgres container"

patterns-established:
  - "Segment pipeline pattern: split on structural elements (images, mentions) first, wrap remaining text in {:markdown, text} for MDEx"
  - "Always use MDEx.Document.default_sanitize_options() for sanitize option in MDEx 0.11+"

requirements-completed: [RTXT-01, RTXT-02, RTXT-04]

# Metrics
duration: 5min
completed: 2026-03-02
---

# Phase 04 Plan 01: Rich Text Rendering Summary

**MDEx 0.11.6 markdown rendering with three-segment parse pipeline (mentions, images, markdown), XSS-sanitized HTML, inline image embedding, and bare URL autolinks — all server-side in Phoenix Component**

## Performance

- **Duration:** 5 minutes
- **Started:** 2026-03-02T02:04:19Z
- **Completed:** 2026-03-02T02:09:36Z
- **Tasks:** 2
- **Files modified:** 5 (mix.exs, mix.lock, message_component.ex, test file created, config/test.exs)

## Accomplishments

- Added MDEx 0.11.6 as project dependency and promoted Floki from test-only to all environments
- Rewrote `parse_segments/1` to produce three segment types: `{:mention, token}`, `{:image, url}`, `{:markdown, text}`
- Added `render_markdown/1` using MDEx.to_html!/2 with autolink extension and XSS sanitization
- Updated HEEx render loop to handle all three segment types with image fallback UI
- 19 unit tests covering markdown rendering, image detection, mention pills, mixed content, and XSS safety

## MDEx Version Details

- MDEx 0.11.6 resolved (Rust NIF via rustler_precompiled, downloaded precompiled binary)
- API change from research notes: `features: [sanitize: true]` is INVALID in 0.11
- Correct form: `sanitize: MDEx.Document.default_sanitize_options()`
- Default sanitize options allow: strong, em, code, pre, a, blockquote, ul, ol, li, p, br — no explicit allow_tags needed

## Final parse_segments/1 Regex Patterns

- Image detection: `~r/https?:\/\/\S+\.(?:jpg|jpeg|png|gif|webp|svg)(?:\?\S*)?/i`
- Mention detection: `~r/@([\w]+)/` (unchanged from original)
- Split order: images first, then mentions within non-image segments, remaining text becomes `{:markdown, text}`

## Task Commits

Each task was committed atomically:

1. **Task 1: Add MDEx dependency and promote Floki to all environments** - `f003ce8` (chore)
2. **Task 2: Extend parse_segments/1 pipeline and render markdown, images, and mentions** - `e70e4c1` (feat)

## Files Created/Modified

- `mix.exs` - Added `{:mdex, "~> 0.11"}`, removed `only: :test` from Floki
- `mix.lock` - Updated with mdex 0.11.6 and its transitive deps
- `lib/cromulent_web/components/message_component.ex` - New parse_segments/1 pipeline, render_markdown/1, updated HEEx template
- `test/cromulent_web/components/message_component_test.exs` - 19 unit tests (created)
- `config/test.exs` - Fixed DB credentials (password: example, port: 5469)

## Decisions Made

- MDEx 0.11 API: `sanitize: MDEx.Document.default_sanitize_options()` is the correct form — `features: [sanitize: true]` raises `ArgumentError: unknown option :features`
- Image URL extraction happens before MDEx processing to prevent duplicate rendering (image as both `<img>` and MDEx autolink `<a>`)
- MDEx default sanitize options already allow `<code>`, `<pre>`, and other common safe tags — no explicit allowlist needed
- test.exs DB config was wrong (password "postgres" instead of "example", missing port 5469) — fixed as blocking Rule 3 deviation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] MDEx 0.11 features option invalid — API changed from plan**
- **Found during:** Task 2 (render_markdown/1 implementation)
- **Issue:** Plan specified `features: [sanitize: true]` but MDEx 0.11.6 removed the `:features` option key — calling `MDEx.to_html!/2` with it raised `ArgumentError: unknown option :features`
- **Fix:** Changed to `sanitize: MDEx.Document.default_sanitize_options()` which is the documented MDEx 0.11 API
- **Files modified:** lib/cromulent_web/components/message_component.ex
- **Verification:** All 19 tests pass, `mix compile` exits 0
- **Committed in:** e70e4c1 (Task 2 commit)

**2. [Rule 3 - Blocking] config/test.exs had wrong DB credentials**
- **Found during:** Task 2 TDD RED phase (couldn't run tests)
- **Issue:** test.exs used `password: "postgres"` and default port 5432, but actual postgres runs with `password: "example"` on port 5469
- **Fix:** Updated test.exs to `password: "example", port: 5469`
- **Files modified:** config/test.exs
- **Verification:** `mix test test/cromulent_web/components/message_component_test.exs` runs without DB connection errors
- **Committed in:** e70e4c1 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 3 - blocking issues)
**Impact on plan:** Both fixes necessary to complete the task. No scope creep. The MDEx API fix was expected per plan's "Pitfall" notes about checking sanitize options.

## Issues Encountered

- Pre-existing test failures exist throughout the test suite (accounts_test.exs, user registration live tests) — these are out-of-scope pre-existing failures not caused by this plan's changes. Logged to deferred-items for future attention.

## Next Phase Readiness

- MessageComponent now produces `{:image, url}` segments — Plan 02 link previews can detect these and add Floki-based URL scraping
- Floki is available at runtime (removed test-only restriction) — ready for Plan 02
- parse_segments/1 image regex is defined as module attribute `@image_url_regex` — Plan 02 can reference or extend it

---
*Phase: 04-rich-text-rendering*
*Completed: 2026-03-02*

## Self-Check: PASSED

- FOUND: lib/cromulent_web/components/message_component.ex
- FOUND: mix.exs (contains {:mdex, "~> 0.11"} and {:floki, ">= 0.30.0"})
- FOUND: test/cromulent_web/components/message_component_test.exs
- FOUND: .planning/phases/04-rich-text-rendering/04-01-SUMMARY.md
- FOUND commit f003ce8: chore(04-01): add MDEx dependency and promote Floki to all environments
- FOUND commit e70e4c1: feat(04-01): add rich text rendering with MDEx markdown, image embedding, and mention pills
