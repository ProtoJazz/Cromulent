---
plan: 05-04
phase: 05-feature-toggles
status: complete
verified_by: human
---

# Summary: Human Verification — Feature Toggle Scenarios

## What Was Verified

Human operator verified the complete feature toggle system end-to-end through the browser UI.

All scenarios approved with the following fixes applied during verification:

## Fixes Applied During Checkpoint

### 1. TURN "Save & Test" — coturn didn't actually test connectivity
- **Problem:** `Coturn.get_ice_servers/3` generates HMAC credentials locally — always succeeds regardless of server reachability.
- **Fix:** `test_turn_connection/1` now parses the TURN URL (strips `turn:`/`turns:` scheme, defaults port to 3478), then attempts a real TCP connection via `:gen_tcp.connect/4` with 5s timeout. Returns "Server unreachable at host:port" on failure.
- **Commit:** `fa957e4`

### 2. Save & Test button not disabled when fields empty
- **Problem:** Button was always enabled; saving coturn/metered with blank URL or secret produced confusing results.
- **Fix:** `phx-change="turn_config_change"` tracks draft form values in socket (`turn_draft_provider`, `turn_draft_url`, `turn_draft_secret`). Button is `disabled` when provider ≠ "disabled" and URL or secret is blank. Styled with `opacity-40 cursor-not-allowed`.
- **Commit:** `12c4ff7`

### 3. Link previews lost on page refresh
- **Problem:** Previews were ephemeral — fetched into socket state only, not persisted. On refresh, messages reload from DB without previews.
- **Fix:** Added migration `20260303080841_add_link_preview_to_messages.exs` with `:map` column. `room_server.ex` calls `Messages.update_link_preview/2` after a successful fetch. `list_messages` and `list_messages_before` atomize string keys returned by Postgres.
- **Commit:** `e540982`

### 4. Flash alerts restyled
- **Problem:** Default Phoenix top-right toast style inconsistent with Flowbite dark theme.
- **Fix:** `flash/1` component in `core_components.ex` restyled to fixed top-center banner (max-w-md, flex row with icon + message + dismiss X). Info: indigo-950/indigo-700 border. Error: red-950/red-700 border.
- **Commit:** `e540982`

## Verification Results

| Scenario | Result |
|---|---|
| Settings tab with 4 toggles + TURN section | ✓ |
| Voice channels disable/re-enable | ✓ |
| Registration disable → redirect with flash | ✓ |
| Admin Create User bypasses registration flag | ✓ |
| Link previews disable → plain links | ✓ |
| TURN config form Save & Test | ✓ (with fix) |
| Email confirmation (optional) | skipped — mailer not configured locally |

## Key Files

- `lib/cromulent_web/live/admin_live.ex` — Settings tab, TURN test, draft assigns
- `lib/cromulent/chat/room_server.ex` — persist preview on fetch
- `lib/cromulent/messages.ex` — `update_link_preview/2`, atomize keys on load
- `lib/cromulent/messages/message.ex` — `link_preview :map` field
- `priv/repo/migrations/20260303080841_add_link_preview_to_messages.exs`
- `lib/cromulent_web/components/core_components.ex` — flash component
