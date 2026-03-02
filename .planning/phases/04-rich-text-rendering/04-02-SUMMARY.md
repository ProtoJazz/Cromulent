---
phase: 04-rich-text-rendering
plan: 02
subsystem: ui
tags: [link-preview, open-graph, finch, floki, pubsub, liveview, xss-prevention]

# Dependency graph
requires:
  - phase: 04-01
    provides: MessageComponent with segment rendering, Floki available in all envs
provides:
  - Cromulent.Messages.LinkPreview module with fetch/1 and extract_first_link/1
  - Async OG metadata fetch via Task.start in RoomServer
  - PubSub broadcast {:link_preview, message_id, preview} after fetch success
  - ChannelLive handle_info patches in-memory messages with :link_preview key
  - MessageComponent link_preview/1 private component renders Discord-style preview card
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Fire-and-forget Task.start from GenServer cast for async work without blocking response
    - PubSub broadcast to deliver async result back to all connected LiveViews
    - In-memory message patching via Enum.map in handle_info (no DB write)
    - try/rescue wrapping Finch.build to convert ArgumentError to {:error, :fetch_failed}

key-files:
  created:
    - lib/cromulent/messages/link_preview.ex
    - test/cromulent/messages/link_preview_test.exs
  modified:
    - lib/cromulent/chat/room_server.ex
    - lib/cromulent_web/live/channel_live.ex
    - lib/cromulent_web/components/message_component.ex

key-decisions:
  - "try/rescue wraps Finch.request to convert ArgumentError for invalid URL schemes (javascript:, bare words) into {:error, :fetch_failed} rather than raising"
  - "Task.start (not Task.async) for fire-and-forget from GenServer — no caller awaiting result"
  - "LINK_PREVIEWS=disabled env guard uses System.get_env at cast time (runtime), not compile time"
  - "Only first URL per message gets a preview (extract_first_link/1 returns single result)"
  - "og:image stripped to nil unless https:// scheme — prevents javascript: XSS in img src"

patterns-established:
  - "Async enrichment pattern: broadcast message immediately, then asynchronously enrich with Task.start + PubSub re-broadcast"
  - "In-memory patch pattern: handle_info updates assigns.messages list without DB roundtrip"

requirements-completed: [RTXT-03]

# Metrics
duration: 2min
completed: 2026-03-02
---

# Phase 04 Plan 02: Link Preview Cards Summary

**Ephemeral Open Graph link preview cards via async Finch/Floki fetch — fire-and-forget Task from RoomServer, PubSub patch to ChannelLive, Discord-style card in MessageComponent**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-02T02:13:08Z
- **Completed:** 2026-03-02T02:15:27Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Created `LinkPreview` module with `fetch/1` (Finch + Floki OG extraction) and `extract_first_link/1` (excludes image extension URLs)
- Security: og:image URLs with non-https scheme stripped to nil, preventing javascript: XSS attacks
- RoomServer fires async Task.start after message broadcast; broadcasts `{:link_preview, msg_id, preview}` on PubSub on success
- ChannelLive `handle_info` patches in-memory messages list with `:link_preview` key without database writes
- MessageComponent renders Discord-style preview card with image thumbnail, title, description, and URL link
- LINK_PREVIEWS=disabled env guard prevents any fetch attempt when set

## Task Commits

Each task was committed atomically:

1. **TDD RED - LinkPreview failing tests** - `309720f` (test)
2. **Task 1: LinkPreview module + RoomServer async fetch** - `0534c9a` (feat)
3. **Task 2: ChannelLive handle_info + MessageComponent preview card** - `00cba63` (feat)

## Files Created/Modified

- `lib/cromulent/messages/link_preview.ex` - LinkPreview module: fetch/1 with Finch+Floki, extract_first_link/1, og:image https validation
- `test/cromulent/messages/link_preview_test.exs` - 9 unit tests for extract_first_link/1 and fetch/1 error cases
- `lib/cromulent/chat/room_server.ex` - Added async Task.start block in handle_cast :broadcast_message for OG fetch
- `lib/cromulent_web/live/channel_live.ex` - Added handle_info({:link_preview, msg_id, preview}) before catch-all
- `lib/cromulent_web/components/message_component.ex` - Added link_preview/1 private component and rendering call

## Decisions Made

- **try/rescue for Finch ArgumentError:** Finch raises `ArgumentError` for invalid URL schemes (e.g., `javascript:alert(1)`, bare words without scheme). Wrapped `Finch.build/Finch.request` in try/rescue to normalize these to `{:error, :fetch_failed}` - ensures consistent return contract from `fetch/1`.
- **Task.start not Task.async:** Fire-and-forget from GenServer cast — no caller waiting to receive result. Using Task.async would leave an unlinked task that could crash the caller if awaited, and Task.async/await would block the cast handler.
- **No DB storage:** Previews are ephemeral — attached to in-memory message maps only. Users who join after the preview TTL or reload lose the preview. Acceptable for v1 per plan spec.
- **Only first URL per message:** extract_first_link/1 returns first non-image URL to prevent preview flooding in URL-heavy messages.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wrap Finch.request in try/rescue for ArgumentError on invalid URL schemes**
- **Found during:** Task 1 (GREEN phase - tests revealed Finch raises for invalid schemes)
- **Issue:** `Finch.build(:get, "javascript:alert(1)", ...)` raises `ArgumentError: invalid scheme "javascript"` instead of returning an error tuple. Tests for `{:error, :fetch_failed}` failed with exception.
- **Fix:** Wrapped `Finch.build |> Finch.request` in a `try/rescue` block that returns `{:error, :fetch_failed}` on any exception, maintaining the documented return contract.
- **Files modified:** `lib/cromulent/messages/link_preview.ex`
- **Verification:** All 9 tests pass including the invalid-scheme test cases.
- **Committed in:** `0534c9a` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in error handling contract)
**Impact on plan:** Fix necessary for correct function contract. No scope creep.

## Issues Encountered

- Pre-existing test failures in `test/cromulent/accounts_test.exs` (112 failures for username validation in fixtures) are unrelated to this plan and were present before execution. Scoped to out-of-bounds, not fixed.

## LINK_PREVIEWS env guard verification

The `LINK_PREVIEWS=disabled` guard is implemented via `System.get_env("LINK_PREVIEWS") != "disabled"` check inside `handle_cast` at runtime. When set, no `extract_first_link/1` call is made and no Task is started. This was code-reviewed for correctness; runtime env testing requires a running server.

## Next Phase Readiness

- All four RTXT requirements (RTXT-01, RTXT-02, RTXT-03, RTXT-04) are implemented across Plans 01 and 02:
  - RTXT-01: Markdown rendering via MDEx (Plan 01)
  - RTXT-02: Image embedding inline (Plan 01)
  - RTXT-03: Link preview cards via async OG fetch (Plan 02 - this plan)
  - RTXT-04: XSS sanitization - MDEx sanitize options + og:image https scheme validation (Plans 01+02)
- Phase 04 (Rich Text Rendering) is now complete
- Phase 05 or Phase 06 can proceed

## Self-Check: PASSED

- lib/cromulent/messages/link_preview.ex: FOUND
- test/cromulent/messages/link_preview_test.exs: FOUND
- .planning/phases/04-rich-text-rendering/04-02-SUMMARY.md: FOUND
- Commit 309720f (TDD RED): FOUND
- Commit 0534c9a (Task 1 feat): FOUND
- Commit 00cba63 (Task 2 feat): FOUND

---
*Phase: 04-rich-text-rendering*
*Completed: 2026-03-02*
