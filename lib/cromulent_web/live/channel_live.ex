defmodule CromulentWeb.ChannelLive do
  use CromulentWeb, :live_view
  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}

  def mount(%{"id" => channel_id}, _session, socket) do
    channel = Cromulent.Channels.get_channel(channel_id)

    token = Phoenix.Token.sign(
      CromulentWeb.Endpoint,
      "user socket",
      socket.assigns.current_user.id
    )

    {:ok, assign(socket,
      channel: channel,
      user_token: token,
      user_id: socket.assigns.current_user.id
    )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h2><%= @channel.name %></h2>

      <%= if @channel.type == :voice do %>
        <div
          id="voice-room"
          data-user-token={@user_token}
          data-user-id={@user_id}
          data-channel-id={@channel.id}
          phx-hook="VoiceRoom"
        >
          <!-- voice UI: participant list, mute button, etc -->
        </div>
      <% else %>
        <!-- text chat UI -->
      <% end %>
    </div>
    """
  end
end
