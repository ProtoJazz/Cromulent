---
phase: 05-feature-toggles
plan: 02
subsystem: auth, api
tags: [feature-flags, phoenix, live-view, ecto, channels, turn]

# Dependency graph
requires:
  - phase: 05-01
    provides: FeatureFlags context with get_flags/0, upsert_flags/1, and feature_flags assign in ensure_authenticated
provides:
  - Voice channel join rejection when voice_enabled=false
  - Registration page redirect when registration_enabled=false
  - Register link hidden on login page when registration_enabled=false
  - Confirmation email sent on registration when email_confirmation_required=true
  - Login blocked for unconfirmed users when email_confirmation_required=true
  - Link preview fetch skipped when link_previews_enabled=false
  - TURN config read from DB flags (coturn/metered accept url/secret params)
  - channels.ex list_joined_channels/2 excludes voice channels when voice_enabled=false
affects: [05-03, 05-04]

# Tech tracking
tech-stack:
  added: []
  patterns: [feature-flag enforcement at entry points, guard-at-top pattern for gate checks]

key-files:
  created:
    - test/cromulent/channels_test.exs
    - test/support/fixtures/accounts_fixtures.ex (updated)
  modified:
    - lib/cromulent/channels.ex
    - lib/cromulent_web/channels/voice_channel.ex
    - lib/cromulent_web/user_auth.ex
    - lib/cromulent_web/live/user_registration_live.ex
    - lib/cromulent_web/live/user_login_live.ex
    - lib/cromulent/accounts.ex
    - lib/cromulent/chat/room_server.ex
    - lib/cromulent/turn/coturn.ex
    - lib/cromulent/turn/metered.ex
    - lib/cromulent_web/live/channel_live.ex
    - lib/cromulent_web/components/sidebar.ex
    - lib/cromulent_web/components/layouts/app.html.heex

key-decisions:
  - "Voice gating at two levels: query-level (list_joined_channels) + join-level (VoiceChannel.join) for defense in depth"
  - "TURN config migrated from env vars to DB flags — coturn/metered now accept (user_id, url, secret) params"
  - "Registration disabled redirects to /users/log_in with put_flash :error"
  - "Email confirmation is opt-in per request at registration time — no retroactive blocking of already-confirmed users"
  - "accounts_fixtures.ex updated to include unique_username — fixed 101 pre-existing test failures"
  - "VoiceChannel.join checks flag first before channel lookup — fast-path rejection"

patterns-established:
  - "Gate pattern: call get_flags() at top of mount/join, guard before any work"
  - "TURN provider: channel_live.ex reads flags.turn_provider and passes url/secret to provider module"

requirements-completed: [ADMN-01]

# Metrics
duration: ~25min
completed: 2026-03-03
---

# Phase 05-02: Feature Flag Enforcement Points Summary

**All 5 feature areas gated by DB flags — voice join rejection, registration redirect, login Register link toggle, email confirmation, link preview skip, TURN read from DB**

## Performance

- **Duration:** ~25 min (partial manual implementation + completion)
- **Completed:** 2026-03-03
- **Tasks:** 3
- **Files modified:** 12

## Accomplishments
- Voice channels excluded from sidebar and join rejected with `{:error, %{reason: "voice_disabled"}}` when `voice_enabled=false`
- Registration page redirects to login with flash error when `registration_enabled=false`; Register link hidden on login page
- Email confirmation email sent on registration when `email_confirmation_required=true`; unconfirmed users blocked from login
- Link preview fetch skipped when `link_previews_enabled=false` (replaced `LINK_PREVIEWS` env var check)
- TURN provider reads `turn_provider/turn_url/turn_secret` from DB flags — no more `System.get_env("TURN_*")` in runtime paths

## Task Commits

1. **Task 1: Voice gating** - `0b7149b` (feat: Phase 5 - user manually implemented)
2. **Task 2: Registration gating and email confirmation** - `dba85cc` (feat)
3. **Task 3: Link preview gate and TURN refactor** - `0b7149b` + `dba85cc` (feat)

## Files Created/Modified
- `lib/cromulent/channels.ex` - `list_joined_channels/2` with `voice_enabled` param; excludes voice when false
- `lib/cromulent_web/channels/voice_channel.ex` - `join/3` returns `{:error, %{reason: "voice_disabled"}}` when flag off
- `lib/cromulent_web/user_auth.ex` - passes `flags.voice_enabled` to `list_joined_channels`
- `lib/cromulent_web/live/user_registration_live.ex` - mount redirects when disabled; sends confirmation email conditionally
- `lib/cromulent_web/live/user_login_live.ex` - loads flags in mount; wraps Register link in conditional
- `lib/cromulent/accounts.ex` - `get_user_by_email_and_password` checks `confirmed_at` when flag is on
- `lib/cromulent/chat/room_server.ex` - replaces `LINK_PREVIEWS` env var with `flags.link_previews_enabled`
- `lib/cromulent/turn/coturn.ex` - `get_ice_servers/3` accepts `(user_id, turn_url, turn_secret)`
- `lib/cromulent/turn/metered.ex` - `get_ice_servers/3` accepts `(user_id, api_url, api_key)`
- `lib/cromulent_web/live/channel_live.ex` - reads TURN config from DB flags instead of env vars
- `lib/cromulent_web/components/sidebar.ex` - `voice_enabled` attr; conditional voice channels section
- `test/support/fixtures/accounts_fixtures.ex` - added `unique_username/0`; includes username in `valid_user_attributes`

## Decisions Made
- Guard at top of join/mount before any DB lookups — fail fast
- Fixture fix (adding username) was necessary to unblock 101 pre-existing test failures from Phase 1 username requirement

## Deviations from Plan

### Implementation Split
**Plan executed in two commits:**
- `0b7149b` (user commit): voice gating, sidebar, TURN refactor, channel_live TURN fix
- `dba85cc` (agent commit): registration gating, login link toggle, email confirmation, link preview gate, fixture fix

No functional deviations from spec.

## Issues Encountered
- 116 pre-existing test failures due to `accounts_fixtures.ex` missing `username` field (added since Phase 1). Fixed in this plan.

## Next Phase Readiness
- All enforcement points active — operator can toggle flags via admin UI (05-03)
- 05-04 human verification checkpoint ready to run

---
*Phase: 05-feature-toggles*
*Completed: 2026-03-03*
