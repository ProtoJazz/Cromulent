# Phase 1: Mention Autocomplete - Research

**Researched:** 2026-02-26
**Domain:** Phoenix LiveView autocomplete UI with keyboard navigation
**Confidence:** HIGH

## Summary

Phase 1 implements @mention autocomplete in the message input, allowing users to type @ and see a filterable dropdown of channel members, groups (@everyone, @here), and user groups. The implementation requires coordinating Phoenix LiveView server-side state management with client-side JavaScript for keyboard navigation and cursor position detection.

The existing codebase already has the foundation: `MentionParser` handles backend mention parsing, `message_mentions` table stores mention data, and the message flow supports mention detection. This phase adds the frontend autocomplete UI layer on top of that infrastructure.

**Primary recommendation:** Use a Phoenix LiveView + JavaScript Hook hybrid approach. LiveView manages filtering and data fetching, while a lightweight JS Hook handles keyboard navigation, cursor position detection for @ trigger, and ARIA accessibility attributes. This avoids the "updated() lifecycle fighting DOM focus" pitfall common in pure-LiveView autocomplete.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Autocomplete popup appears **above** the message input (Discord/Slack pattern)
- Each row shows: user avatar + display name + dimmed @username for disambiguation
- Maximum **5 visible items** before the list scrolls
- Built using the project's existing **Flowbite** UI component framework
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MENT-01 | User can type @ in message input and see a filterable dropdown of channel members | **Standard Stack**: LiveView `phx-keydown` + JS Hook for @ detection. **Pattern**: Cursor position detection via `selectionStart`, filter channel members from server state |
| MENT-02 | User can navigate autocomplete with keyboard (up/down/enter/escape) | **Architecture Pattern**: JS Hook manages keyboard events, LiveView tracks selection index. **ARIA**: `aria-activedescendant` for virtual focus, standard combobox pattern |
| MENT-03 | @everyone and @here mentions display correctly in autocomplete alongside users | **Pattern**: Backend already supports broadcast mention types via `MentionParser`. UI groups items by type (broadcast targets at top, users below) |
| MENT-04 | @group mentions display correctly in autocomplete alongside users | **Pattern**: Backend already supports groups via `Groups.groups_by_slug()`. UI shows groups with distinct icon/styling between users and broadcast targets |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | 1.0.0 | Server-side UI state | Already in project, handles filtering/data without full page reloads |
| Phoenix LiveView Hooks | Built-in | Client-side JS integration | Standard LiveView pattern for DOM manipulation and keyboard events |
| Flowbite | Latest | UI components | Project requirement — existing Tailwind-based component library |
| ExUnit | Built-in | Testing framework | Phoenix default, already configured in project |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Floki | 0.30.0+ | HTML parsing in tests | Already in project for LiveView testing (`Phoenix.LiveViewTest`) |
| String module | Built-in Elixir | Text filtering | Use `String.starts_with?` for simple prefix matching, `String.contains?` for broader matches |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| LiveView Hooks | Alpine.js | Alpine reduces server round-trips but adds 15KB dependency. Hooks sufficient for keyboard nav + cursor detection |
| Prefix matching | Fuzzy search (Akin/FuzzyCompare) | Fuzzy search better for typos but adds complexity. Start simple with prefix, add fuzzy later if needed |
| Custom autocomplete | liveview_autocomplete library | Library requires Alpine.js dependency. Custom implementation gives full control and avoids extra deps |

**Installation:**
```bash
# No additional packages needed — using existing stack
# If fuzzy search needed later:
# mix deps: {:akin, "~> 0.2"}
```

## Architecture Patterns

### Recommended Project Structure
```
lib/cromulent_web/live/
├── channel_live.ex           # Add autocomplete state + event handlers
lib/cromulent_web/components/
├── mention_autocomplete.ex   # New: Autocomplete dropdown component
assets/js/
├── app.js                    # Add MentionAutocomplete hook
├── hooks/                    # New directory
    └── mention_autocomplete.js  # Cursor position + keyboard nav
test/cromulent_web/live/
├── channel_live_test.exs     # Add autocomplete interaction tests
```

