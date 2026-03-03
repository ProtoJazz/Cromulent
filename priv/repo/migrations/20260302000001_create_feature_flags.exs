defmodule Cromulent.Repo.Migrations.CreateFeatureFlags do
  use Ecto.Migration

  def change do
    create table(:feature_flags, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :voice_enabled, :boolean, default: true, null: false
      add :registration_enabled, :boolean, default: true, null: false
      add :link_previews_enabled, :boolean, default: true, null: false
      add :email_confirmation_required, :boolean, default: false, null: false
      add :turn_provider, :string, default: "disabled", null: false
      add :turn_url, :string
      add :turn_secret, :string

      timestamps(type: :utc_datetime)
    end
  end
end
