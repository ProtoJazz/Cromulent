defmodule Cromulent.Repo.Migrations.CreateMessageMentions do
  use Ecto.Migration

  def change do
    create table(:message_mentions, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :mention_type, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: true
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: true

      timestamps(type: :utc_datetime)
    end

    create index(:message_mentions, [:message_id])
    create index(:message_mentions, [:user_id])
    create index(:message_mentions, [:group_id])
  end
end