### Pattern 1: LiveView + Hook Hybrid (RECOMMENDED)

**What:** LiveView manages autocomplete state (open/closed, filtered results, selected index), while JS Hook handles keyboard events, cursor position detection, and DOM manipulation for accessibility.

**When to use:** Autocomplete with keyboard navigation — avoids "updated() lifecycle erasing DOM state" pitfall.

**LiveView responsibilities:**
- Detect @ character via `phx-keydown` event
- Filter channel members/groups based on query string
- Track selected index (arrow key navigation updates this)
- Close autocomplete on selection/escape

**JS Hook responsibilities:**
- Detect cursor position to extract text after @
- Send keydown events to LiveView (arrows, enter, escape)
- Update `aria-activedescendant` for screen readers
- Scroll selected item into view

**Example LiveView Event Handler:**
```elixir
# Source: Inferred from FullstackPhoenix tutorial pattern
def handle_event("autocomplete_filter", %{"query" => query}, socket) do
  results = filter_mention_targets(socket.assigns.channel, query)
  {:noreply, assign(socket, autocomplete_results: results, autocomplete_query: query)}
end

def handle_event("autocomplete_navigate", %{"direction" => "down"}, socket) do
  max_index = length(socket.assigns.autocomplete_results) - 1
  new_index = min(socket.assigns.autocomplete_index + 1, max_index)
  {:noreply, assign(socket, autocomplete_index: new_index)}
end
```

**Example JS Hook Structure:**
```javascript
// Pattern from: https://aurmartin.fr/posts/phoenix-liveview-select/
Hooks.MentionAutocomplete = {
  mounted() {
    this.input = this.el.querySelector('input[name="body"]')
    this.input.addEventListener('keydown', (e) => this.handleKeydown(e))
    this.input.addEventListener('input', (e) => this.handleInput(e))
  },

  handleInput(e) {
    const cursorPos = this.input.selectionStart
    const textBeforeCursor = this.input.value.slice(0, cursorPos)
    const match = textBeforeCursor.match(/@(\w*)$/)
    if (match) {
      this.pushEvent("autocomplete_filter", { query: match[1] })
    }
  },

  updated() {
    // Sync aria-activedescendant with server-selected index
    const selectedId = this.el.dataset.selectedId
    if (selectedId) {
      this.input.setAttribute('aria-activedescendant', selectedId)
    }
  }
}
```

### Pattern 2: Cursor Position Detection

**What:** Detect @ character and extract query string from input cursor position.

**How:** Use `input.selectionStart` to get caret position, slice text before cursor, regex match `/@(\w*)$/` to find active mention.

**Example:**
```javascript
// Source: https://ourcodeworld.com/articles/read/282/how-to-get-the-current-cursor-position-and-selection-within-a-text-input-or-textarea-in-javascript
const cursorPos = input.selectionStart  // Zero-based index
const textBefore = input.value.slice(0, cursorPos)
const mentionMatch = textBefore.match(/@(\w*)$/)  // Capture word after @

if (mentionMatch) {
  const query = mentionMatch[1]  // Empty string if just "@"
  // Trigger autocomplete with query
}
```

### Pattern 3: ARIA Combobox Accessibility

**What:** Follow WAI-ARIA combobox pattern for screen reader support.

**Required attributes:**
- Input: `role="combobox"`, `aria-autocomplete="list"`, `aria-controls="mention-listbox"`, `aria-expanded="true/false"`, `aria-activedescendant="option-{index}"`
- Popup: `role="listbox"`, `aria-label="Mention suggestions"`
- Options: `role="option"`, `id="option-{index}"`, `aria-selected="true/false"`

