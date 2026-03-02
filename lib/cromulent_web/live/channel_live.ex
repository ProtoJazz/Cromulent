defmodule CromulentWeb.ChannelLive do
  use CromulentWeb, :live_view
  alias Cromulent.Chat.RoomServer
  import CromulentWeb.Components.MessageComponent
  import CromulentWeb.Components.MentionAutocomplete
  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    token =
      Phoenix.Token.sign(
        CromulentWeb.Endpoint,
        "user socket",
        socket.assigns.current_user.id
      )

    # Subscribe to user-specific PubSub topic for desktop notifications
    Phoenix.PubSub.subscribe(Cromulent.PubSub, "user:#{socket.assigns.current_user.id}")

    {:ok,
     assign(socket,
       user_token: token,
       user_id: socket.assigns.current_user.id,
       channel: nil,
       messages: [],
       typing_users: %{},
       can_write: nil,
       join_modal_type: nil,
       mention_counts: %{},
       autocomplete_open: false,
       autocomplete_query: "",
       autocomplete_results: [],
       autocomplete_index: 0,
       voice_channel: nil,
       voice_connection_state: nil
     )}
  end

  def handle_params(%{"slug" => slug}, _uri, socket) do
    if socket.assigns.channel do
      Phoenix.PubSub.unsubscribe(Cromulent.PubSub, "text:#{socket.assigns.channel.id}")
    end

    channel = Cromulent.Channels.get_channel_by_slug(slug)
    messages = Cromulent.Messages.list_messages(channel.id)
    can_write = Cromulent.Channels.can_write?(socket.assigns.current_user, channel)

    RoomServer.ensure_started(channel.id)
    Phoenix.PubSub.subscribe(Cromulent.PubSub, "text:#{channel.id}")

    if latest = List.last(messages) do
      Cromulent.Notifications.mark_channel_read(
        socket.assigns.current_user.id,
        channel.id,
        latest.id
      )
    end

    {:noreply,
     socket
     |> assign(
       channel: channel,
       messages: messages,
       oldest_id: List.first(messages) && List.first(messages).id,
       all_loaded: length(messages) < 50,
       can_write: can_write
     )
     |> refresh_unread_counts()}
  end

  defp refresh_unread_counts(socket) do
    user_id = socket.assigns.current_user.id

    socket
    |> assign(:unread_counts, Cromulent.Notifications.unread_counts_for_user(user_id))
    |> assign(:mention_counts, Cromulent.Notifications.mention_counts_for_user(user_id))
  end

  def handle_event("load_more", _params, %{assigns: %{all_loaded: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("load_more", _params, socket) do
    older =
      Cromulent.Messages.list_messages_before(
        socket.assigns.channel.id,
        socket.assigns.oldest_id
      )

    case older do
      [] ->
        {:noreply, assign(socket, all_loaded: true)}

      msgs ->
        {:noreply,
         socket
         |> assign(:messages, msgs ++ socket.assigns.messages)
         |> assign(:oldest_id, List.first(msgs).id)
         |> assign(:all_loaded, length(msgs) < 50)}
    end
  end

  def handle_event("send_message", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to post in this channel.")}
  end

  def handle_event("send_message", %{"body" => ""}, socket), do: {:noreply, socket}

  def handle_event("send_message", %{"body" => body}, socket) do
    body = String.trim(body)

    if body != "" do
      online_user_ids =
        CromulentWeb.Presence.list("server:all")
        |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta.user_id end)

      case Cromulent.Messages.create_message(
             socket.assigns.current_user,
             socket.assigns.channel,
             %{
               channel_id: socket.assigns.channel.id,
               user_id: socket.assigns.current_user.id,
               body: body
             },
             online_user_ids
           ) do
        {:ok, {message, notified_user_ids}} ->
          RoomServer.broadcast_message(socket.assigns.channel.id, message, notified_user_ids)
          {:noreply, assign(socket, message_input: "")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not send message.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("typing_start", _params, socket) do
    RoomServer.typing_start(
      socket.assigns.channel.id,
      socket.assigns.current_user.id,
      socket.assigns.current_user.email
    )

    {:noreply, socket}
  end

  def handle_event("typing_stop", _params, socket) do
    RoomServer.typing_stop(socket.assigns.channel.id, socket.assigns.current_user.id)
    {:noreply, socket}
  end

  def handle_event("join_voice", %{"channel-id" => channel_id}, socket) do
    # Cross-channel auto-leave: if already in a voice channel, push leave event first.
    # Both events arrive in the same LiveView batch; JS processes them in order.
    socket =
      if socket.assigns[:voice_channel] do
        push_event(socket, "voice:leave", %{})
      else
        socket
      end

    channel = Cromulent.Channels.get_channel(channel_id)
    Cromulent.VoiceState.join(socket.assigns.current_user.id, channel)

    ice_servers =
      case get_ice_servers(socket.assigns.current_user.id) do
        {:ok, servers} -> servers
        # Graceful fallback: TURN credential failure falls back to STUN-only.
        # Voice still works on most networks; only restrictive NATs are affected.
        {:error, _reason} -> [%{urls: "stun:stun.l.google.com:19302"}]
      end

    {:noreply,
     socket
     |> assign(:voice_channel, channel)
     |> assign(:voice_connection_state, :connecting)
     |> push_event("voice:join", %{
       channel_id: channel_id,
       user_token: socket.assigns.user_token,
       user_id: socket.assigns.user_id,
       ice_servers: ice_servers
     })}
  end

  def handle_event("leave_voice", _params, socket) do
    Cromulent.VoiceState.leave(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(:voice_channel, nil)
     |> assign(:voice_connection_state, nil)
     |> push_event("voice:leave", %{})}
  end

  def handle_event("voice_state_changed", %{"state" => state}, socket) do
    connection_state =
      case state do
        "connected" -> :connected
        "disconnected" -> :disconnected
        _ -> socket.assigns[:voice_connection_state]
      end

    {:noreply, assign(socket, :voice_connection_state, connection_state)}
  end

  def handle_event("open_join_modal", %{"type" => type}, socket) do
    {:noreply, assign(socket, :join_modal_type, String.to_existing_atom(type))}
  end

  def handle_event("delete_message", %{"id" => id}, socket) do
    case Cromulent.Messages.delete_message(socket.assigns.current_user, id) do
      {:ok, _} ->
        Cromulent.Chat.RoomServer.broadcast_message_deleted(socket.assigns.channel.id, id)
        {:noreply, socket}

      {:error, :permission_denied} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to delete that message.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete message.")}
    end
  end

  def handle_event("autocomplete_open", %{"query" => query}, socket) do
    results = filter_mention_targets(socket.assigns.channel, query)

    {:noreply,
     assign(socket,
       autocomplete_open: true,
       autocomplete_query: query,
       autocomplete_results: results,
       autocomplete_index: 0
     )}
  end

  def handle_event("autocomplete_close", _params, socket) do
    {:noreply,
     assign(socket,
       autocomplete_open: false,
       autocomplete_query: "",
       autocomplete_results: [],
       autocomplete_index: 0
     )}
  end

  def handle_event("autocomplete_navigate", %{"direction" => direction}, socket) do
    results_length = length(socket.assigns.autocomplete_results)
    current_index = socket.assigns.autocomplete_index

    new_index =
      case direction do
        "up" -> max(0, current_index - 1)
        "down" -> min(results_length - 1, current_index + 1)
        _ -> current_index
      end

    {:noreply, assign(socket, autocomplete_index: new_index)}
  end

  def handle_event("autocomplete_select", %{"index" => index}, socket) do
    index = if is_binary(index), do: String.to_integer(index), else: index
    results = socket.assigns.autocomplete_results

    case Enum.at(results, index) do
      nil ->
        {:noreply, socket}

      item ->
        mention_text = format_mention(item)

        {:noreply,
         socket
         |> push_event("mention_selected", %{text: mention_text})
         |> assign(
           autocomplete_open: false,
           autocomplete_query: "",
           autocomplete_results: [],
           autocomplete_index: 0
         )}
    end
  end

  def handle_event("navigate-to-channel", %{"channel_slug" => slug}, socket) do
    {:noreply, push_patch(socket, to: ~p"/channels/#{slug}")}
  end

  def handle_info({:message_deleted, message_id}, socket) do
    {:noreply, update(socket, :messages, &Enum.reject(&1, fn m -> m.id == message_id end))}
  end

  def handle_info(:close_join_modal, socket) do
    {:noreply, assign(socket, :join_modal_type, nil)}
  end

  def handle_info({:channel_joined, channel}, socket) do
    if channel.type == :voice do
      Phoenix.PubSub.subscribe(Cromulent.PubSub, "voice:#{channel.id}")
    end

    channels = Cromulent.Channels.list_joined_channels(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:channels, channels)
     |> assign(:join_modal_type, nil)
     |> put_flash(:info, "Channel joined!")}
  end

  def handle_info({:new_message, message}, socket) do
    Cromulent.Notifications.mark_channel_read(
      socket.assigns.current_user.id,
      socket.assigns.channel.id,
      message.id
    )

    socket =
      socket
      |> update(:messages, &(&1 ++ [message]))
      |> push_event("chat:new_message", %{})
      |> refresh_unread_counts()

    {:noreply, socket}
  end

  def handle_info({:typing, user_id, username}, socket) do
    {:noreply, update(socket, :typing_users, &Map.put(&1, user_id, username))}
  end

  def handle_info({:typing_stopped, user_id}, socket) do
    {:noreply, update(socket, :typing_users, &Map.delete(&1, user_id))}
  end

  def handle_info({:unread_changed}, socket) do
    {:noreply, refresh_unread_counts(socket)}
  end

  def handle_info({:mention_changed}, socket) do
    send_update(CromulentWeb.Components.NotificationInbox,
      id: "notification-inbox",
      current_user: socket.assigns.current_user
    )

    {:noreply, refresh_unread_counts(socket)}
  end

  def handle_info({:navigate_to_channel, slug}, socket) do
    {:noreply, push_patch(socket, to: ~p"/channels/#{slug}")}
  end

  def handle_info({:desktop_notification, data}, socket) do
    # Only push desktop notification if user is NOT viewing the mentioned channel
    if socket.assigns.channel == nil or socket.assigns.channel.id != data.channel_id do
      {:noreply, push_event(socket, "desktop-notification", data)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:link_preview, msg_id, preview}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn
        %{id: ^msg_id} = m -> Map.put(m, :link_preview, preview)
        m -> m
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <%!-- Notification handler --%>
      <div id="notification-handler" phx-hook="NotificationHandler" class="hidden"></div>

      <%!-- Message list --%>
      <div id="message-list" class="flex-1 overflow-y-auto py-4 space-y-1" phx-hook="ChatScroll">
        <.message :for={msg <- @messages} message={msg} current_user={@current_user} />
      </div>

      <div id="scroll-to-bottom-btn" class="hidden absolute bottom-20 left-1/2 -translate-x-1/2">
        <button
          onclick="window.chatScroll.scrollToBottom(true)"
          class="flex items-center gap-2 px-3 py-1.5 rounded-full bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-medium shadow-lg transition-all"
        >
          <svg class="h-3 w-3" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
              clip-rule="evenodd"
            />
          </svg>
          New messages
        </button>
      </div>

      <%!-- Typing indicator --%>
      <div class="flex-shrink-0 px-4 h-5 flex items-center">
        <span class="text-xs text-gray-400 italic">
          {typing_text(@typing_users, @current_user.id)}
        </span>
      </div>

      <%!-- Message input --%>
      <div class="flex-shrink-0 border-t border-gray-700 bg-gray-800 relative">
        <%= if @can_write do %>
          <div
            id="mention-hook"
            phx-hook="MentionAutocomplete"
            data-selected-index={@autocomplete_index}
          >
            <.mention_autocomplete
              open={@autocomplete_open}
              results={@autocomplete_results}
              selected_index={@autocomplete_index}
            />
            <form phx-submit="send_message" class="flex items-center gap-2 px-4 h-12">
              <input
                type="text"
                name="body"
                placeholder={"Message ##{@channel.name}"}
                class="block w-full border-0 bg-gray-800 px-0 text-sm text-white placeholder:text-gray-400 focus:ring-0"
                autocomplete="off"
                value=""
                id="msg-input"
                phx-keydown="typing_start"
                phx-blur="typing_stop"
                role="combobox"
                aria-autocomplete="list"
                aria-controls="mention-listbox"
                aria-expanded={@autocomplete_open}
              />
              <button
                type="submit"
                class="inline-flex cursor-pointer justify-center rounded-full p-2 text-indigo-500 hover:bg-gray-700"
              >
                <svg
                  class="h-5 w-5 rotate-90"
                  aria-hidden="true"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="currentColor"
                  viewBox="0 0 18 20"
                >
                  <path d="m17.914 18.594-8-18a1 1 0 0 0-1.828 0l-8 18a1 1 0 0 0 1.157 1.376L8 18.281V9a1 1 0 0 1 2 0v9.281l6.758 1.689a1 1 0 0 0 1.156-1.376Z" />
                </svg>
                <span class="sr-only">Send message</span>
              </button>
            </form>
          </div>
        <% else %>
          <div class="flex items-center px-4 h-12">
            <p class="text-sm text-gray-500 italic">This channel is read-only.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp filter_mention_targets(channel, query) do
    query_lower = String.downcase(query)

    # Fetch channel members and groups
    members = Cromulent.Channels.list_members(channel)
    groups = Cromulent.Groups.list_groups()

    # Build broadcast targets
    broadcast_targets = [
      %{type: :broadcast, token: "everyone", label: "@everyone", description: "Notify everyone in channel"},
      %{type: :broadcast, token: "here", label: "@here", description: "Notify all online users"}
    ]

    # Filter broadcast targets (show if query is empty or matches)
    filtered_broadcasts =
      if query_lower == "" do
        broadcast_targets
      else
        Enum.filter(broadcast_targets, fn bt ->
          String.starts_with?(bt.token, query_lower)
        end)
      end

    # Filter and rank users
    filtered_users =
      members
      |> Enum.filter(fn user ->
        username_lower = String.downcase(user.username)
        # Check if username starts with query or contains query
        String.starts_with?(username_lower, query_lower) or
          String.contains?(username_lower, query_lower)
      end)
      |> Enum.sort_by(fn user ->
        username_lower = String.downcase(user.username)

        cond do
          # Exact match first
          username_lower == query_lower -> 0
          # Prefix match on username second
          String.starts_with?(username_lower, query_lower) -> 1
          # Contains match last
          true -> 2
        end
      end)
      |> Enum.map(fn user ->
        %{type: :user, user: user}
      end)

    # Filter groups
    filtered_groups =
      groups
      |> Enum.filter(fn group ->
        slug_lower = String.downcase(group.slug)
        name_lower = String.downcase(group.name)

        String.starts_with?(slug_lower, query_lower) or
          String.contains?(name_lower, query_lower)
      end)
      |> Enum.map(fn group ->
        %{type: :group, group: group}
      end)

    # Combine: broadcasts first, then users, then groups
    filtered_broadcasts ++ filtered_users ++ filtered_groups
  end

  defp format_mention(item) do
    case item.type do
      :broadcast -> "@#{item.token} "
      :user -> "@#{item.user.username} "
      :group -> "@#{item.group.slug} "
    end
  end

  defp get_ice_servers(user_id) do
    case System.get_env("TURN_PROVIDER") do
      "coturn" -> Cromulent.Turn.Coturn.get_ice_servers(user_id)
      "metered" -> Cromulent.Turn.Metered.get_ice_servers(user_id)
      # No TURN_PROVIDER set = STUN-only mode (default, preserves existing behavior)
      _ -> {:ok, [%{urls: "stun:stun.l.google.com:19302"}]}
    end
  end

  defp typing_text(typing_users, current_user_id) do
    others =
      typing_users
      |> Map.delete(current_user_id)
      |> Map.values()

    case length(others) do
      0 -> ""
      1 -> "#{Enum.at(others, 0)} is typing..."
      2 -> "#{Enum.at(others, 0)} and #{Enum.at(others, 1)} are typing..."
      3 -> "#{Enum.at(others, 0)}, #{Enum.at(others, 1)}, and #{Enum.at(others, 2)} are typing..."
      _ -> "Several people are typing..."
    end
  end
end
