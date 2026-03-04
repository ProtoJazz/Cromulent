# Phase 5: Feature Toggles - Research

**Researched:** 2026-03-02
**Domain:** Elixir/Phoenix runtime configuration, Ecto schema design, LiveView on_mount patterns
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Flag storage
- All feature flags stored in the **database** (not env vars) — one flags/config table
- DB is authoritative; overrides any legacy env var values
- Default state on fresh install (no DB rows): voice on, registration on, link previews on, email confirmation off, TURN disabled (STUN-only)
- Flag changes take effect on **next page load** — no live PubSub propagation to active sessions

#### Voice disable
- When disabled: voice channels **hidden completely** from the sidebar
- Enforced at the **query level** — channel list query excludes type=voice channels when flag is off
- **Backend also enforces**: VoiceChannel rejects join attempts server-side when voice is disabled
- VoiceBar component stays as-is (naturally disappears since no voice channels are accessible)

#### Registration disable
- `/users/register` **redirects to the login page** with flash: "Registration is closed on this server"
- The "Register" link on the login page is **hidden** when registration is disabled
- The API registration endpoint (`/api/auth/register` or equivalent) is also **blocked** when disabled
- **Admin panel bypasses the flag** — admins can always create user accounts
- A **Create User form** must be added to AdminLive as part of this phase (required for admin bypass to work)

#### Email confirmation toggle
- New toggle: operator can **require email confirmation** for new accounts
- **Off by default** — preserves current behavior (no confirmation required, users log in immediately)
- When enabled: wires back the commented-out confirmation email delivery in `user_registration_live.ex` (line 117-121)
- When enabled: `get_user_by_email_and_password` must also check `confirmed_at` before allowing login

#### Link preview disable
- When disabled: URLs render as **plain clickable links** (still autolinked via Phase 4 markdown pipeline)
- No preview card fetch or rendering occurs
- Claude's discretion on implementation approach

#### TURN configuration
- Full TURN config stored in DB: **provider** (coturn / metered / disabled), **server URL**, **secret or API key**
- Admin form: provider dropdown + URL field + secret/API key field
- On save: **test connection** — attempt TURN credential fetch and display success/failure to admin
- "Disabled" provider option = force STUN-only (overrides any legacy TURN_PROVIDER env var)

#### Admin panel - Settings tab
- New **"Settings" tab** added alongside the existing Users and Channels tabs in AdminLive
- Boolean flags (voice, registration, link previews, email confirmation) use **Flowbite toggle switches** — instant save, no confirmation dialog
- TURN config section below the toggles — form with provider dropdown + URL + secret fields + Save & Test button
- All changes save immediately on toggle/submit; no separate "save all" button for toggles

#### Admin user creation
- Add **Create User form** to the Users tab in AdminLive (or as a modal from the users list)
- Minimum fields: email, username, password
- Creation bypasses the registration disabled flag — always available to admins

### Claude's Discretion
- DB schema design for the flags table (key-value vs named columns vs separate TURN config table)
- TURN connection test implementation details (what exactly to test and how to surface the result)
- Link preview disable implementation (where in the pipeline to gate the fetch)
- How to pass feature flag state to LiveView (assign at mount, module-level cache, etc.)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ADMN-01 | Server operator can enable/disable features via environment variables (voice, TURN, link previews, registration) | DB-backed FeatureFlags context with `get_flags/0`, enforcement at query level (voice), route level (registration), runtime cast level (link previews), channel join level (VoiceChannel), and login level (email confirmation) |
</phase_requirements>

---

## Summary

Phase 5 implements DB-backed feature flags for a Phoenix/Ecto application with an existing admin LiveView. The core work is: create a `Cromulent.FeatureFlags` context backed by a database table, wire it into all enforcement points across the app, and add a Settings tab to AdminLive with Flowbite toggles.

