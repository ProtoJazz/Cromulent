defmodule CromulentWeb.ChannelLive do
  use CromulentWeb, :live_view
  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}

  def mount(%{"id" => channel_id}, _session, socket) do
    channel = Cromulent.Channels.get_channel(channel_id)

    token =
      Phoenix.Token.sign(
        CromulentWeb.Endpoint,
        "user socket",
        socket.assigns.current_user.id
      )

    {:ok,
     assign(socket,
       channel: channel,
       user_token: token,
       user_id: socket.assigns.current_user.id
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h2>{@channel.name}</h2>

      <%= if @channel.type == :voice do %>
        <div
          id="voice-room"
          data-user-token={@user_token}
          data-user-id={@user_id}
          data-channel-id={@channel.id}
          phx-hook="VoiceRoom"
        >
          <!-- voice UI: participant list, mute button, etc -->
          <button
            id="ptt-button"
            class="select-none touch-none px-8 py-6 rounded-full bg-gray-600 text-white font-bold text-lg active:bg-green-500"
            data-active="false"
          >
            🎙️ Hold to Talk
          </button>
        </div>
      <% else %>
        <!-- text chat UI -->
      <% end %>
    </div>
    """
  end
end
