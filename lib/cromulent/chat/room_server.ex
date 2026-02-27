# lib/cromulent/chat/room_server.ex

defmodule Cromulent.Chat.RoomServer do
  use GenServer

  alias Phoenix.PubSub

  @type state :: %{
          channel_id: integer(),
          typing_timers: %{integer() => reference()}
        }

  def ensure_started(channel_id) do
    case DynamicSupervisor.start_child(
           Cromulent.RoomSupervisor,
           {__MODULE__, channel_id}
         ) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end

  # ── Public API ──────────────────────────────────────────────

  def start_link(channel_id) do
    GenServer.start_link(__MODULE__, channel_id, name: via(channel_id))
  end

  def broadcast_message(channel_id, message, notified_user_ids \\ []) do
    GenServer.cast(via(channel_id), {:broadcast_message, message, notified_user_ids})
  end

  def broadcast_message_deleted(channel_id, message_id) do
    GenServer.cast(via(channel_id), {:broadcast_message_deleted, message_id})
  end

  def typing_start(channel_id, user_id, username) do
    GenServer.cast(via(channel_id), {:typing_start, user_id, username})
  end

  def typing_stop(channel_id, user_id) do
    GenServer.cast(via(channel_id), {:typing_stop, user_id})
  end

  # ── GenServer callbacks ──────────────────────────────────────

  @impl true
  def init(channel_id) do
    {:ok, %{channel_id: channel_id, typing_timers: %{}}}
  end

  @impl true
  def handle_cast({:broadcast_message, message, notified_user_ids}, state) do
    PubSub.broadcast(Cromulent.PubSub, topic(state.channel_id), {:new_message, message})

    member_ids =
      Cromulent.Channels.list_channel_member_ids(state.channel_id)

    for user_id <- member_ids do
      PubSub.broadcast(Cromulent.PubSub, "user:#{user_id}", {:unread_changed})
    end

    for user_id <- notified_user_ids do
      PubSub.broadcast(Cromulent.PubSub, "user:#{user_id}", {:mention_changed})
    end

    # Broadcast desktop notifications to mentioned users
    channel = Cromulent.Channels.get_channel(state.channel_id)

    for user_id <- notified_user_ids do
      notification_data = %{
        channel_id: state.channel_id,
        channel_name: channel.name,
        channel_slug: channel.slug,
        author: message.user.username,
        message_preview: String.slice(message.body, 0..100),
        notification_id: message.id
      }

      PubSub.broadcast(Cromulent.PubSub, "user:#{user_id}", {:desktop_notification, notification_data})
    end

    {:noreply, state}
  end

  def handle_cast({:broadcast_message_deleted, message_id}, state) do
    PubSub.broadcast(Cromulent.PubSub, topic(state.channel_id), {:message_deleted, message_id})
    {:noreply, state}
  end

  def handle_cast({:typing_start, user_id, username}, state) do
    # Cancel existing timer for this user if any
    state = cancel_typing_timer(state, user_id)

    # Broadcast that they're typing
    PubSub.broadcast(Cromulent.PubSub, topic(state.channel_id), {:typing, user_id, username})

    # Auto-clear after 3 seconds if they go quiet
    timer = Process.send_after(self(), {:typing_timeout, user_id}, 3_000)
    state = put_in(state.typing_timers[user_id], timer)

    {:noreply, state}
  end

  def handle_cast({:typing_stop, user_id}, state) do
    state = cancel_typing_timer(state, user_id)
    PubSub.broadcast(Cromulent.PubSub, topic(state.channel_id), {:typing_stopped, user_id})
    {:noreply, state}
  end

  @impl true
  def handle_info({:typing_timeout, user_id}, state) do
    state = cancel_typing_timer(state, user_id)
    PubSub.broadcast(Cromulent.PubSub, topic(state.channel_id), {:typing_stopped, user_id})
    {:noreply, state}
  end

  # ── Private ──────────────────────────────────────────────────

  defp via(channel_id) do
    {:via, Registry, {Cromulent.RoomRegistry, channel_id}}
  end

  defp topic(channel_id), do: "text:#{channel_id}"

  defp cancel_typing_timer(state, user_id) do
    case Map.get(state.typing_timers, user_id) do
      nil ->
        state

      timer ->
        Process.cancel_timer(timer)
        update_in(state.typing_timers, &Map.delete(&1, user_id))
    end
  end
end
