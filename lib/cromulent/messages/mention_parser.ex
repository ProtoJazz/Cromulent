defmodule Cromulent.Messages.MentionParser do
  @moduledoc """
  Parses @mention tokens from message bodies and resolves them to
  structured mention records.

  Returns a list of mention attrs maps ready to insert into message_mentions.
  Unresolved @tokens (no matching user or group) are silently ignored.
  """

  @broadcast_tokens %{
    "everyone" => :everyone,
    "all" => :everyone,
    "here" => :here
  }

  @mention_regex ~r/@([\w]+)/

  @doc """
  Parses a message body and returns a list of mention attrs.

  `channel_users` — list of %User{} structs who are members of the channel.
  `groups_by_slug` — map of %{slug => %Group{}} for all groups.

  Example return value:
    [
      %{mention_type: :user, user_id: "...", group_id: nil},
      %{mention_type: :group, group_id: "...", user_id: nil},
      %{mention_type: :everyone, user_id: nil, group_id: nil}
    ]
  """
  def parse(body, channel_users, groups_by_slug) do
    users_by_username = Map.new(channel_users, &{&1.username, &1})

    @mention_regex
    |> Regex.scan(body, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.flat_map(&resolve_token(&1, users_by_username, groups_by_slug))
  end

  defp resolve_token(token, users_by_username, groups_by_slug) do
    cond do
      mention_type = Map.get(@broadcast_tokens, token) ->
        [%{mention_type: mention_type, user_id: nil, group_id: nil}]

      user = Map.get(users_by_username, token) ->
        [%{mention_type: :user, user_id: user.id, group_id: nil}]

      group = Map.get(groups_by_slug, token) ->
        [%{mention_type: :group, group_id: group.id, user_id: nil}]

      true ->
        # Unresolved token — not a user or group, skip it
        []
    end
  end
end