The architectural decision is already made: a single database table is authoritative over legacy env vars. The key design question left to Claude's discretion is schema shape (key-value rows vs single-row named columns vs two tables). Based on research, a **single-row named-columns approach** fits best here: there are exactly 5-6 well-known flags with distinct types (4 booleans + 1 enum/string for TURN provider + URL + secret). Named columns give compile-time clarity and typed Ecto casting, and Repo.one + upsert on a singleton record is straightforward.

The enforcement pattern is load-at-mount via `on_mount` in UserAuth (following the existing hook pattern). Flags are fetched once per page load and stored in socket assigns as a `%FeatureFlags{}` struct. No caching layer is needed for this scale — a simple `Repo.one` on every mount is sufficient and simpler than maintaining an ETS cache.

**Primary recommendation:** Create a `feature_flags` table with named boolean columns plus TURN config columns, a `Cromulent.FeatureFlags` context with `get_flags/0` and upsert, load flags via UserAuth's `ensure_authenticated` on_mount callback, enforce at each call site.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto / ecto_sql | ~> 3.10 (already in project) | DB schema, migrations, queries | Project already uses it for all persistence |
| Phoenix LiveView | ~> 1.0.0 (already in project) | Settings tab UI, toggle events | Already powers AdminLive |
| Flowbite (CSS/JS) | Already in assets/package.json | Toggle switch UI components | Already used in project, locked decision |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Finch | ~> 0.13 (already in project) | TURN connection test HTTP call | Used for Metered TURN health check in test |
| Phoenix.Channel | Built-in Phoenix | VoiceChannel enforcement | Already used in voice_channel.ex |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Named-columns single row | key-value rows (`{key: "voice_enabled", value: "true"}`) | KV is more flexible but requires string casting; named columns give type safety and compile-time field names. With only 6-7 known flags, named columns win. |
| Named-columns single row | Separate `turn_config` table | Splitting TURN config into its own table adds a join. Since TURN config is always fetched with flags, a single table with nullable TURN columns is simpler. |
| Load at mount via on_mount | Module-level ETS cache with PubSub invalidation | Cache adds complexity (race conditions, invalidation). "Next page load" is the stated propagation SLA, so no cache needed. |
| Load at mount via on_mount | fun_with_flags library | Library adds dependency + schema complexity for 5 flags. Hand-loading from DB is 20 lines of code. |

**No new dependencies required.** Everything needed is already in the project.

---

## Architecture Patterns

### Recommended Project Structure
```
lib/cromulent/
├── feature_flags.ex          # context module: get_flags/0, upsert_flags/1
├── feature_flags/
│   └── flags.ex              # Ecto schema for feature_flags table
priv/repo/migrations/
└── YYYYMMDD_create_feature_flags.exs
lib/cromulent_web/
├── user_auth.ex              # add feature_flags assign in ensure_authenticated
└── live/
    └── admin_live.ex         # add :settings tab, toggle events, TURN form
```

### Pattern 1: Single-Row Named-Columns Schema

**What:** A single row in `feature_flags` holds all flag state. Always accessed via `Repo.one(FeatureFlags.Flags)` — no ID filtering needed. Upserted on admin save.

**When to use:** When the set of flags is known at compile time, typed, and small (< 20 flags). Avoids string-cast hell of key-value stores.

**Example:**
```elixir
# lib/cromulent/feature_flags/flags.ex
defmodule Cromulent.FeatureFlags.Flags do
  use Ecto.Schema
  import Ecto.Changeset

  schema "feature_flags" do
    field :voice_enabled, :boolean, default: true
    field :registration_enabled, :boolean, default: true
    field :link_previews_enabled, :boolean, default: true
    field :email_confirmation_required, :boolean, default: false
    field :turn_provider, :string, default: "disabled"  # "disabled" | "coturn" | "metered"
    field :turn_url, :string
    field :turn_secret, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(flags, attrs) do
    flags
    |> cast(attrs, [
      :voice_enabled, :registration_enabled, :link_previews_enabled,
      :email_confirmation_required, :turn_provider, :turn_url, :turn_secret
    ])
    |> validate_inclusion(:turn_provider, ["disabled", "coturn", "metered"])
  end
end
```

