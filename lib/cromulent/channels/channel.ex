defmodule Cromulent.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, Cromulent.UUID7, autogenerate: true}
  @foreign_key_type :binary_id
  schema "channels" do
    field :name, :string
    field :slug, :string
    field :type, Ecto.Enum, values: [:text, :voice], default: :text
    field :is_default, :boolean, default: false
    field :is_private, :boolean, default: false
    field :write_permission, Ecto.Enum, values: [:everyone, :admin_only],default: :everyone

    has_many :messages, Cromulent.Messages.Message
    has_many :memberships, Cromulent.Channels.ChannelMembership

    timestamps(type: :utc_datetime)
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

   def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :type, :is_default, :is_private, :write_permission])
    |> validate_required([:name, :type])
    |> then(fn cs ->
      put_change(cs, :slug, slugify(get_field(cs, :name) || ""))
    end)
    |> validate_required([:slug])
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end
