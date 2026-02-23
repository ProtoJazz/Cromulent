defmodule Cromulent.Repo.Migrations.CreateChannelReads do
  use Ecto.Migration

  def change do
    create table(:channel_reads, primary_key: false) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all), null: false
      add :last_read_message_id, references(:messages, type: :binary_id, on_delete: :nilify_all)
      add :inserted_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create unique_index(:channel_reads, [:user_id, :channel_id])
    create index(:channel_reads, [:channel_id])
  end
end
