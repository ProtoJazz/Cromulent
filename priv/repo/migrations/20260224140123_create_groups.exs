defmodule Cromulent.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :color, :string, null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:groups, [:slug])
  end
end
