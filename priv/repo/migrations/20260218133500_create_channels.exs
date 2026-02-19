defmodule Cromulent.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :type, :string, null: false, default: "text"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channels, [:name])
    create unique_index(:channels, [:slug])
  end
end
