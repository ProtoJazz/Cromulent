defmodule CromulentWeb.Components.VoiceBar do
  use Phoenix.Component

  attr :voice_channel, :any, required: true

  def voice_bar(assigns) do
    ~H"""
    <div class="px-3 py-3 border-t border-gray-700 bg-gray-900">
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center gap-2 min-w-0">
          <div class="w-2 h-2 rounded-full bg-green-500 flex-shrink-0"></div>
          <span class="text-sm font-medium text-green-500 truncate">{@voice_channel.name}</span>
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
      <button
        id="ptt-button"
        class="w-full select-none touch-none px-4 py-2 rounded bg-gray-700 text-gray-300 text-sm font-medium active:bg-green-600 active:text-white"
        data-active="false"
      >
        Push to Talk
      </button>
    </div>
    """
  end
end
