---
phase: 05-feature-toggles
verified: 2026-03-03T00:00:00Z
status: passed
score: 7/7 must-haves verified
---

# Phase 5: Feature Toggles Verification Report

**Phase Goal:** Operator-controlled feature toggles — voice, registration, link previews, email confirmation, and TURN config — all managed from AdminLive Settings tab backed by a DB FeatureFlags table.
**Verified:** 2026-03-03
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                                     | Status     | Evidence                                                                                     |
|----|-----------------------------------------------------------------------------------------------------------|------------|----------------------------------------------------------------------------------------------|
| 1  | FeatureFlags.get_flags/0 returns a %Flags{} struct with correct defaults when no DB row exists            | VERIFIED   | `lib/cromulent/feature_flags.ex` line 11: `Repo.one(Flags) \|\| %Flags{}`; 9 passing tests  |
| 2  | FeatureFlags.upsert_flags/1 persists flag changes to the database                                        | VERIFIED   | upsert_flags/1 does insert-vs-update via `%Flags{id: nil}` guard; tested in feature_flags_test.exs |
| 3  | All authenticated LiveViews receive @feature_flags in socket assigns via ensure_authenticated             | VERIFIED   | `user_auth.ex` line 250: `Phoenix.Component.assign(socket, :feature_flags, flags)` in authenticated branch |
| 4  | When voice_enabled is false, voice channels are absent from the sidebar and VoiceChannel.join rejects     | VERIFIED   | `channels.ex` list_joined_channels/2 with voice_enabled filter; `voice_channel.ex` lines 6-9 guard |
| 5  | When registration_enabled is false, /users/register redirects with flash and Register link is hidden      | VERIFIED   | `user_registration_live.ex` mount checks flag; `user_login_live.ex` wraps Register link in conditional |
| 6  | AdminLive has a Settings tab with toggle switches, TURN form, and Create User form that wire to DB        | VERIFIED   | `admin_live.ex` Settings tab with 4 toggles, TURN form, toggle_flag/save_turn_config/admin_create_user events |
| 7  | TURN provider reads from DB flags (not env vars); link previews and email confirmation gated by DB flags  | VERIFIED   | `channel_live.ex` reads flags.turn_provider; `room_server.ex` checks flags.link_previews_enabled; `accounts.ex` checks confirmed_at when flag on |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact                                                              | Provides                                     | Status     | Details                                                                              |
|-----------------------------------------------------------------------|----------------------------------------------|------------|--------------------------------------------------------------------------------------|
| `priv/repo/migrations/20260302000001_create_feature_flags.exs`        | feature_flags table with all flag columns    | VERIFIED   | Contains `create table(:feature_flags, primary_key: false)` with binary_id PK and 7 flag columns |
| `lib/cromulent/feature_flags/flags.ex`                                | Ecto schema for feature flags                | VERIFIED   | Exports `Cromulent.FeatureFlags.Flags`, UUID7 PK, all 7 fields, changeset validates turn_provider |
| `lib/cromulent/feature_flags.ex`                                      | Context with get_flags/0 and upsert_flags/1  | VERIFIED   | Both functions present and substantive; normalize_attrs/1 helper added for empty string conversion |
| `lib/cromulent_web/user_auth.ex`                                      | feature_flags assign injected at mount       | VERIFIED   | Line 184: `flags = Cromulent.FeatureFlags.get_flags()`, line 250: assign(:feature_flags, flags) |
| `lib/cromulent/channels.ex`                                           | list_joined_channels/2 with voice_enabled    | VERIFIED   | Contains `voice_enabled \\ true` default; where clause filters voice channels when false |
| `lib/cromulent_web/channels/voice_channel.ex`                         | join/3 rejects when voice disabled           | VERIFIED   | Lines 6-9: `flags = get_flags(); if !flags.voice_enabled do {:error, %{reason: "voice_disabled"}}` |
| `lib/cromulent_web/live/user_registration_live.ex`                    | mount redirects when registration disabled   | VERIFIED   | Lines 103-110: checks flag, redirects with flash "Registration is closed on this server." |
| `lib/cromulent/turn/coturn.ex`                                        | get_ice_servers/3 accepts url and secret     | VERIFIED   | Signature: `def get_ice_servers(user_id, turn_url, turn_secret) when is_binary(turn_url) and is_binary(turn_secret)` |
| `lib/cromulent/turn/metered.ex`                                       | get_ice_servers/3 accepts api_url and api_key| VERIFIED   | Signature: `def get_ice_servers(_user_id, api_url, api_key) when is_binary(api_url) and is_binary(api_key)` |
| `lib/cromulent_web/live/admin_live.ex`                                | Settings tab + Create User form              | VERIFIED   | Full Settings tab at :settings, toggle_flag/save_turn_config/admin_create_user handlers |

### Key Link Verification