**Example:**
```heex
<%!-- Source: https://www.w3.org/WAI/ARIA/apg/patterns/combobox/ --%>
<input
  role="combobox"
  aria-autocomplete="list"
  aria-controls="mention-listbox"
  aria-expanded={@autocomplete_open}
  aria-activedescendant={"option-#{@autocomplete_index}"}
/>

<ul role="listbox" id="mention-listbox" aria-label="Mention suggestions">
  <li :for={{item, idx} <- Enum.with_index(@autocomplete_results)}
      role="option"
      id={"option-#{idx}"}
      aria-selected={idx == @autocomplete_index}>
    <%= render_mention_item(item) %>
  </li>
</ul>
```

### Pattern 4: Filtering and Ranking

**What:** Filter channel members, groups, and broadcast targets based on query.

**Ranking order:**
1. Exact username match (highest priority)
2. Username starts with query (prefix match)
3. Display name starts with query
4. Display name contains query (lowest priority)
5. Broadcast targets (@everyone, @here) always appear at top if query is empty or matches

**Example:**
```elixir
defp filter_mention_targets(channel, query) do
  members = Cromulent.Channels.list_members(channel)
  groups = Cromulent.Groups.list_groups()

  query_lower = String.downcase(query)

  # Broadcast targets
  broadcast = if query == "" or String.starts_with?("everyone", query_lower) or String.starts_with?("here", query_lower) do
    [%{type: :broadcast, label: "@everyone"}, %{type: :broadcast, label: "@here"}]
  else
    []
  end

  # Filter users
  users = members
    |> Enum.filter(fn user ->
      String.starts_with?(String.downcase(user.username), query_lower) or
      String.contains?(String.downcase(user.display_name || user.username), query_lower)
    end)
    |> Enum.sort_by(fn user ->
      cond do
        String.downcase(user.username) == query_lower -> 0  # Exact match
        String.starts_with?(String.downcase(user.username), query_lower) -> 1  # Prefix
        String.starts_with?(String.downcase(user.display_name || ""), query_lower) -> 2
        true -> 3  # Contains
      end
    end)
    |> Enum.map(&%{type: :user, user: &1})

  # Filter groups (similar logic)
  groups_filtered = # ... similar filtering

  broadcast ++ users ++ groups_filtered
end
```

### Anti-Patterns to Avoid

- **Managing input value in LiveView state**: Phoenix LiveView docs state "the JavaScript client is always the source of truth for current input values." Don't track input text in `socket.assigns` — only track autocomplete-specific state (open/closed, results, selected index). Source: [Form bindings — Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/form-bindings.html)

- **Over-debouncing autocomplete filter**: Don't use 500ms+ debounce like search boxes. Autocomplete should feel instant — use 100-150ms or phx-throttle to avoid lag while still rate-limiting. Source: [Bindings — Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/bindings.html)

- **Moving DOM focus into popup**: Keep focus on input, use `aria-activedescendant` for virtual focus. Moving real focus breaks typing flow. Source: [Combobox Pattern | APG | WAI](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/)

- **Not handling updated() lifecycle in Hook**: When LiveView re-renders, event listeners disappear. Hook's `updated()` must re-sync ARIA attributes. Source: [Interactive Select component using Phoenix LiveView](https://aurmartin.fr/posts/phoenix-liveview-select/)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fuzzy string matching | Custom Levenshtein distance | `akin` or `fuzzy_compare` Elixir library (if needed) | Edge cases: Unicode normalization, multi-byte characters, performance tuning. Libraries handle this. |
| Autocomplete positioning | Custom CSS calculations for "above input" placement | CSS `bottom: 100%` with `position: absolute` on parent `position: relative` | Browser handles viewport overflow, scroll offsets automatically |
| Keyboard navigation state | Manual index tracking with wraparound logic | Use `rem(index + offset, length)` for circular nav OR clamp with `max(0, min(index, max_index))` | Off-by-one errors are common, use tested patterns |
| ARIA attribute management | Custom accessibility implementation | Follow WAI-ARIA combobox pattern exactly | Screen reader compatibility requires precise attribute choreography, well-documented pattern exists |

**Key insight:** Autocomplete UIs have 20+ years of accessibility research (WAI-ARIA patterns). Cursor position, keyboard navigation, and ARIA attributes have subtle bugs if hand-rolled. Use established patterns and libraries for non-trivial string matching.

