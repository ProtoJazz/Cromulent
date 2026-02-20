defmodule Cromulent.Repo.Migrations.AddPermissionsToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add :is_default, :boolean, null: false, default: false
      add :is_private, :boolean, null: false, default: false
      add :write_permission, :string, null: false, default: "everyone"
    end
  end
end
