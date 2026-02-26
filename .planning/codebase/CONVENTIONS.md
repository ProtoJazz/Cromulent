# Coding Conventions

**Analysis Date:** 2026-02-26

## Naming Patterns

**Files:**
- Module files use snake_case: `accounts.ex`, `channels.ex`, `mention_parser.ex`
- Test files use snake_case with `_test` suffix: `accounts_test.exs`, `channel_live_test.exs`
- Directory names use snake_case: `lib/cromulent_web/live/`, `test/support/fixtures/`

**Functions:**
- Public functions use snake_case: `list_messages/1`, `get_user_by_email/1`, `create_channel/1`
- Private functions use snake_case with `defp`: `validate_email/2`, `resolve_token/3`, `can_delete?/2`
- Guard clauses and pattern matching common in function heads
- Predicate functions end with `?`: `valid_password?/2`, `admin?/1`, `member_of_group?/2`
- Private mutation helpers prefix with verb: `do_set_role/3`, `maybe_validate_unique_email/2`, `maybe_hash_password/2`

**Variables:**
- Use snake_case for all variables: `user_id`, `channel_id`, `message_id`, `mention_type`
- Frequently unpacked in function parameters: `%{id: id}`, `%User{role: :admin}`
- Bind atoms for pattern matching in pipeline operations

**Types & Modules:**
- PascalCase for module names: `Cromulent.Accounts`, `CromulentWeb.ChannelLive`
- Context modules are singular: `Cromulent.Accounts`, `Cromulent.Channels` (contain the public API)
- Schema modules nested: `Cromulent.Accounts.User`, `Cromulent.Messages.Message`
- Enum field values use lowercase atoms: `:admin`, `:member`, `:user`, `:everyone`, `:here`

## Code Style

**Formatting:**
- Elixir Code Formatter is configured in `.formatter.exs`
- Supports `Phoenix.LiveView.HTMLFormatter` for `heex` templates
- Format scope covers `{config,lib,test}/**/*.{heex,ex,exs}`
- Run with: `mix format`

**Linting:**
- No explicit ESLint/formatter config beyond Elixir's built-in
- Follows Phoenix conventions and generator style

## Import Organization

**Order:**
1. Module imports and qualified names: `alias Cromulent.Accounts.{User, UserToken}`
2. Ecto imports: `import Ecto.Query`, `import Ecto.Changeset`
3. Phoenix/Web imports: `use CromulentWeb, :live_view`
4. Cross-context aliases: `alias Cromulent.Repo`

**Path Aliases:**
- No explicit path aliases configured
- Full module paths used throughout: `Cromulent.Accounts.get_user_by_email/1`
- Context modules are the public entry point for business logic

**Example from `lib/cromulent/accounts.ex`:**
```elixir
defmodule Cromulent.Accounts do
  import Ecto.Query, warn: false
  alias Cromulent.Repo
  alias Cromulent.Accounts.{User, UserToken, UserNotifier}
```

## Error Handling

**Patterns:**
- Return tuples: `{:ok, user}` or `{:error, changeset}`
- Private functions may use `!` suffix to raise: `Repo.insert!()`, `Repo.get!()`
- Custom error atoms for permission checks: `{:error, :permission_denied}`, `{:error, :not_found}`, `{:error, :already_confirmed}`
- Guard clauses for early validation: `when is_binary(email)`
- `with` blocks for sequential token/lookup operations:
```elixir
with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
     %UserToken{sent_to: email} <- Repo.one(query),
     {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
  :ok
else
  _ -> :error
end
```

**Permission checks:**
- Use guard patterns in function heads: `defp can_delete?(%{role: :admin}, _message), do: true`
- Return atoms for permission denial: `{:error, :permission_denied}` in `Messages.create_message/4`
- Admin-first pattern: `if user.role == :admin` or `can_write?(%{role: :admin}, _channel)`

## Logging

**Framework:** Default Elixir `Logger` (not explicitly imported in code reviewed)

**Patterns:**
- Minimal explicit logging in current codebase
- Use debug info in development (`:info` level), warning in test (`:warning` level)
- Config-based: Set in `config/test.exs` and `config/dev.exs`
- Warnings for deprecated patterns: `import Ecto.Query, warn: false` used sparingly

## Comments