## Common Pitfalls

### Pitfall 1: Autocomplete Fighting Form Submit
**What goes wrong:** User presses Enter to select autocomplete item, but form submits instead, sending incomplete message.

**Why it happens:** Default browser behavior — Enter in text input triggers form submit.

**How to avoid:** In JS Hook, call `event.preventDefault()` when autocomplete is open and Enter is pressed. Only close autocomplete and insert mention, don't submit form.

**Warning signs:** Users complain messages send prematurely when selecting mentions.

**Code example:**
```javascript
handleKeydown(e) {
  if (this.autocompleteOpen && e.key === 'Enter') {
    e.preventDefault()  // CRITICAL: Don't submit form
    this.selectCurrentItem()
  }
}
```

### Pitfall 2: Cursor Position Lost After Mention Insert
**What goes wrong:** After inserting "@username" mention, cursor jumps to end of input instead of staying after the inserted text.

**Why it happens:** Replacing input value resets cursor to end by default.

**How to avoid:** After inserting mention, manually set `input.selectionStart` and `input.selectionEnd` to desired position.

**Warning signs:** User types "Hello @john how are you" → selects "@john" → cursor jumps to end → user has to arrow-left back to continue typing.

**Code example:**
```javascript
insertMention(username) {
  const cursorPos = this.input.selectionStart
  const before = this.input.value.slice(0, this.mentionStartPos)
  const after = this.input.value.slice(cursorPos)
  const mention = `@${username} `

  this.input.value = before + mention + after

  // CRITICAL: Set cursor after mention
  const newPos = this.mentionStartPos + mention.length
  this.input.selectionStart = newPos
  this.input.selectionEnd = newPos
}
```

### Pitfall 3: Autocomplete Doesn't Close on Click Outside
**What goes wrong:** User clicks outside input/dropdown, but autocomplete stays open, blocking UI.

**Why it happens:** No click-outside listener registered.

**How to avoid:** Add `phx-click-away="close_autocomplete"` on autocomplete container, or add JS click-outside listener in Hook.

**Warning signs:** QA finds autocomplete "stuck open" in certain scenarios.

**Code example (LiveView approach):**
```heex
<div phx-click-away="close_autocomplete">
  <!-- Autocomplete dropdown -->
</div>
```

### Pitfall 4: Debounce Too Aggressive, UI Feels Sluggish
**What goes wrong:** User types "@jo" but dropdown doesn't appear for 500ms, feels laggy.

**Why it happens:** Using search-box debounce value (500ms+) for autocomplete.

**How to avoid:** Use 100-150ms debounce OR `phx-throttle="100"` for autocomplete. It should feel instant while still rate-limiting server calls.

**Warning signs:** User feedback "autocomplete is slow" when network is fine.

### Pitfall 5: Re-render Closes Autocomplete Unexpectedly
**What goes wrong:** User types "@joh" → autocomplete opens → new message arrives in channel → LiveView re-renders → autocomplete closes.

**Why it happens:** Autocomplete open state not preserved across LiveView updates, or conditional rendering removes autocomplete DOM entirely.

**How to avoid:**
1. Keep autocomplete state in socket.assigns, render dropdown conditionally but always include container
2. Use `temporary_assigns` for message list to avoid full re-render on new messages
3. In Hook `updated()`, restore UI state after LiveView patch

**Warning signs:** Autocomplete "flickers" or closes when unrelated LiveView updates happen.

## Code Examples

Verified patterns from research and existing codebase:

### Detect @ Trigger in Input
```javascript
// Source: Inferred from https://ourcodeworld.com/articles/read/282/how-to-get-the-current-cursor-position
handleInput(e) {
  const input = e.target
  const cursorPos = input.selectionStart
  const textBefore = input.value.slice(0, cursorPos)

  // Match @ followed by word characters (including empty string)
  const match = textBefore.match(/@(\w*)$/)

  if (match) {
    const query = match[1]  // Empty if just "@"
    const mentionStart = cursorPos - match[0].length

    this.pushEvent("autocomplete_open", {
      query: query,
      position: mentionStart
    })
  } else if (this.autocompleteOpen) {
    this.pushEvent("autocomplete_close", {})
  }
}
```

