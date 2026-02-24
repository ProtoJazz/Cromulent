defmodule Cromulent.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all), null: false
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      # one of: "user", "group", "here", "everyone"
      add :mention_type, :string, null: false
      add :read_at, :utc_datetime, null: true

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :channel_id])
    create unique_index(:notifications, [:user_id, :message_id])
  end
end
