defmodule Cromulent.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channels" do
    field :name, :string
    field :type, Ecto.Enum, values: [:text, :voice], default: :text

    has_many :messages, Cromulent.Messages.Message

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :type])
    |> validate_required([:name, :type])
    |> unique_constraint(:name)
  end
end
