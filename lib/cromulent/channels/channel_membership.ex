defmodule Cromulent.Channels.ChannelMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @foreign_key_type :binary_id

  @primary_key false
  schema "channel_memberships" do
    belongs_to :channel, Cromulent.Channels.Channel
    belongs_to :user, Cromulent.Accounts.User

    field :joined_at, :utc_datetime
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:channel_id, :user_id, :joined_at])
    |> validate_required([:channel_id, :user_id, :joined_at])
    |> unique_constraint([:channel_id, :user_id], name: :channel_memberships_pkey)
  end
end
