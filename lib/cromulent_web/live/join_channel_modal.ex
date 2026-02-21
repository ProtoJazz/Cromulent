defmodule CromulentWeb.JoinChannelModal do
  use CromulentWeb, :live_component

  alias Cromulent.Channels

  @impl true
  def update(%{current_user: user, channel_type: type} = assigns, socket) do
    joinable = Channels.list_joinable_channels(user, type)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:joinable_channels, joinable)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("join", %{"channel-id" => channel_id}, socket) do
    user = socket.assigns.current_user

    with channel when not is_nil(channel) <- Channels.get_channel(channel_id),
         {:ok, _} <- Channels.join_channel(user, channel) do
      # Notify parent to refresh channels
      send(self(), {:channel_joined, channel})
      {:noreply, socket |> assign(:error, nil)}
    else
      {:error, :private_channel} ->
        {:noreply, assign(socket, :error, "That channel is invite-only.")}

      nil ->
        {:noreply, assign(socket, :error, "Channel not found.")}

      _ ->
        {:noreply, assign(socket, :error, "Something went wrong.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center"
      role="dialog"
      aria-modal="true"
    >
      <%!-- Backdrop --%>
      <div
        class="absolute inset-0 bg-black/60"
        phx-click="close_join_modal"
        phx-target={@myself}
      />

      <%!-- Panel --%>
      <div class="relative z-10 w-full max-w-md mx-4 bg-gray-800 rounded-xl shadow-2xl border border-gray-700 overflow-hidden">
        <%!-- Header --%>
        <div class="px-5 py-4 border-b border-gray-700 flex items-center justify-between">
          <div>
            <h2 class="text-base font-semibold text-white">
              Browse <%= if @channel_type == :text, do: "Text", else: "Voice" %> Channels
            </h2>
            <p class="text-xs text-gray-400 mt-0.5">
              Channels you can join
            </p>
          </div>
          <button
            phx-click="close_join_modal"
            phx-target={@myself}
            class="text-gray-400 hover:text-white transition-colors rounded-md p-1 hover:bg-gray-700"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <%!-- Error --%>
        <%= if @error do %>
          <div class="mx-5 mt-3 px-3 py-2 bg-red-900/40 border border-red-700 rounded-lg text-sm text-red-300">
            {@error}
          </div>
        <% end %>

        <%!-- Channel list --%>
        <div class="px-3 py-3 max-h-80 overflow-y-auto">
          <%= if @joinable_channels == [] do %>
            <div class="py-10 text-center text-gray-500 text-sm">
              You're already in all available <%= if @channel_type == :text, do: "text", else: "voice" %> channels.
            </div>
          <% else %>
            <ul class="space-y-1">
              <li :for={ch <- @joinable_channels}>
                <div class="flex items-center justify-between px-3 py-2.5 rounded-lg hover:bg-gray-700 group">
                  <div class="flex items-center gap-2.5 min-w-0">
                    <%!-- Icon --%>
                    <%= if @channel_type == :text do %>
                      <svg class="w-4 h-4 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14" />
                      </svg>
                    <% else %>
                      <svg class="w-4 h-4 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                      </svg>
                    <% end %>

                    <span class="text-sm font-medium text-gray-200 truncate">
                      {ch.name}
                    </span>
                  </div>

                  <button
                    phx-click="join"
                    phx-value-channel-id={ch.id}
                    phx-target={@myself}
                    class="ml-3 flex-shrink-0 text-xs font-medium px-3 py-1 rounded-md bg-indigo-600 hover:bg-indigo-500 text-white transition-colors cursor-pointer"
                  >
                    Join
                  </button>
                </div>
              </li>
            </ul>
          <% end %>
        </div>

        <div class="px-5 py-3 border-t border-gray-700 text-xs text-gray-500">
          Private channels are invite-only and won't appear here.
        </div>
      </div>
    </div>
    """
  end

  # Let the parent close the modal via its own event handler
  def handle_event("close_join_modal", _, socket) do
    send(self(), :close_join_modal)
    {:noreply, socket}
  end
end
