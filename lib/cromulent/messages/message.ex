defmodule Cromulent.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, Cromulent.UUID7, autogenerate: true}
  @foreign_key_type :binary_id
  schema "messages" do
    field :body, :string

    belongs_to :channel, Cromulent.Channels.Channel
    belongs_to :user, Cromulent.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :channel_id, :user_id])
    |> validate_required([:body, :channel_id, :user_id])
    |> validate_length(:body, min: 1, max: 4000)
  end
end
