defmodule CromulentWeb.ChannelLive do
  use CromulentWeb, :live_view
  import CromulentWeb.Components.MessageComponent
  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}

  def mount(%{"id" => channel_id}, _session, socket) do
    channel = Cromulent.Channels.get_channel(channel_id)

    token =
      Phoenix.Token.sign(
        CromulentWeb.Endpoint,
        "user socket",
        socket.assigns.current_user.id
      )

    messages =
      if channel.type == :text do
        Cromulent.Messages.list_messages(channel_id)
      else
        []
      end

    {:ok,
     assign(socket,
       channel: channel,
       user_token: token,
       user_id: socket.assigns.current_user.id,
       messages: messages
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
        <div class="flex flex-col h-[calc(100vh-2rem)]">
          <%!-- Message list --%>
          <div class="flex-1 overflow-y-auto py-4">
            <div :for={msg <- @messages}>
              <.message message={msg} />
            </div>
          </div>

          <%!-- Message input --%>
          <div class="px-4 pb-4">
            <div class="flex items-center bg-gray-700 rounded-lg px-4 py-2">
              <input
                type="text"
                placeholder={"Message ##{@channel.name |> String.replace("# ", "")}"}
                class="flex-1 bg-transparent text-gray-200 placeholder-gray-400 border-none focus:ring-0 text-sm"
              />
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