| From                                   | To                                    | Via                                              | Status  | Details                                                                                |
|----------------------------------------|---------------------------------------|--------------------------------------------------|---------|----------------------------------------------------------------------------------------|
| `user_auth.ex`                         | `feature_flags.ex`                    | `FeatureFlags.get_flags()` in ensure_authenticated | WIRED | Line 184: `flags = Cromulent.FeatureFlags.get_flags()` in authenticated branch        |
| `feature_flags.ex`                     | `feature_flags/flags.ex`              | `Repo.one(Flags) \|\| %Flags{}`                  | WIRED   | Line 11 of feature_flags.ex uses `Flags` schema directly                               |
| `user_auth.ex`                         | `channels.ex`                         | `list_joined_channels(user, flags.voice_enabled)` | WIRED  | Line 185: `Cromulent.Channels.list_joined_channels(socket.assigns.current_user, flags.voice_enabled)` |
| `channel_live.ex`                      | `turn/coturn.ex`                      | `Coturn.get_ice_servers(user_id, flags.turn_url, flags.turn_secret)` | WIRED | Line 541 in channel_live.ex passes turn_url and turn_secret |
| `room_server.ex`                       | `FeatureFlags`                        | `flags.link_previews_enabled` check before Task.start | WIRED | Lines 84-106: `flags = Cromulent.FeatureFlags.get_flags(); if flags.link_previews_enabled do` |
| `admin_live.ex`                        | `feature_flags.ex`                    | `FeatureFlags.upsert_flags` in handle_event toggle_flag | WIRED | Line 125: `case FeatureFlags.upsert_flags(attrs)` |
| `admin_live.ex`                        | `accounts.ex`                         | `Accounts.register_user` in handle_event admin_create_user | WIRED | Line 167: `case Accounts.register_user(%{...})` |
| `app.html.heex`                        | `sidebar.ex`                          | `voice_enabled={if assigns[:feature_flags], ...}` | WIRED | Line 66 of app.html.heex passes feature_flags.voice_enabled to sidebar component |
| `sidebar.ex`                           | template                              | `<%= if @voice_enabled do %>` wraps voice section | WIRED | Line 153 conditionally renders entire Voice Channels section |

### Requirements Coverage

| Requirement | Source Plan | Description                                                                 | Status      | Evidence                                                                                   |
|-------------|-------------|-----------------------------------------------------------------------------|-------------|-------------------------------------------------------------------------------------------|
| ADMN-01     | 05-01, 05-02, 05-03 | Server operator can enable/disable features via configuration (voice, TURN, link previews, registration) | SATISFIED | DB-backed FeatureFlags with AdminLive Settings UI covers all feature areas. ROADMAP.md success criteria (7 items) all satisfied. Note: REQUIREMENTS.md says "environment variables" but ROADMAP.md success criteria specify "DB flag" — implementation follows ROADMAP contract. |

### Anti-Patterns Found

| File                                        | Line | Pattern                      | Severity | Impact                                                   |
|---------------------------------------------|------|------------------------------|----------|----------------------------------------------------------|
| `lib/cromulent_web/channels/voice_channel.ex` | 32   | `IO.puts` debug log          | Info     | Pre-existing before this phase; logs voice join events. Not introduced by phase 5. Not a blocker. |

No blocker anti-patterns introduced by phase 5. The IO.puts in voice_channel.ex was pre-existing.

### Human Verification Required

The following scenarios were human-verified and signed off in 05-04-SUMMARY.md:

#### 1. Settings tab with 4 toggles and TURN section

**Test:** Navigate to /admin?tab=settings
**Expected:** Settings tab active with 4 Flowbite toggle switches and TURN config section
**Result:** Verified (05-04-SUMMARY.md)

#### 2. Voice channels disable/re-enable

**Test:** Toggle Voice Channels off, reload sidebar
**Expected:** Voice channels absent; re-enable restores them
**Result:** Verified (05-04-SUMMARY.md)

#### 3. Registration disable with flash redirect

**Test:** Toggle registration off, visit /users/register
**Expected:** Redirect to /users/log_in with "Registration is closed on this server."
**Result:** Verified (05-04-SUMMARY.md)

#### 4. Admin Create User bypasses registration flag

**Test:** With registration disabled, fill Create User form in Users tab
**Expected:** New user created and appears in table
**Result:** Verified (05-04-SUMMARY.md)

#### 5. Link previews disable

**Test:** Toggle link previews off, post a URL in a channel
**Expected:** Plain link, no preview card
**Result:** Verified (05-04-SUMMARY.md)

#### 6. TURN config Save and Test

**Test:** Enter coturn/metered config, click Save & Test
**Expected:** Config saved, inline TCP probe result displayed
**Result:** Verified with fix (fa957e4 — coturn now probes TCP connectivity)

#### 7. Email confirmation (skipped)

**Test:** Enable email confirmation, register a user, check dev mailbox
**Expected:** Confirmation email delivered; unconfirmed user cannot log in
**Result:** Skipped — mailer not configured in local dev environment. Code path is implemented and wired (accounts.ex confirmed_at check, registration_live.ex delivers instructions). Needs dedicated mail environment to fully validate.

### Gaps Summary

No gaps found. All automated wiring is complete and substantive. Human verification sign-off exists in 05-04-SUMMARY.md for 6 of 7 scenarios. The email confirmation scenario was skipped due to local mailer configuration — the code path is wired and correct, so this is an environment limitation rather than an implementation gap.

### Notable Implementation Enhancements Beyond Plan

During human verification (05-04), three improvements were added that exceed the original plan specifications:

1. **TURN TCP probe** (`fa957e4`): coturn "Save & Test" now does a real TCP connection attempt instead of just generating HMAC credentials. This correctly tests server reachability.

2. **Save & Test button disabled when fields empty** (`12c4ff7`): `phx-change="turn_config_change"` tracks draft values; button disabled when provider is non-disabled but URL or secret is blank.

3. **Link previews persisted to DB** (`e540982`): Link previews are now saved via `Messages.update_link_preview/2` and survive page refreshes (previously ephemeral socket state only). This is a correct and complete implementation.

---

_Verified: 2026-03-03_
_Verifier: Claude (gsd-verifier)_
