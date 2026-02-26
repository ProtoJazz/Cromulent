defmodule Cromulent.Notifications.ChannelRead do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "channel_reads" do
    belongs_to :user, Cromulent.Accounts.User, type: :binary_id
    belongs_to :channel, Cromulent.Channels.Channel, type: :binary_id
    belongs_to :last_read_message, Cromulent.Messages.Message, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(channel_read, attrs) do
    channel_read
    |> cast(attrs, [:user_id, :channel_id, :last_read_message_id])
    |> validate_required([:user_id, :channel_id])
  end
end