### Pattern 2: FeatureFlags Context

**What:** A context module that isolates all flag reads and writes. Callers never touch Ecto directly.

**When to use:** Always — consistent with `Cromulent.Accounts`, `Cromulent.Channels` context pattern already in project.

**Example:**
```elixir
# lib/cromulent/feature_flags.ex
defmodule Cromulent.FeatureFlags do
  alias Cromulent.Repo
  alias Cromulent.FeatureFlags.Flags

  @doc "Returns the current feature flags, or defaults if no row exists."
  def get_flags do
    Repo.one(Flags) || %Flags{}
  end

  @doc "Upserts the feature flags row."
  def upsert_flags(attrs) do
    flags = get_flags()
    flags
    |> Flags.changeset(attrs)
    |> Repo.insert_or_update()
  end
end
```

### Pattern 3: Load Flags via UserAuth on_mount

**What:** Flags are loaded once per mount in `ensure_authenticated` and stored as `:feature_flags` in socket assigns. All LiveViews that use `ensure_authenticated` automatically have `@feature_flags` available.

**When to use:** Following the existing project pattern — UserAuth's `ensure_authenticated` already loads `:channels`, `:server_presences`, `:unread_counts` etc.

**Example:**
```elixir
# In user_auth.ex ensure_authenticated, after user confirmed:
flags = Cromulent.FeatureFlags.get_flags()
socket = Phoenix.Component.assign(socket, :feature_flags, flags)
```

Then in the template:
```heex
<%!-- Pass to sidebar --%>
<.sidebar
  ...
  voice_enabled={@feature_flags.voice_enabled}
/>
```

### Pattern 4: Registration Redirect in UserRegistrationLive

**What:** Check flags in `mount/3` of UserRegistrationLive and redirect with flash when registration is disabled.

**When to use:** For LiveView routes. For dead (plug) routes, use a Plug in the pipeline.

**Example:**
```elixir
def mount(_params, _session, socket) do
  flags = Cromulent.FeatureFlags.get_flags()

  if !flags.registration_enabled do
    {:ok,
     socket
     |> put_flash(:error, "Registration is closed on this server.")
     |> redirect(to: ~p"/users/log_in")}
  else
    changeset = Accounts.change_user_registration(%User{})
    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)
    {:ok, socket, temporary_assigns: [form: nil]}
  end
end
```

### Pattern 5: Voice Channel Enforcement (Query-Level + Channel-Level)

**What:** Two enforcement points: (1) `list_joined_channels` filters out voice channels at the Ecto query level when voice is disabled; (2) `VoiceChannel.join/3` rejects with error when voice is disabled.

**When to use:** Defense in depth — query level hides the UI, channel level enforces the protocol.

**Example (query level):**
```elixir
# Cromulent.Channels - pass voice_enabled flag
def list_joined_channels(user, voice_enabled \\ true) do
  query = from(c in Channel,
    join: m in ChannelMembership,
    on: m.channel_id == c.id and m.user_id == ^user.id,
    order_by: [asc: c.inserted_at]
  )

  if voice_enabled do
    Repo.all(query)
  else
    query |> where([c, _m], c.type != :voice) |> Repo.all()
  end
end
```

**Example (VoiceChannel.join/3):**
```elixir
def join("voice:" <> channel_id, _params, socket) do
  flags = Cromulent.FeatureFlags.get_flags()

  if !flags.voice_enabled do
    {:error, %{reason: "voice_disabled"}}
  else
    # existing join logic...
  end
end
```

### Pattern 6: TURN Config Reading (Replace System.get_env)

**What:** Replace `System.get_env("TURN_PROVIDER")` inline read in `channel_live.ex:537` with a DB flag read. The `get_ice_servers/1` call must not crash when no TURN is configured.

**When to use:** Everywhere TURN config is currently read from env vars.

