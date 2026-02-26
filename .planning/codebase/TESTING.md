# Testing Patterns

**Analysis Date:** 2026-02-26

## Test Framework

**Runner:**
- ExUnit (Elixir built-in testing framework)
- No external test runner required
- Config: No separate test config file; configuration in `config/test.exs`

**Assertion Library:**
- ExUnit assertions: `assert`, `refute`, `assert_raise`
- Ecto-specific: `Ecto.Adapters.SQL.Sandbox` for database isolation
- Pattern matching assertions: `assert %User{id: ^id} = result`

**Run Commands:**
```bash
mix test                                    # Run all tests
mix test test/path_test.exs                 # Run a single test file
mix test test/path_test.exs:42              # Run a specific test by line number
```

## Test File Organization

**Location:**
- Test files co-located with source in `test/` mirror directory structure
- Source: `lib/cromulent/accounts.ex` → Test: `test/cromulent/accounts_test.exs`
- Source: `lib/cromulent_web/live/channel_live.ex` → Test: `test/cromulent_web/live/channel_live_test.exs`
- Support code: `test/support/` (fixtures, test helpers, setup)

**Naming:**
- Test modules append `Test` suffix: `Cromulent.AccountsTest`, `CromulentWeb.ChannelLiveTest`
- Test functions start with `test `: `test "returns user by email"`
- Fixtures use underscore: `user_fixture()`, `user_fixture(attrs)`

**Structure:**
```
test/
├── cromulent/                          # Business logic tests
│   └── accounts_test.exs
├── cromulent_web/                      # Web/LiveView tests
│   ├── user_auth_test.exs
│   └── live/
│       └── channel_live_test.exs
├── support/                            # Test infrastructure
│   ├── conn_case.ex                    # HTTP controller test setup
│   ├── data_case.ex                    # Database test setup
│   └── fixtures/
│       └── accounts_fixtures.ex        # Factories and builders
└── test_helper.exs                     # Entry point
```

## Test Structure

**Suite Organization:**
```elixir
defmodule Cromulent.AccountsTest do
  use Cromulent.DataCase

  alias Cromulent.Accounts
  import Cromulent.AccountsFixtures
  alias Cromulent.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end
end
```

**Patterns:**
- Use `describe/2` blocks to organize related tests by function
- One behavior per test function
- Arrange-Act-Assert structure (often implicit)

**Setup Blocks:**
- Inline setup with `setup do` block in `describe`:
```elixir
describe "apply_user_email/3" do
  setup do
    %{user: user_fixture()}
  end

  test "requires email to change", %{user: user} do
    # test implementation
  end
end
```

- Setup automatically provides context to all tests in the describe block
- Return map of `key: value` pairs to pass to test

## Test Data & Fixtures

**Fixtures:**
- Organized in `test/support/fixtures/` parallel to source structure
- `test/support/fixtures/accounts_fixtures.ex` provides:

```elixir
defmodule Cromulent.AccountsFixtures do
  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Cromulent.Accounts.register_user()
    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
```

**Location:**
- `test/support/fixtures/accounts_fixtures.ex` - User, token builders
- Imported via `import Cromulent.AccountsFixtures` in test modules

**Patterns:**
- Generators return domain objects (users, tokens) ready for testing
- Builders use functional style with optional attributes:
```elixir
user_fixture()  # Default user
user_fixture(email: "custom@example.com")  # Custom attributes
```

- `unique_*` helpers for constraint testing
- `valid_*_attributes` for form validation tests
- `extract_*` helpers for token parsing (email-based workflow testing)

## Mocking

**Framework:**
- No external mocking library used
- Leverages pattern matching and fixture strategy instead
- `Ecto.Adapters.SQL.Sandbox` provides transaction isolation

**Patterns:**
- **No explicit mocks** in current test suite; instead use real fixtures
- Database operations are wrapped in transactions per test
- Test data created via public API functions (e.g., `Accounts.register_user/1`)
- Email capture uses Swoosh Test adapter in `config/test.exs`:
```elixir
config :cromulent, Cromulent.Mailer, adapter: Swoosh.Adapters.Test
```

**Example from `accounts_test.exs`:**
```elixir
test "sends token through notification", %{user: user} do
  token =
    extract_user_token(fn url ->
      Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
    end)

  {:ok, token} = Base.url_decode64(token, padding: false)
  assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
  assert user_token.user_id == user.id
end
```

This tests the entire email delivery flow without mocking, by:
1. Calling the real delivery function with a capturing callback
2. Extracting the token from the captured email
3. Verifying the token was persisted in the database

