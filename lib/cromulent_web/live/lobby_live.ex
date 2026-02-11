defmodule CromulentWeb.LobbyLive do
  use CromulentWeb, :live_view
  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, channels: Cromulent.Channels.list_channels())}
  end

  def render(assigns) do
    ~H"""
    <div class="sidebar">
      <div :for={ch <- @channels} class="channel-item">
        <.link navigate={~p"/channels/#{ch.id}"}>
          <%= ch.name %>
        </.link>
      </div>
    </div>
    """
  end
end