### LiveView Autocomplete State Management
```elixir
# In ChannelLive module
def mount(_params, _session, socket) do
  {:ok, assign(socket,
    # ... existing assigns
    autocomplete_open: false,
    autocomplete_query: "",
    autocomplete_results: [],
    autocomplete_index: 0
  )}
end

def handle_event("autocomplete_open", %{"query" => query}, socket) do
  results = filter_mention_targets(socket.assigns.channel, query)

  {:noreply, assign(socket,
    autocomplete_open: true,
    autocomplete_query: query,
    autocomplete_results: results,
    autocomplete_index: 0  # Reset selection
  )}
end

def handle_event("autocomplete_select", %{"index" => index}, socket) do
  result = Enum.at(socket.assigns.autocomplete_results, index)

  # Send selected mention back to JS to insert into input
  {:noreply, socket
    |> assign(autocomplete_open: false)
    |> push_event("mention_selected", %{mention: format_mention(result)})
  }
end
```

### Flowbite-Styled Dropdown Component
```heex
<%!-- New component: lib/cromulent_web/components/mention_autocomplete.ex --%>
<div :if={@open}
     class="absolute bottom-full left-0 mb-2 w-64 max-h-60 overflow-y-auto bg-gray-800 border border-gray-700 rounded-lg shadow-lg"
     role="listbox"
     id="mention-listbox"
     aria-label="Mention suggestions">

  <ul class="py-1">
    <li :for={{item, idx} <- Enum.with_index(@results)}
        role="option"
        id={"mention-option-#{idx}"}
        aria-selected={idx == @selected_index}
        phx-click="autocomplete_select"
        phx-value-index={idx}
        class={[
          "px-3 py-2 flex items-center gap-2 cursor-pointer",
          if(idx == @selected_index, do: "bg-gray-700", else: "hover:bg-gray-750")
        ]}>

      <%= case item.type do %>
        <% :user -> %>
          <img src={avatar_url(item.user)} class="w-6 h-6 rounded-full" alt="" />
          <span class="text-white"><%= item.user.display_name || item.user.username %></span>
          <span class="text-gray-400 text-sm">@<%= item.user.username %></span>

        <% :broadcast -> %>
          <span class="text-indigo-400 font-semibold"><%= item.label %></span>

        <% :group -> %>
          <span class="text-green-400">@<%= item.group.slug %></span>
          <span class="text-gray-400 text-sm"><%= item.group.name %></span>
      <% end %>
    </li>
  </ul>
</div>
```

