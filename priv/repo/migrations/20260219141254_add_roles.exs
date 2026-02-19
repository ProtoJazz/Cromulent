defmodule Cromulent.Repo.Migrations.AddRoles do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "member"
    end
  end
end
