defmodule CromulentWeb.VoiceChannel do
  use Phoenix.Channel
  alias CromulentWeb.Presence

  def join("voice:" <> channel_id, _params, socket) do
    channel = channel_id |> parse_id() |> Cromulent.Channels.get_channel()

    if channel && channel.type == :voice do
      presences = Presence.list("voice:#{channel_id}")
      user_key = to_string(socket.assigns.current_user.id)

      if Map.has_key?(presences, user_key) do
        # User already in this channel (rapid reconnect / multiple tabs).
        # Rely on Presence timeout to clear the old entry.
        {:error, %{reason: "already_in_channel"}}
      else
        send(self(), :after_join)
        {:ok, assign(socket, :channel_id, channel_id)}
      end
    else
      {:error, %{reason: "not found"}}
    end
  end

  def handle_info(:after_join, socket) do
    IO.puts("🔊 after_join firing for user #{socket.assigns.current_user.id}")
    broadcast_from!(socket, "peer_joined", %{
      user_id: socket.assigns.current_user.id
    })

    {:ok, _} = Presence.track(socket, socket.assigns.current_user.id, %{
      user_id: socket.assigns.current_user.id,
      email: socket.assigns.current_user.email,
      online_at: inspect(System.system_time(:second)),
      muted: false,
      deafened: false
    })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("toggle_mute", %{"muted" => muted}, socket) do
    Presence.update(socket, socket.assigns.current_user.id, fn meta ->
      Map.put(meta, :muted, muted)
    end)
    {:noreply, socket}
  end

  def handle_in("sdp_offer", %{"to" => to, "sdp" => sdp}, socket) do
    CromulentWeb.Endpoint.broadcast("voice:#{socket.assigns.channel_id}", "sdp_offer", %{
      from: socket.assigns.current_user.id,
      to: to,
      sdp: sdp
    })
    {:noreply, socket}
  end

  def handle_in("sdp_answer", %{"to" => to, "sdp" => sdp}, socket) do
    CromulentWeb.Endpoint.broadcast("voice:#{socket.assigns.channel_id}", "sdp_answer", %{
      from: socket.assigns.current_user.id,
      to: to,
      sdp: sdp
    })
    {:noreply, socket}
  end

  def handle_in("ptt_state", %{"active" => active}, socket) do
    broadcast_from!(socket, "ptt_state", %{
      user_id: socket.assigns.current_user.id,
      active: active
    })
    {:noreply, socket}
  end

  def handle_in("ice_candidate", %{"to" => to, "candidate" => candidate}, socket) do
    CromulentWeb.Endpoint.broadcast("voice:#{socket.assigns.channel_id}", "ice_candidate", %{
      from: socket.assigns.current_user.id,
      to: to,
      candidate: candidate
    })
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    broadcast_from!(socket, "peer_left", %{
      user_id: socket.assigns.current_user.id
    })
  end

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> id
    end
  end
end