**Example:**
```elixir
defp get_ice_servers(user_id) do
  flags = Cromulent.FeatureFlags.get_flags()

  case flags.turn_provider do
    "coturn" -> Cromulent.Turn.Coturn.get_ice_servers(user_id, flags.turn_url, flags.turn_secret)
    "metered" -> Cromulent.Turn.Metered.get_ice_servers(user_id)
    _ -> {:ok, [%{urls: "stun:stun.l.google.com:19302"}]}
  end
end
```

Note: Coturn and Metered provider modules currently read from env vars directly. They need to accept params or read from flags instead.

### Pattern 7: Email Confirmation Toggle

**What:** When `email_confirmation_required` is true, `user_registration_live.ex` calls the commented-out `deliver_user_confirmation_instructions/2`, and `get_user_by_email_and_password` rejects unconfirmed users.

**When to use:** Wire the existing infrastructure that Phoenix Auth generator already created.

**Example (accounts.ex login check):**
```elixir
def get_user_by_email_and_password(email, password) do
  user = Repo.get_by(User, email: email)
  if User.valid_password?(user, password) do
    flags = Cromulent.FeatureFlags.get_flags()
    if flags.email_confirmation_required && is_nil(user.confirmed_at) do
      nil  # Treat as invalid — unconfirmed users cannot log in
    else
      user
    end
  end
end
```

### Pattern 8: Link Preview Disable (Gate in room_server.ex)

**What:** Replace `System.get_env("LINK_PREVIEWS") != "disabled"` check in `room_server.ex:84` with DB flag read. This is already the correct enforcement point (cast time, fire-and-forget).

**Example:**
```elixir
flags = Cromulent.FeatureFlags.get_flags()
if flags.link_previews_enabled do
  # existing Task.start fetch logic
end
```

### Anti-Patterns to Avoid

- **Compile-time flag checks:** Never use `Application.compile_env` for feature flags that must change at runtime without redeployment.
- **Caching with ETS without invalidation:** If adding a cache, it must be invalidated on every upsert. For "next page load" SLA, no cache is simpler and correct.
- **Checking flags in the template only:** Always enforce at the backend (query/channel/controller) — template checks are UI-only conveniences, not security controls.
- **Calling `get_flags/0` repeatedly per request:** Load once in `ensure_authenticated` and pass through assigns. Avoid calling `Repo.one(Flags)` in every individual function.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Toggle UI component | Custom CSS toggle | Flowbite toggle switch (already in project) | Already integrated; consistent with project UI |
| Feature flag library | Custom ETS-backed cache | Simple `Repo.one(Flags)` at mount | 5 flags do not need library overhead; library adds migration complexity |
| TURN credential validation | Custom HTTP probe | Attempt `get_ice_servers/1` in a Task and return result | TURN modules already implement this logic |

**Key insight:** This phase is entirely wiring existing infrastructure. The flag values flow from the DB into already-built enforcement points. No new complex systems are needed.

---

## Common Pitfalls

### Pitfall 1: Default State When No DB Row Exists

**What goes wrong:** On fresh install, `Repo.one(Flags)` returns `nil`. Callers do `flags.voice_enabled` and crash with `nil.voice_enabled`.

**Why it happens:** The migration creates the table but inserts no rows. First boot has no flags row.

**How to avoid:** In `get_flags/0`, return `%Flags{}` as the default when `Repo.one` returns nil (struct default values match the spec: voice on, registration on, link previews on, email confirmation off, TURN disabled). The struct field defaults ARE the defaults.

**Warning signs:** Crashes on fresh `mix ecto.reset` runs.

### Pitfall 2: TURN Provider Modules Still Reading from Env Vars

**What goes wrong:** After migration to DB-backed TURN config, the existing `Cromulent.Turn.Coturn` and `Cromulent.Turn.Metered` modules still call `System.get_env("TURN_SECRET")` with `raise` if missing.

**Why it happens:** Those modules were written to read env vars directly and raise on missing config.

**How to avoid:** Modify `get_ice_servers/1` signatures on provider modules to accept the config values as parameters (or read from the flags struct). Remove the `raise` — return `{:error, :not_configured}` instead.

