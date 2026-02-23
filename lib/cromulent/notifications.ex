# lib/cromulent/notifications.ex
defmodule Cromulent.Notifications do
  import Ecto.Query
  alias Cromulent.Repo
  alias Cromulent.Notifications.ChannelRead

  # Called when a user opens a channel — upsert their read position
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
  end

  # Returns a map of %{channel_id => unread_count} for all a user's channels
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
end
