# Phase 5: Feature Toggles - Context

**Gathered:** 2026-03-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Server operators can enable/disable features via DB-backed feature flags editable from the admin panel. No new end-user features — existing features (voice, registration, link previews, TURN, email confirmation) get operator-controlled on/off switches. All flags stored in the database; admin panel is the control surface.

</domain>

<decisions>
## Implementation Decisions

### Flag storage
- All feature flags stored in the **database** (not env vars) — one flags/config table
- DB is authoritative; overrides any legacy env var values
- Default state on fresh install (no DB rows): voice on, registration on, link previews on, email confirmation off, TURN disabled (STUN-only)
- Flag changes take effect on **next page load** — no live PubSub propagation to active sessions

### Voice disable
- When disabled: voice channels **hidden completely** from the sidebar
- Enforced at the **query level** — channel list query excludes type=voice channels when flag is off
- **Backend also enforces**: VoiceChannel rejects join attempts server-side when voice is disabled
- VoiceBar component stays as-is (naturally disappears since no voice channels are accessible)

### Registration disable
- `/users/register` **redirects to the login page** with flash: "Registration is closed on this server"
- The "Register" link on the login page is **hidden** when registration is disabled
- The API registration endpoint (`/api/auth/register` or equivalent) is also **blocked** when disabled
- **Admin panel bypasses the flag** — admins can always create user accounts
- A **Create User form** must be added to AdminLive as part of this phase (required for admin bypass to work)

### Email confirmation toggle
- New toggle: operator can **require email confirmation** for new accounts
- **Off by default** — preserves current behavior (no confirmation required, users log in immediately)
- When enabled: wires back the commented-out confirmation email delivery in `user_registration_live.ex` (line 117-121)
- When enabled: `get_user_by_email_and_password` must also check `confirmed_at` before allowing login

### Link preview disable
- When disabled: URLs render as **plain clickable links** (still autolinked via Phase 4 markdown pipeline)
- No preview card fetch or rendering occurs
- Claude's discretion on implementation approach

### TURN configuration
- Full TURN config stored in DB: **provider** (coturn / metered / disabled), **server URL**, **secret or API key**
- Admin form: provider dropdown + URL field + secret/API key field
- On save: **test connection** — attempt TURN credential fetch and display success/failure to admin
- "Disabled" provider option = force STUN-only (overrides any legacy TURN_PROVIDER env var)

### Admin panel - Settings tab
- New **"Settings" tab** added alongside the existing Users and Channels tabs in AdminLive
- Boolean flags (voice, registration, link previews, email confirmation) use **Flowbite toggle switches** — instant save, no confirmation dialog
- TURN config section below the toggles — form with provider dropdown + URL + secret fields + Save & Test button
- All changes save immediately on toggle/submit; no separate "save all" button for toggles

### Admin user creation
- Add **Create User form** to the Users tab in AdminLive (or as a modal from the users list)
- Minimum fields: email, username, password
- Creation bypasses the registration disabled flag — always available to admins

### Claude's Discretion
- DB schema design for the flags table (key-value vs named columns vs separate TURN config table)
- TURN connection test implementation details (what exactly to test and how to surface the result)
- Link preview disable implementation (where in the pipeline to gate the fetch)
- How to pass feature flag state to LiveView (assign at mount, module-level cache, etc.)

</decisions>

<specifics>
## Specific Ideas

- The existing `# XXX: Renable confirmation emails eventually` comment in `user_registration_live.ex:117` is the exact spot to wire the email confirmation toggle
- TURN admin UI should replace the current `System.get_env("TURN_PROVIDER")` inline read in `channel_live.ex:537` — DB becomes the source of truth

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AdminLive` (`lib/cromulent_web/live/admin_live.ex`): Existing users + channels tabs with tab-switching logic — add Settings tab following same pattern
- Flowbite toggle components: Already in the project (`assets/package.json`), use for boolean flag switches
- `TURN provider` modules from Phase 3: `Cromulent.TURN.*` — existing abstraction that DB-backed config should feed into
- `Accounts.deliver_user_confirmation_instructions/2`: Confirmation email delivery already implemented, just needs to be called conditionally
- `User.confirm_changeset/0` + `confirm_user/1`: Full confirmation flow already in `Cromulent.Accounts`

### Established Patterns
- `System.get_env` inline reads in `runtime.exs` — existing env var pattern (DB replaces this for feature flags)
- `Application.get_env(:cromulent, :dns_cluster_query)` — app config pattern used in `application.ex`
- `Application.compile_env(:cromulent, :dev_routes)` in router — compile-time flag pattern (runtime DB flags should NOT use this)
- `handle_event/3` + `assign/3` in LiveView for UI state updates
- Context modules as public API (`Cromulent.Accounts`, `Cromulent.Channels`) — a `Cromulent.FeatureFlags` context would follow this pattern

### Integration Points
- `channel_live.ex:537` — TURN_PROVIDER inline System.get_env read must be replaced with DB-backed flag read
- `user_registration_live.ex:117-121` — commented-out confirmation email delivery, wired when email confirmation toggle is enabled
- `accounts.ex:41-45` — `get_user_by_email_and_password/2` needs to check `confirmed_at` when email confirmation is required
- `VoiceChannel.join/3` — must check voice enabled flag and reject when disabled
- Channel list queries in `ChannelLive` — filter out voice channels at query level when voice is disabled
- Router (`router.ex`) — registration routes need flag check to redirect when disabled
- API auth controller — registration endpoint needs to respect the flag

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-feature-toggles*
*Context gathered: 2026-03-02*