**Warning signs:** Clicking "Test" in the admin TURN config crashes the server process.

### Pitfall 3: Voice Channel Hidden in Sidebar but Joinable via Direct URL/Channel

**What goes wrong:** Voice channels are hidden from sidebar, but a user who bookmarked the URL can still navigate to `voice:channel_id` via Phoenix Channel and connect.

**Why it happens:** Hiding from UI is not enforcement — the channel join is separate from the query.

**How to avoid:** Two enforcement layers are required: query-level (hides from sidebar) AND VoiceChannel.join rejection (protocol-level). Both are specified in the locked decisions.

**Warning signs:** Testing flag disable by only checking sidebar visibility.

### Pitfall 4: Registration Flash Message in LiveView Redirect

**What goes wrong:** `put_flash/3` in `mount/3` before `redirect/2` may not display the flash message if the target route re-renders without flash.

**Why it happens:** LiveView flash propagation during mount redirects can behave differently from Plug-based redirects.

**How to avoid:** Use Phoenix's flash propagation — call `put_flash/3` before `redirect` in mount. The `:error` key will be picked up by the target LiveView's `@flash` assign. Test this in dev to confirm flash appears on the login page.

**Warning signs:** No flash message visible after redirect.

### Pitfall 5: Email Confirmation Blocks ALL Existing Users on Toggle Enable

**What goes wrong:** Enabling `email_confirmation_required` immediately locks out all users who registered before confirmation was required (their `confirmed_at` is nil).

**Why it happens:** `confirmed_at` field is nil for all users registered when confirmation was off.

**How to avoid:** When enabling the flag, consider whether to bulk-confirm existing users. For this phase: the `get_user_by_email_and_password` check should only apply to users registered AFTER the flag was enabled. Simpler approach: backfill `confirmed_at` for all existing users when the flag is first enabled (can be done in the admin action). Document this clearly in the admin UI.

**Warning signs:** After enabling email confirmation in a running server, existing users cannot log in.

### Pitfall 6: Flowbite Toggle Uses phx-click with Sync Save

**What goes wrong:** Toggle changes are instant-save (no submit button). If the DB write fails, the toggle visually changed but the DB did not.

**Why it happens:** UI optimistic update without error handling.

**How to avoid:** In the `handle_event` for toggle changes, return the DB-read value back via `assign` — assign the flags struct from the DB response, not from the UI event. This way the UI always reflects ground truth.

---

## Code Examples

Verified patterns from existing codebase:

### Migration: Create feature_flags Table
```elixir
# priv/repo/migrations/TIMESTAMP_create_feature_flags.exs
defmodule Cromulent.Repo.Migrations.CreateFeatureFlags do
  use Ecto.Migration

  def change do
    create table(:feature_flags) do
      add :voice_enabled, :boolean, default: true, null: false
      add :registration_enabled, :boolean, default: true, null: false
      add :link_previews_enabled, :boolean, default: true, null: false
      add :email_confirmation_required, :boolean, default: false, null: false
      add :turn_provider, :string, default: "disabled", null: false
      add :turn_url, :string
      add :turn_secret, :string

      timestamps(type: :utc_datetime)
    end
  end
end
```

Note: No primary key override needed; standard integer ID is fine for a singleton table.

### FeatureFlags Context: insert_or_update Pattern
```elixir
def upsert_flags(attrs) do
  case get_flags() do
    %Cromulent.FeatureFlags.Flags{id: nil} = defaults ->
      # No row yet — insert
      defaults
      |> Flags.changeset(attrs)
      |> Repo.insert()

    existing ->
      existing
      |> Flags.changeset(attrs)
      |> Repo.update()
  end
end
```

### AdminLive: Settings Tab — Toggle Event Pattern
```elixir
# Following the existing handle_event pattern in admin_live.ex
def handle_event("toggle_flag", %{"flag" => flag, "value" => value}, socket) do
  attrs = %{String.to_existing_atom(flag) => value == "true"}

  case Cromulent.FeatureFlags.upsert_flags(attrs) do
    {:ok, flags} ->
      {:noreply,
       socket
       |> put_flash(:info, "Setting updated.")
       |> assign(:feature_flags, flags)}

    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Failed to update setting.")}
  end
end
```

