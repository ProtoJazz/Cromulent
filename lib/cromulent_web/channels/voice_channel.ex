defmodule CromulentWeb.VoiceChannel do
  use Phoenix.Channel

  def join("voice:" <> channel_id, _params, socket) do
    channel = Cromulent.Channels.get_channel(channel_id)

    if channel && channel.type == :voice do
      send(self(), :after_join)
      {:ok, assign(socket, :channel_id, channel_id)}
    else
      {:error, %{reason: "not found"}}
    end
  end

  # After join, tell everyone else a new peer arrived
def handle_info(:after_join, socket) do
  IO.puts("🔊 after_join firing for user #{socket.assigns.current_user.id}")
  broadcast_from!(socket, "peer_joined", %{
    user_id: socket.assigns.current_user.id
  })
  {:noreply, socket}
end
  # Relay SDP offer to a specific peer
  def handle_in("sdp_offer", %{"to" => to, "sdp" => sdp}, socket) do
    CromulentWeb.Endpoint.broadcast("voice:#{socket.assigns.channel_id}", "sdp_offer", %{
      from: socket.assigns.current_user.id,
      to: to,
      sdp: sdp
    })
    {:noreply, socket}
  end

  # Relay SDP answer
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

  # Relay ICE candidates
  def handle_in("ice_candidate", %{"to" => to, "candidate" => candidate}, socket) do
    CromulentWeb.Endpoint.broadcast("voice:#{socket.assigns.channel_id}", "ice_candidate", %{
      from: socket.assigns.current_user.id,
      to: to,
      candidate: candidate
    })
    {:noreply, socket}
  end

  # Notify peers when someone leaves
  def terminate(_reason, socket) do
    broadcast_from!(socket, "peer_left", %{
      user_id: socket.assigns.current_user.id
    })
  end
end