**When to Comment:**
- Module documentation: All public contexts have `@moduledoc` blocks
- Function documentation: All public functions documented with `@doc` strings
- Complex business logic: Comments explain intent, e.g., "back to chronological order" in `Messages.list_messages/1`
- TODO patterns: Commented code showing future work (e.g., allow user self-delete in `Messages` module)
- Admin-specific comments: "Admins can delete anything" explains permission model

**JSDoc/TSDoc:**
- Use `@doc` with examples block for documentation:
```elixir
@doc """
Gets a user by email.

## Examples

    iex> get_user_by_email("foo@example.com")
    %User{}

    iex> get_user_by_email("unknown@example.com")
    nil
"""
```

- Markdown-style documentation with `##` sections for "Examples", "Options"
- `@moduledoc` for context overview
- Use `~S"""` for special characters in doc strings

## Function Design

**Size:**
- Small, single-purpose functions preferred
- Complex logic broken into `defp` helpers
- Example: `validate_email/2` → `maybe_validate_unique_email/2` → separate validation steps

**Parameters:**
- Use pattern matching in function heads:
```elixir
def get_user_by_email_and_password(email, password)
    when is_binary(email) and is_binary(password) do
```
- Guard clauses for type validation
- Optional parameters via lists: `def valid_user_attributes(attrs \\ %{}) do`
- Structs commonly deconstructed: `%User{} = user`, `%Channel{is_private: true}`

**Return Values:**
- Consistent `{:ok, result}` and `{:error, reason}` tuple returns
- Changesets for form/validation operations: `%Ecto.Changeset{}`
- Atoms for simple queries: `:ok`, `:error`
- List or single items based on function name (plural = list)

## Module Design

**Exports:**
- All public functions at module top (no export lists, Elixir exports all public)
- Section comments to organize: `## Database getters`, `## User registration`, `## Session`
- Context modules group related operations:
  - `Accounts`: User, tokens, sessions, registration
  - `Channels`: Membership, permissions, visibility queries
  - `Messages`: Creation, deletion, list operations
  - `Notifications`: Fan-out, read tracking

**Barrel Files:**
- Not explicitly used; contexts are single-file modules in `lib/cromulent/`
- Component collections in `lib/cromulent_web/components/core_components.ex`
- Live views separate files by feature

**Schema Changesets:**
- Changesets defined as `def fieldname_changeset(schema, attrs, opts \\ [])`
- Option-based validation: `:hash_password`, `:validate_email`
- Support progressive validation for form display vs. final insertion

## Database Interaction Patterns

**Ecto Query Style:**
- Import `Ecto.Query` at module top
- Use query fragments with `from/2` macro:
```elixir
from(m in Message,
  where: m.channel_id == ^channel_id,
  order_by: [desc: m.id],
  limit: @page_size,
  preload: [:user, :mentions]
)
|> Repo.all()
```

- Preload related data to avoid N+1: `preload([:user, :mentions])`
- Transaction support via `Ecto.Multi` for multi-step operations
- Conflicting insert handling: `on_conflict: :nothing`, `on_conflict: [set: [...]]`

**Repo Operations:**
- Standard operations: `Repo.get/2`, `Repo.get_by/2`, `Repo.get!/2`, `Repo.insert/1`, `Repo.update/1`, `Repo.delete/1`
- Batch operations: `Repo.insert_all/2`, `Repo.delete_all/1`, `Repo.update_all/2`
- Transaction wrapping: `Repo.transaction(fn -> ... end)`

## LiveView & Web Patterns

**Live View Structure:**
- Use `use CromulentWeb, :live_view` to pull in helpers
- Implement `mount/3`, `handle_params/3`, `handle_event/3`
- Use `@impl true` before callback implementations
- On-mount hooks: `on_mount {CromulentWeb.UserAuth, :ensure_authenticated}`
- Socket assign patterns: `assign(socket, :field, value)`, `assign(socket, key: value, another: value2)`

**Component Style:**
- Function components with `attr` and `slot` declarations
- Render with `~H"""..."""` sigil for template syntax
- HEEX template markup follows Phoenix conventions

**Form Handling:**
- Convert changesets to forms: `to_form(changeset)`
- Empty form creation: `to_form(%{"name" => "", "type" => "text"})`

---

*Convention analysis: 2026-02-26*
