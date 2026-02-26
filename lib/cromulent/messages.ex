defmodule Cromulent.Messages do
  import Ecto.Query
  alias Cromulent.Repo
  alias Cromulent.Messages.{Message, MessageMention, MentionParser}
  alias Cromulent.Channels
  alias Cromulent.Groups
  alias Cromulent.Notifications

  @page_size 50

  def list_messages(channel_id) do
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> order_by([m], desc: m.id)
    |> limit(@page_size)
    |> preload([:user, :mentions])
    |> Repo.all()
    # back to chronological order
    |> Enum.reverse()
  end

  def list_messages_before(channel_id, before_id) do
    Message
    |> where([m], m.channel_id == ^channel_id and m.id < ^before_id)
    |> order_by([m], desc: m.id)
    |> limit(@page_size)
    |> preload([:user, :mentions])
    |> Repo.all()
    |> Enum.reverse()
  end


  def delete_message(user, message_id) do
    case Repo.get(Message, message_id) do
      nil ->
        {:error, :not_found}

      message ->
        if can_delete?(user, message) do
          Repo.delete(message)
        else
          {:error, :permission_denied}
        end
    end
  end

  # Admins can delete anything.
  # To allow users to delete their own messages later, add:
  #   defp can_delete?(user, %Message{user_id: user_id}) when user.id == user_id, do: true
  defp can_delete?(%{role: :admin}, _message), do: true
  defp can_delete?(_user, _message), do: false

  @spec create_message(any(), any(), any(), any()) :: any()
  def create_message(user, channel, attrs, online_user_ids \\ []) do
    unless Channels.can_write?(user, channel) do
      {:error, :permission_denied}
    else
      Repo.transaction(fn ->
        message =
          %Message{}
          |> Message.changeset(attrs)
          |> Repo.insert!()

        channel_users = Channels.list_members(channel)
        groups_by_slug = Groups.groups_by_slug()
        mention_attrs = MentionParser.parse(message.body, channel_users, groups_by_slug)

        insert_mentions(message.id, mention_attrs)

        notified_user_ids =
          if mention_attrs != [] do
            channel_member_ids = Channels.list_channel_member_ids(channel.id)

            Notifications.fan_out_notifications(
              message,
              mention_attrs,
              channel_member_ids,
              online_user_ids
            )
          else
            []
          end

        {Repo.preload(message, [:user, :mentions]), notified_user_ids}
      end)
    end
  end

  defp insert_mentions(_message_id, []), do: :ok

  defp insert_mentions(message_id, mention_attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(mention_attrs, fn attrs ->
        %{
          id: Cromulent.UUID7.autogenerate(),
          message_id: message_id,
          mention_type: attrs.mention_type,
          user_id: attrs[:user_id],
          group_id: attrs[:group_id],
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(MessageMention, rows)
  end
end
