defmodule CromulentWeb.LobbyLive do
  use CromulentWeb, :live_view
  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-full">
      <div class="text-center">
        <h1 class="text-3xl font-bold text-white mb-2">Welcome to Cromulent</h1>
        <p class="text-gray-400">Select a channel from the sidebar to get started.</p>
      </div>
    </div>
    """
  end
end
