defmodule Cromulent.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels) do
      add :name, :string, null: false
      add :type, :string, null: false, default: "text"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channels, [:name])
  end
end
