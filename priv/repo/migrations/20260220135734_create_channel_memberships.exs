defmodule Cromulent.Repo.Migrations.CreateChannelMemberships do
  use Ecto.Migration

  def change do
    create table(:channel_memberships, primary_key: false) do
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :joined_at, :utc_datetime, null: false
    end

    create index(:channel_memberships, [:user_id])
  end
end
