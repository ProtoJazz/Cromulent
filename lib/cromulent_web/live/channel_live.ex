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
        Cromulent.Messages.list_messages(channel_id, socket.assigns.current_user)
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
        <div class="flex flex-col h-screen fixed inset-0 lg:left-64">
          <%!-- Message list --%>
          <div class="flex-1 overflow-y-auto py-4 space-y-1">
            <.message :for={msg <- @messages} message={msg} current_user={@current_user} />
          </div>

          <%!-- Message input --%>
          <div class="flex-shrink-0 border-t border-gray-700 bg-gray-800">
            <div class="flex items-center gap-2 px-4 py-3">
              <input
                type="text"
                placeholder={"Message ##{@channel.name |> String.replace("# ", "")}"}
                class="block w-full border-0 bg-gray-800 px-0 text-sm text-white placeholder:text-gray-400 focus:ring-0"
              />
              <button type="submit" class="inline-flex cursor-pointer justify-center rounded-full p-2 text-indigo-500 hover:bg-gray-700">
                <svg class="h-5 w-5 rotate-90" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 18 20">
                  <path d="m17.914 18.594-8-18a1 1 0 0 0-1.828 0l-8 18a1 1 0 0 0 1.157 1.376L8 18.281V9a1 1 0 0 1 2 0v9.281l6.758 1.689a1 1 0 0 0 1.156-1.376Z" />
                </svg>
                <span class="sr-only">Send message</span>
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
