defmodule Cromulent.FeatureFlags.Flags do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Cromulent.UUID7, autogenerate: true}
  @foreign_key_type :binary_id

  schema "feature_flags" do
    field :voice_enabled, :boolean, default: true
    field :registration_enabled, :boolean, default: true
    field :link_previews_enabled, :boolean, default: true
    field :email_confirmation_required, :boolean, default: false
    field :turn_provider, :string, default: "disabled"
    field :turn_url, :string
    field :turn_secret, :string

    timestamps(type: :utc_datetime)
  end

  @valid_providers ["disabled", "coturn", "metered"]

  def changeset(flags, attrs) do
    flags
    |> cast(attrs, [
      :voice_enabled,
      :registration_enabled,
      :link_previews_enabled,
      :email_confirmation_required,
      :turn_provider,
      :turn_url,
      :turn_secret
    ])
    |> validate_inclusion(:turn_provider, @valid_providers)
  end
end
