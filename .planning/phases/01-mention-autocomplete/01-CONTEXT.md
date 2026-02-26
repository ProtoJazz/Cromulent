# Phase 1: Mention Autocomplete - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Type-ahead @mention UI with keyboard navigation. Users can @mention channel members, groups (@everyone, @here), and user groups from a filterable autocomplete dropdown in the message input. This phase covers the autocomplete interaction only — notification delivery triggered by mentions is Phase 2.

</domain>

<decisions>
## Implementation Decisions

### Popup appearance
- Autocomplete popup appears **above** the message input (Discord/Slack pattern)
- Each row shows: user avatar + display name + dimmed @username for disambiguation
- Maximum **5 visible items** before the list scrolls
- Built using the project's existing **Flowbite** UI component framework

### Workflow preference
- **Learning-first approach**: Implementation should be walked through step by step
- User wants to understand the "why" and "how" behind decisions, not just receive generated code
- Discuss implementation choices collaboratively as work progresses
- Prioritize understanding over speed of delivery

### Claude's Discretion
- Selection highlight styling (should fit existing Flowbite theme)
- Trigger behavior (when autocomplete activates, minimum characters)
- Filtering approach (fuzzy vs prefix match, result sorting/ranking)
- Mention rendering in messages (how inserted mentions display to author and readers)
- Visual distinction between users, groups, and broadcast targets (@everyone, @here)
- Keyboard navigation details beyond arrow keys + Enter

</decisions>

<specifics>
## Specific Ideas

- Should feel like Discord/Slack's mention autocomplete — popup above input, keyboard-driven
- Use existing Flowbite components rather than building custom dropdown UI

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-mention-autocomplete*
*Context gathered: 2026-02-26*
