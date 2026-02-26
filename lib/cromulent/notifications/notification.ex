defmodule Cromulent.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Cromulent.UUID7, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    field :mention_type, Ecto.Enum, values: [:user, :group, :here, :everyone]
    field :read_at, :utc_datetime

    belongs_to :user, Cromulent.Accounts.User
    belongs_to :channel, Cromulent.Channels.Channel
    belongs_to :message, Cromulent.Messages.Message

    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :channel_id, :message_id, :mention_type, :read_at])
    |> validate_required([:user_id, :channel_id, :message_id, :mention_type])
    |> unique_constraint([:user_id, :message_id])
  end
end
