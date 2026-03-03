defmodule CromulentWeb.Components.VoiceBar do
  use Phoenix.Component

  attr :voice_channel, :any, required: true
  attr :connection_state, :atom, default: :connecting
  attr :muted, :boolean, default: false
  attr :deafened, :boolean, default: false
  attr :voice_mode, :string, default: "ptt"

  def voice_bar(assigns) do
    ~H"""
    <div class="px-3 py-3 border-t border-gray-700 bg-gray-900">
      <%!-- Top row: connection status + disconnect button --%>
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center gap-2 min-w-0">
          <div class={[
            "w-2 h-2 rounded-full flex-shrink-0",
            @connection_state == :connecting && "bg-yellow-500",
            @connection_state == :connected && "bg-green-500",
            @connection_state == :disconnected && "bg-red-500"
          ]}></div>
          <span class={[
            "text-sm font-medium truncate",
            @connection_state == :connecting && "text-yellow-500",
            @connection_state == :connected && "text-green-500",
            @connection_state == :disconnected && "text-red-500"
          ]}>
            <%= case @connection_state do %>
              <% :connecting -> %>Connecting...
              <% :connected -> %>{@voice_channel.name}
              <% :disconnected -> %>Disconnected
              <% _ -> %>Connecting...
            <% end %>
          </span>
        </div>
        <button
          phx-click="leave_voice"
          class="p-1.5 text-gray-400 hover:text-red-400 rounded hover:bg-gray-700"
          title="Disconnect"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 8l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2M5 3a2 2 0 00-2 2v1c0 8.284 6.716 15 15 15h1a2 2 0 002-2v-3.28a1 1 0 00-.684-.948l-4.493-1.498a1 1 0 00-1.21.502l-1.13 2.257a11.042 11.042 0 01-5.516-5.517l2.257-1.128a1 1 0 00.502-1.21L9.228 3.683A1 1 0 008.279 3H5z" />
          </svg>
        </button>
      </div>

      <%!-- Middle row: Mute + Deafen buttons --%>
      <div class="flex gap-2 mb-2">
        <button
          phx-click="toggle_mute"
          class={[
            "flex-1 flex items-center justify-center gap-1.5 px-3 py-1.5 rounded text-xs font-medium transition-colors",
            if(@muted,
              do: "bg-red-600 hover:bg-red-700 text-white",
              else: "bg-gray-700 hover:bg-gray-600 text-gray-300"
            )
          ]}
          title={if @muted, do: "Unmute", else: "Mute"}
        >
          <%= if @muted do %>
            <%!-- Mic-slash: microphone with line through --%>
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M7 4a3 3 0 016 0v6a3 3 0 11-6 0V4z"/>
              <path d="M5.5 9.643a.75.75 0 00-1.5 0V10a6 6 0 0012 0v-.357a.75.75 0 00-1.5 0V10a4.5 4.5 0 01-9 0v-.357z"/>
              <path d="M3 3l14 14" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            </svg>
          <% else %>
            <%!-- Mic icon --%>
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path d="M7 4a3 3 0 016 0v6a3 3 0 11-6 0V4z"/>
              <path d="M5.5 9.643a.75.75 0 00-1.5 0V10a6 6 0 0012 0v-.357a.75.75 0 00-1.5 0V10a4.5 4.5 0 01-9 0v-.357z"/>
            </svg>
          <% end %>
          {if @muted, do: "Unmute", else: "Mute"}
        </button>

        <button
          phx-click="toggle_deafen"
          class={[
            "flex-1 flex items-center justify-center gap-1.5 px-3 py-1.5 rounded text-xs font-medium transition-colors",
            if(@deafened,
              do: "bg-red-600 hover:bg-red-700 text-white",
              else: "bg-gray-700 hover:bg-gray-600 text-gray-300"
            )
          ]}
          title={if @deafened, do: "Undeafen", else: "Deafen"}
        >
          <%!-- Headphone/speaker icon --%>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.114 5.636a9 9 0 010 12.728M16.463 8.288a5.25 5.25 0 010 7.424M6.75 8.25l4.72-4.72a.75.75 0 011.28.53v15.88a.75.75 0 01-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.01 9.01 0 012.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75z" />
          </svg>
          {if @deafened, do: "Undeafen", else: "Deafen"}
        </button>
      </div>

      <%!-- Bottom: PTT button or VAD label --%>
      <%= if @voice_mode == "ptt" do %>
        <button
          id="ptt-button"
          class="w-full select-none touch-none px-4 py-2 rounded bg-gray-700 text-gray-300 text-sm font-medium active:bg-green-600 active:text-white"
          data-active="false"
        >
          Push to Talk
        </button>
      <% else %>
        <div class="w-full px-4 py-2 rounded bg-gray-800 text-gray-500 text-sm text-center">
          Voice Activity
        </div>
      <% end %>
    </div>
    """
  end
end
