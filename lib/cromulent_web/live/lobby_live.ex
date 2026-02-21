defmodule CromulentWeb.LobbyLive do
  use CromulentWeb, :live_view
  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do

    first_text_channel =
      Cromulent.Channels.list_visible_channels(socket.assigns.current_user)
      |> Enum.find(&(&1.type == :text))

    {:ok, push_navigate(socket, to: ~p"/channels/#{first_text_channel.slug}")}
  end
end