## Database Setup & Isolation

**Framework:** `Ecto.Adapters.SQL.Sandbox`

**Configuration (`test_helper.exs`):**
```elixir
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Cromulent.Repo, :manual)
```

**Data Layer Test Base (`test/support/data_case.ex`):**
```elixir
defmodule Cromulent.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Cromulent.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Cromulent.DataCase
    end
  end

  setup tags do
    Cromulent.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Cromulent.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
```

**Isolation:**
- Each test runs in a transaction (sandbox mode)
- Transaction is rolled back after test completes
- Prevents test data from persisting between runs
- Supports parallel test execution with `async: true`

## Test Types

**Unit Tests:**
- Scope: Individual functions and changesets
- Approach: Test valid and invalid inputs separately
- Example: `test "validates email and password when given"`
- Validate constraints: uniqueness, format, length, required fields

**Integration Tests:**
- Scope: Multi-step workflows combining Accounts + Notifications
- Example: `test "sends token through notification"` - calls delivery API + verifies database state
- Database transactions enable real persistence testing
- Test email flow without real email service (Swoosh Test adapter)

**E2E Tests:**
- Not detected in current codebase
- LiveView tests exist but don't appear to test full UI flows
- Could be added to `test/cromulent_web/live/` directory

## Helper Functions

**Test Case Base Classes:**
- `Cromulent.DataCase` - Use for all database-dependent tests (most common)
- `CromulentWeb.ConnCase` - Use for HTTP controller tests (not fully reviewed)

**Utilities:**
- `errors_on(changeset)` - Extract error messages from invalid changeset
```elixir
assert %{
  password: ["can't be blank"],
  email: ["can't be blank"]
} = errors_on(changeset)
```

- `get_change(changeset, :field)` - Extract changed field value before insertion
- `Repo.get_by/2`, `Repo.exists?/2` - Verify database state after operations

## Async Testing

**Configuration:**
```elixir
use Cromulent.DataCase, async: true
```

- Not currently used in reviewed test files
- Supported via `Ecto.Adapters.SQL.Sandbox` with transaction isolation
- Could improve test suite speed but requires careful handling of shared state

## Common Patterns

**Async/Error Testing:**
```elixir
test "raises if id is invalid" do
  assert_raise Ecto.NoResultsError, fn ->
    Accounts.get_user!(-1)
  end
end
```

**Validation Testing:**
```elixir
test "validates email and password when given" do
  {:error, changeset} = Accounts.register_user(%{email: "not valid", password: "not valid"})

  assert %{
    email: ["must have the @ sign and no spaces"],
    password: ["should be at least 12 character(s)"]
  } = errors_on(changeset)
end
```

**Token/Workflow Testing:**
```elixir
test "updates the email with a valid token", %{user: user, token: token, email: email} do
  assert Accounts.update_user_email(user, token) == :ok
  changed_user = Repo.get!(User, user.id)
  assert changed_user.email != user.email
  assert changed_user.email == email
  assert changed_user.confirmed_at
  refute Repo.get_by(UserToken, user_id: user.id)  # Token should be deleted
end
```

**Changeset Assertion Pattern:**
```elixir
test "allows fields to be set" do
  email = unique_user_email()
  password = valid_user_password()

  changeset =
    Accounts.change_user_registration(
      %User{},
      valid_user_attributes(email: email, password: password)
    )

  assert changeset.valid?
  assert get_change(changeset, :email) == email
  assert get_change(changeset, :password) == password
  assert is_nil(get_change(changeset, :hashed_password))  # Should not be visible before hash
end
```

## Test Coverage

**Requirements:** Not enforced (no configuration found)

**Current State:**
- `Cromulent.AccountsTest` covers ~30+ test cases per major function
- Validation edge cases: empty fields, invalid format, length constraints, uniqueness
- Happy path and error cases both tested
- Database constraint violations explicitly tested

**Example Coverage for `register_user/1`:**
- Empty attributes
- Invalid email format
- Invalid password length
- Email/password max length (security)
- Email uniqueness (including case-insensitive)
- Happy path with valid registration

## Test Database

**Configuration (`config/test.exs`):**
```elixir
config :cromulent, Cromulent.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "cromulent_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
```

- PostgreSQL default: `cromulent_test`
- Supports `MIX_TEST_PARTITION` for parallel CI environments
- Sandbox pool size scales with CPU cores
- Database must exist before tests run

**Setup:**
```bash
mix test  # Alias automatically: creates DB, runs migrations, runs tests
```

---

*Testing analysis: 2026-02-26*
