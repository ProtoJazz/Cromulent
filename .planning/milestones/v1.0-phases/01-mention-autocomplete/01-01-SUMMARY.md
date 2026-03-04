---
phase: 01-mention-autocomplete
plan: 01
subsystem: mention-autocomplete
tags: [backend, ui, liveview, accessibility]
dependency_graph:
  requires: []
  provides:
    - Autocomplete state management in ChannelLive
    - MentionAutocomplete dropdown component
    - Event handlers for autocomplete interactions
  affects:
    - lib/cromulent_web/live/channel_live.ex
tech_stack:
  added: []
  patterns:
    - Phoenix LiveView event handling
    - Flowbite dark theme styling
    - WAI-ARIA combobox pattern
key_files:
  created:
    - lib/cromulent_web/components/mention_autocomplete.ex
  modified:
    - lib/cromulent_web/live/channel_live.ex
decisions:
  - Dropdown renders above input (not below) for better visibility
  - Max 5 items visible before scrolling (220px height)
  - Broadcast targets appear first, then users, then groups
  - User filtering uses prefix matching first, then contains matching
  - ARIA attributes added for screen reader accessibility
metrics:
  duration_minutes: 3
  tasks_completed: 2
  tasks_total: 2
  completed_at: 2026-02-26
---

# Phase 01 Plan 01: Mention Autocomplete Backend & UI Summary

**One-liner:** Server-side mention filtering with Flowbite dropdown showing @everyone/@here, channel members, and groups

## Overview

Added autocomplete state management to ChannelLive and created the MentionAutocomplete dropdown component. The backend handles filtering of three target types (broadcast, user, group) with intelligent ranking. The UI component renders above the message input with Flowbite dark theme styling and full ARIA accessibility support.

## Implementation Details

### ChannelLive State Management

Added four autocomplete assigns to `mount/3`:
- `autocomplete_open` — controls dropdown visibility
- `autocomplete_query` — current filter text after @
- `autocomplete_results` — filtered list of mention targets
- `autocomplete_index` — currently highlighted item (for keyboard navigation)

### Event Handlers

Implemented four autocomplete event handlers:

1. **`autocomplete_open`** — Receives query string, calls `filter_mention_targets/2`, opens dropdown with results
2. **`autocomplete_close`** — Resets all autocomplete state
3. **`autocomplete_navigate`** — Handles up/down arrow keys, updates selected index with bounds checking
4. **`autocomplete_select`** — Formats selected mention, pushes client event, closes dropdown

### Filtering Logic (`filter_mention_targets/2`)

Fetches three data sources:
- Channel members via `Cromulent.Channels.list_members/1`
- Groups via `Cromulent.Groups.list_groups/0`
- Broadcast targets (@everyone, @here) as static data

**Filtering rules:**
- Broadcast targets: shown if query empty OR token starts with query
- Users: username starts with OR contains query (case-insensitive)
- Groups: slug starts with OR name contains query

**Ranking:**
- Users sorted by: exact match > prefix match > contains match
- Results ordered: broadcasts first, then users, then groups

### MentionAutocomplete Component

Created new function component with Flowbite styling:

**Visual design:**
- Positioned absolutely above input with `bottom-full` (per user decision)
- Max height 220px (~5 items) with overflow scroll
- Dark theme: gray-800 background, gray-600 border
- Selected item: gray-700 background highlight
- Hover state: gray-700/50 semi-transparent

**Item rendering:**

*User items:*
- Avatar circle (first letter of username, indigo-600 background)
- Display name in white
- Dimmed @username in gray-400

*Broadcast items:*
- @ symbol in indigo circle
- Label (@everyone/@here) in indigo-400 bold
- Description text in gray-400

*Group items:*
- Group icon (people SVG) in colored circle (uses group.color or green-600 fallback)
- @slug in green-400 bold
- Group name in gray-400

**Accessibility:**
- Listbox has `role="listbox"` and `aria-label="Mention suggestions"`
- Each option has `role="option"`, unique ID, and `aria-selected`
- Input has `role="combobox"`, `aria-autocomplete="list"`, `aria-controls="mention-listbox"`, `aria-expanded`
- Follows WAI-ARIA combobox pattern

### Template Changes

- Wrapped message input area in `<div id="mention-hook" phx-hook="MentionAutocomplete">`
- Added `data-selected-index` attribute for JS Hook to read
- Made input container `relative` for absolute positioning of dropdown
- Rendered `<.mention_autocomplete>` component above form

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

- [x] Code compiles successfully (pre-existing warnings documented in deferred-items.md)
- [x] MentionAutocomplete component renders conditionally based on `autocomplete_open`
- [x] All three item types (user, broadcast, group) have distinct visual styling
- [x] ARIA attributes correctly set on listbox, options, and input
- [x] Event handlers implemented for all autocomplete interactions
- [x] Filtering logic returns broadcast/user/group results with proper ranking

## Known Issues

Pre-existing compilation warnings (out of scope):
- Unused alias Repo in channel_live.ex
- Various unused variables in unrelated files
- Ungrouped function clauses in user_auth.ex and join_channel_modal.ex

These are documented in `.planning/phases/01-mention-autocomplete/deferred-items.md` for future cleanup.

## Next Steps

Plan 02 will implement the JavaScript Hook (`MentionAutocomplete`) that:
- Detects @ character and extracts query
- Sends autocomplete_open events to backend
- Handles keyboard navigation (arrow keys, enter, escape)
- Replaces @ trigger with selected mention text
- Integrates with form submission

## Files Modified

### Created
- `lib/cromulent_web/components/mention_autocomplete.ex` (88 lines)

### Modified
- `lib/cromulent_web/live/channel_live.ex` (+74 lines)
  - Added autocomplete state to mount
  - Added filter_mention_targets/2 and format_mention/1 helpers
  - Added 4 event handlers
  - Updated template with hook and component rendering
  - Added import for MentionAutocomplete component

## Commit

- **1ad36ab**: feat(01-01): add mention autocomplete backend and UI component

## Self-Check

**Status:** PASSED

Verified artifacts:
- ✓ File exists: lib/cromulent_web/components/mention_autocomplete.ex
- ✓ Commit exists: 1ad36ab
- ✓ Commit contains expected changes (2 files changed, 261 insertions, 28 deletions)
