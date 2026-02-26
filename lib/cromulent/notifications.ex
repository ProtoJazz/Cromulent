defmodule Cromulent.Notifications do
  import Ecto.Query
  alias Cromulent.Repo
  alias Cromulent.Notifications.{ChannelRead, Notification}
  alias Cromulent.Groups

  # ── Channel Read Tracking ──────────────────────────────────────────────────

  def mark_channel_read(user_id, channel_id, message_id) do
    %ChannelRead{}
    |> ChannelRead.changeset(%{
      user_id: user_id,
      channel_id: channel_id,
      last_read_message_id: message_id
    })
    |> Repo.insert(
      on_conflict: [set: [last_read_message_id: message_id, updated_at: DateTime.utc_now()]],
      conflict_target: [:user_id, :channel_id]
    )

    # Also mark any notifications in this channel as read for this user
    mark_notifications_read(user_id, channel_id)
  end

  # ── Unread Counts ──────────────────────────────────────────────────────────

  # Total unread messages per channel (existing behaviour)
  def unread_counts_for_user(user_id) do
    from(m in Cromulent.Messages.Message,
      join: membership in Cromulent.Channels.ChannelMembership,
      on: membership.channel_id == m.channel_id and membership.user_id == ^user_id,
      left_join: cr in ChannelRead,
      on: cr.channel_id == m.channel_id and cr.user_id == ^user_id,
      where: is_nil(cr.last_read_message_id) or m.id > cr.last_read_message_id,
      where: m.user_id != ^user_id,
      group_by: m.channel_id,
      select: {m.channel_id, count(m.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # Unread mention/notification counts per channel — used for the badge number
  def mention_counts_for_user(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      group_by: n.channel_id,
      select: {n.channel_id, count(n.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # ── Notification Fan-out ───────────────────────────────────────────────────

  @doc """
  Called after a message is inserted. Takes the parsed mention attrs list
  (from MentionParser) and fans out notification rows to all affected users.

  `channel_member_ids` — all user IDs in the channel (for @everyone)
  `online_user_ids`    — currently online user IDs (for @here), from Presence
  """
  def fan_out_notifications(message, mention_attrs_list, channel_member_ids, online_user_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    notification_rows =
      mention_attrs_list
      |> Enum.flat_map(&recipients_for_mention(&1, channel_member_ids, online_user_ids))
      |> Enum.uniq()
      # Don't notify the message author
      |> Enum.reject(&(&1 == message.user_id))
      |> Enum.map(fn user_id ->
        mention = Enum.find(mention_attrs_list, fn m ->
          case m.mention_type do
            :user -> m.user_id == user_id
            _ -> true
          end
        end)

        %{
          id: Cromulent.UUID7.autogenerate(),
          user_id: user_id,
          channel_id: message.channel_id,
          message_id: message.id,
          mention_type: mention.mention_type,
          read_at: nil,
          inserted_at: now,
          updated_at: now
        }
      end)

    # insert_all with on_conflict ignore handles the unique (user_id, message_id) constraint
    Repo.insert_all(Notification, notification_rows,
      on_conflict: :nothing,
      conflict_target: [:user_id, :message_id]
    )

    Enum.map(notification_rows, & &1.user_id)
  end

  defp recipients_for_mention(%{mention_type: :user, user_id: uid}, _members, _online) do
    [uid]
  end

  defp recipients_for_mention(%{mention_type: :group, group_id: gid}, _members, _online) do
    Groups.user_ids_for_group(gid)
  end

  defp recipients_for_mention(%{mention_type: :here}, _members, online_user_ids) do
    online_user_ids
  end

  defp recipients_for_mention(%{mention_type: :everyone}, channel_member_ids, _online) do
    channel_member_ids
  end

  # ── Read State ─────────────────────────────────────────────────────────────

  defp mark_notifications_read(user_id, channel_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(n in Notification,
      where: n.user_id == ^user_id and n.channel_id == ^channel_id and is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: now])
  end
end
