defmodule Cromulent.Messages.MessageMention do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Cromulent.UUID7, autogenerate: true}
  @foreign_key_type :binary_id

  # mention_type values:
  #   :user     — @username, user_id is set, group_id is nil
  #   :group    — @groupslug, group_id is set, user_id is nil
  #   :here     — @here, both nil (online members at time of send)
  #   :everyone — @everyone / @all, both nil (all channel members)

  schema "message_mentions" do
    field :mention_type, Ecto.Enum, values: [:user, :group, :here, :everyone]

    belongs_to :message, Cromulent.Messages.Message
    belongs_to :user, Cromulent.Accounts.User
    belongs_to :group, Cromulent.Groups.Group

    timestamps(type: :utc_datetime)
  end

  def changeset(mention, attrs) do
    mention
    |> cast(attrs, [:message_id, :mention_type, :user_id, :group_id])
    |> validate_required([:message_id, :mention_type])
    |> validate_target()
  end

  # Ensure user_id or group_id is set when required by mention_type
  defp validate_target(changeset) do
    case get_field(changeset, :mention_type) do
      :user ->
        validate_required(changeset, [:user_id])

      :group ->
        validate_required(changeset, [:group_id])

      _ ->
        changeset
    end
  end
end
