defmodule Cromulent.Repo.Migrations.AddDeviceFieldsToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :device_name, :string
      add :device_type, :string
      add :ip_address, :string
      add :last_used_at, :utc_datetime
    end

    create index(:users_tokens, [:user_id, :context])
  end
end
