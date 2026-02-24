defmodule CromulentWeb.ChannelLive do
  use CromulentWeb, :live_view
  alias Cromulent.Chat.RoomServer
  alias Cromulent.Repo
  import CromulentWeb.Components.MessageComponent
  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    token =
      Phoenix.Token.sign(
        CromulentWeb.Endpoint,
        "user socket",
        socket.assigns.current_user.id
      )

    {:ok,
     assign(socket,
       user_token: token,
       user_id: socket.assigns.current_user.id,
       channel: nil,
       messages: [],
       typing_users: %{},
       can_write: nil,
       join_modal_type: nil
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
    assign(
      socket,
      :unread_counts,
      Cromulent.Notifications.unread_counts_for_user(socket.assigns.current_user.id)
    )
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
      case Cromulent.Messages.create_message(
             socket.assigns.current_user,
             socket.assigns.channel,
             %{
               channel_id: socket.assigns.channel.id,
               user_id: socket.assigns.current_user.id,
               body: body
             }
           ) do
        {:ok, message} ->
          message = Repo.preload(message, :user)
          RoomServer.broadcast_message(socket.assigns.channel.id, message)
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
    channel = Cromulent.Channels.get_channel(channel_id)
    Cromulent.VoiceState.join(socket.assigns.current_user.id, channel)

    {:noreply,
     socket
     |> assign(:voice_channel, channel)
     |> push_event("voice:join", %{
       channel_id: channel_id,
       user_token: socket.assigns.user_token,
       user_id: socket.assigns.user_id
     })}
  end

  def handle_event("leave_voice", _params, socket) do
    Cromulent.VoiceState.leave(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(:voice_channel, nil)
     |> push_event("voice:leave", %{})}
  end

  def handle_event("open_join_modal", %{"type" => type}, socket) do
    {:noreply, assign(socket, :join_modal_type, String.to_existing_atom(type))}
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

  def handle_info(_, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
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
      <div class="flex-shrink-0 border-t border-gray-700 bg-gray-800">
        <%= if @can_write do %>
          <form phx-submit="send_message" class="flex items-center gap-2 px-4 h-12">
            <input
              type="text"
              name="body"
              placeholder={"Message ##{@channel.name}"}
              class="block w-full border-0 bg-gray-800 px-0 text-sm text-white placeholder:text-gray-400 focus:ring-0"
              autocomplete="off"
              value=""
              id={"msg-input-#{length(@messages)}"}
              phx-keydown="typing_start"
              phx-blur="typing_stop"
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
        <% else %>
          <div class="flex items-center px-4 h-12">
            <p class="text-sm text-gray-500 italic">This channel is read-only.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
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