### AdminLive: Tab Navigation — Follow Existing Pattern
The existing tab pattern uses `handle_params/3` matching `tab` param and `String.to_atom/1`. Extend `~w(users channels)` to `~w(users channels settings)`:

```elixir
def handle_params(%{"tab" => tab}, _uri, socket) when tab in ~w(users channels settings) do
  {:noreply, assign(socket, :tab, String.to_atom(tab))}
end
```

### Flowbite Toggle Switch HTML Pattern (existing Flowbite in project)
```heex
<%!-- Flowbite toggle — phx-click sends flag name and new value --%>
<label class="inline-flex items-center cursor-pointer">
  <input
    type="checkbox"
    checked={@feature_flags.voice_enabled}
    phx-click="toggle_flag"
    phx-value-flag="voice_enabled"
    phx-value-value={!@feature_flags.voice_enabled}
    class="sr-only peer"
  />
  <div class="relative w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4
              peer-focus:ring-indigo-300 dark:peer-focus:ring-indigo-800 rounded-full peer
              dark:bg-gray-700 peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full
              peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px]
              after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full
              after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-indigo-600">
  </div>
  <span class="ms-3 text-sm font-medium text-white">Voice Channels</span>
</label>
```

### Admin Create User — Following register_user Pattern
```elixir
# In AdminLive handle_event
def handle_event("admin_create_user", %{"email" => email, "username" => username, "password" => password}, socket) do
  case Accounts.register_user(%{email: email, username: username, password: password}) do
    {:ok, _user} ->
      {:noreply,
       socket
       |> put_flash(:info, "User #{username} created.")
       |> assign(:users, Accounts.list_users())}

    {:error, changeset} ->
      {:noreply,
       socket
       |> put_flash(:error, "Failed to create user.")
       |> assign(:create_user_form, to_form(changeset))}
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `System.get_env("LINK_PREVIEWS")` at cast time | DB flag read via `FeatureFlags.get_flags()` | This phase | Same call site, different source |
| `System.get_env("TURN_PROVIDER")` in `get_ice_servers/1` | DB `flags.turn_provider` field | This phase | TURN config editable at runtime without restart |
| Commented-out confirmation email in registration | Conditionally called based on DB flag | This phase | Enables on/off without redeploy |

**Deprecated/outdated after this phase:**
- `LINK_PREVIEWS` env var: superseded by DB flag (backward compat: treat existing "disabled" env var as initial migration if desired, then DB takes over)
- `TURN_PROVIDER`, `TURN_SECRET`, `TURN_URL` env vars: superseded by DB TURN config
- `Application.compile_env(:cromulent, :dev_routes)` pattern: NOT the model for these flags — that pattern is compile-time only

---

## Open Questions

1. **Backfilling confirmed_at for existing users when email confirmation is enabled**
   - What we know: All existing users have `confirmed_at: nil`
   - What's unclear: Should the admin UI warn about this before enabling? Should enablement auto-backfill?
   - Recommendation: Backfill `confirmed_at` to `inserted_at` for all users in the same DB transaction that enables the flag, or at minimum show a warning in the admin UI. The simplest safe option: when the flag is first enabled, run `Repo.update_all(User, set: [confirmed_at: DateTime.utc_now()])` for users where `confirmed_at` is nil.

2. **TURN connection test: what to test**
   - What we know: The admin wants success/failure feedback on Save & Test
   - What's unclear: For coturn, credential generation is local (no HTTP call); for metered, there's an API call. A coturn "test" can only verify that credentials are generated (not network reachability).
   - Recommendation: For coturn — attempt `get_ice_servers/1` with the provided URL/secret and return `:ok` if it succeeds (credential math works). For metered — make the actual API call and return the HTTP result. Surface as inline text ("Connection successful" / "Failed: ...") rather than a separate modal.

3. **TURN provider module refactoring**
   - What we know: `Coturn.get_ice_servers/1` and `Metered.get_ice_servers/1` currently read env vars with `raise`
   - What's unclear: Best signature change — pass flags struct, or pass individual params?
   - Recommendation: Pass individual params (`get_ice_servers(user_id, turn_url, turn_secret)` for coturn, `get_ice_servers(user_id, api_url, api_key)` for metered). Keeps provider modules standalone and testable.

---

## Integration Map

All files that need changes, organized by integration point:

| File | Change Required |
|------|----------------|
| `priv/repo/migrations/TIMESTAMP_create_feature_flags.exs` | New migration |
| `lib/cromulent/feature_flags/flags.ex` | New Ecto schema |
| `lib/cromulent/feature_flags.ex` | New context module |
| `lib/cromulent_web/user_auth.ex` | Add `feature_flags` assign in `ensure_authenticated` |
| `lib/cromulent_web/live/admin_live.ex` | Add Settings tab, toggle events, TURN form, Create User form |
| `lib/cromulent_web/live/user_registration_live.ex` | Check flag in mount, redirect when disabled; conditionally deliver confirmation email |
| `lib/cromulent_web/live/user_login_live.ex` | Hide Register link when registration disabled (needs `feature_flags` assign) |
| `lib/cromulent/accounts.ex` | `get_user_by_email_and_password/2` checks `confirmed_at` when confirmation required |
| `lib/cromulent/channels.ex` | `list_joined_channels/1` accepts voice_enabled param, filters voice when disabled |
| `lib/cromulent_web/channels/voice_channel.ex` | `join/3` checks voice flag before allowing join |
| `lib/cromulent/chat/room_server.ex` | Replace `System.get_env("LINK_PREVIEWS")` with DB flag check |
| `lib/cromulent/turn/coturn.ex` | Accept URL/secret as params instead of reading env vars |
| `lib/cromulent/turn/metered.ex` | Accept API URL/key as params instead of reading env vars |
| `lib/cromulent_web/live/channel_live.ex` | `get_ice_servers/1` reads from DB flags, passes to provider modules |
| `lib/cromulent_web/components/sidebar.ex` | Accept `voice_enabled` attr, conditionally hide voice section |

---

## Sources

### Primary (HIGH confidence)
- Codebase direct inspection (`lib/cromulent_web/live/admin_live.ex`, `user_auth.ex`, `channel_live.ex`, `voice_channel.ex`, `room_server.ex`, `user_registration_live.ex`, `accounts.ex`, `channels.ex`, `turn/coturn.ex`, `components/sidebar.ex`) — all integration points mapped
- Ecto schema pattern from `lib/cromulent/channels/channel.ex` — named columns with Ecto.Enum and defaults
- UserAuth `ensure_authenticated` on_mount pattern — confirms how to inject assigns for all LiveViews

### Secondary (MEDIUM confidence)
- [Elixir Forum: DB table "settings" with key-value data](https://elixirforum.com/t/db-table-settings-with-key-value-data-and-how-to-improve-it/57880) — community consensus for named-columns vs KV for small known flag sets
- [Phoenix LiveView on_mount universal assigns](https://honesw.com/blog/universal-assigns-with-phoenix-liveview) — confirmed pattern for loading flags once and distributing via mount

### Tertiary (LOW confidence)
- [FunWithFlags GitHub](https://github.com/tompave/fun_with_flags) — reviewed and decided against: overkill for 5 static flags

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all existing Ecto/Phoenix/Flowbite
- Architecture: HIGH — patterns directly verified against existing codebase code
- Integration points: HIGH — every file change identified via direct code inspection
- Pitfalls: HIGH — most identified from existing code patterns (e.g., coturn raises on missing env vars, confirmed_at nil for existing users)
- TURN test implementation: MEDIUM — behavior depends on provider type; approach is sound but exact HTTP call for metered not verified against live API

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (stable Phoenix/Ecto patterns, 30-day window)