### Keyboard Navigation in Hook
```javascript
// Source: Pattern from https://aurmartin.fr/posts/phoenix-liveview-select/
handleKeydown(e) {
  if (!this.autocompleteOpen) return

  switch(e.key) {
    case 'ArrowDown':
      e.preventDefault()
      this.pushEvent("autocomplete_navigate", { direction: "down" })
      break

    case 'ArrowUp':
      e.preventDefault()
      this.pushEvent("autocomplete_navigate", { direction: "up" })
      break

    case 'Enter':
      e.preventDefault()  // Don't submit form!
      this.pushEvent("autocomplete_select", {
        index: parseInt(this.el.dataset.selectedIndex)
      })
      break

    case 'Escape':
      e.preventDefault()
      this.pushEvent("autocomplete_close", {})
      break
  }
}

updated() {
  // Sync ARIA attribute after LiveView update
  const selectedIndex = this.el.dataset.selectedIndex
  if (selectedIndex !== undefined) {
    this.input.setAttribute('aria-activedescendant', `mention-option-${selectedIndex}`)
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Alpine.js for autocomplete | Phoenix LiveView Hooks | LiveView 0.15+ (2021) | Hooks provide tighter integration, no 15KB dependency |
| Manual ARIA implementation | WAI-ARIA 1.2 combobox pattern | ARIA 1.2 (2020) | Standardized `aria-activedescendant` for virtual focus |
| DOM focus in popup | Virtual focus with aria-activedescendant | ARIA 1.1+ | Keeps focus on input, better UX and browser compatibility |
| phx-keydown for all keys | phx-throttle for rapid events | LiveView 0.15+ (2021) | Better performance for arrow keys |

**Deprecated/outdated:**
- **Alpine.js-based autocomplete**: Many tutorials (2020-2022) use Alpine.js. Current best practice is LiveView Hooks for better Phoenix integration.
- **Inline autocomplete (aria-autocomplete="inline")**: Rarely used in modern chat apps. List-based autocomplete is standard for mentions.

## Open Questions

1. **Should we pre-fetch channel members on mount or lazy-load on @ trigger?**
   - What we know: Channel members already loaded in `ChannelLive.mount/3` for message display
   - What's unclear: Performance impact if channel has 1000+ members (unlikely for self-hosted use case)
   - Recommendation: Use existing `list_members(channel)` call, already in memory. Only optimize if user reports >500 member channels.

2. **Fuzzy matching: Worth the complexity for v1?**
   - What we know: Prefix matching (`String.starts_with?`) is fast and predictable. Fuzzy matching libraries (Akin, FuzzyCompare) add complexity.
   - What's unclear: User expectation — do they expect "@jhn" to match "@john"?
   - Recommendation: Start with prefix + contains matching. Add fuzzy search in Phase 2 if user feedback requests it. YAGNI applies.

3. **How to visually distinguish group mentions from user mentions?**
   - What we know: Backend supports groups, but no design spec for visual treatment
   - What's unclear: Icon? Color? Prefix label?
   - Recommendation: Use color coding (users: white text, groups: green text, broadcast: indigo text) + icon (user avatar, group icon, broadcast icon). Defer to user feedback during implementation walkthrough.

## Sources

### Primary (HIGH confidence)
- [WAI-ARIA Combobox Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/) - ARIA attributes and keyboard requirements
- [Editable Combobox Example](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-autocomplete-list/) - Reference implementation
- [Phoenix LiveView Form Bindings](https://hexdocs.pm/phoenix_live_view/form-bindings.html) - Input state management patterns
- [Phoenix LiveView Bindings](https://hexdocs.pm/phoenix_live_view/bindings.html) - phx-debounce, phx-throttle usage
- Existing codebase: `lib/cromulent/messages/mention_parser.ex`, `lib/cromulent_web/live/channel_live.ex`

### Secondary (MEDIUM confidence)
- [FullstackPhoenix: Typeahead with LiveView and Tailwind](https://fullstackphoenix.com/tutorials/typeahead-with-liveview-and-tailwind) - LiveView autocomplete pattern
- [Aurélien Martin: Interactive Select component](https://aurmartin.fr/posts/phoenix-liveview-select/) - Hook lifecycle management
- [Our Code World: Cursor Position in JavaScript](https://ourcodeworld.com/articles/read/282/how-to-get-the-current-cursor-position-and-selection-within-a-text-input-or-textarea-in-javascript) - selectionStart/End API
- [Flowbite Dropdown Accessibility](https://github.com/themesberg/flowbite-react/pull/840) - Keyboard navigation improvements

### Tertiary (LOW confidence)
- [Algolia: Rich text box with mentions](https://www.algolia.com/doc/ui-libraries/autocomplete/solutions/rich-text-box-with-mentions-and-hashtags) - Commercial implementation (informational only)
- [Fuzzy Search Algorithms](https://github.com/jeancroy/FuzzySearch) - For future fuzzy matching consideration

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Phoenix LiveView + Hooks is proven pattern, already in project
- Architecture: HIGH - WAI-ARIA combobox is W3C standard, LiveView Hook hybrid validated by multiple sources
- Pitfalls: MEDIUM-HIGH - Form submit prevention and cursor position management are known issues from tutorials, but specific to implementation details

**Research date:** 2026-02-26
**Valid until:** 2026-04-26 (60 days — Phoenix LiveView and ARIA patterns are stable)
