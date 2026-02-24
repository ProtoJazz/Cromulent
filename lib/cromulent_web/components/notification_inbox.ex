defmodule CromulentWeb.Components.NotificationInbox do
  use CromulentWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="relative">
      <button
        phx-click="toggle_inbox"
        phx-target={@myself}
        class="relative p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded"
        title="Notifications"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
          />
        </svg>
        <span
          :if={@unread_count > 0}
          class="absolute -top-1 -right-1 inline-flex items-center justify-center w-4 h-4 text-[10px] font-bold leading-none text-white bg-red-600 rounded-full"
        >
          {if @unread_count > 99, do: "99+", else: @unread_count}
        </span>
      </button>

      <div
        :if={@inbox_open}
        class="absolute right-0 mt-2 w-96 bg-gray-800 border border-gray-700 rounded-lg shadow-xl z-50 max-h-96 overflow-y-auto"
        phx-click-away="close_inbox"
        phx-target={@myself}
      >
        <div class="flex items-center justify-between px-4 py-3 border-b border-gray-700">
          <h3 class="text-sm font-semibold text-white">Notifications</h3>
          <button
            :if={@unread_count > 0}
            phx-click="mark_all_read"
            phx-target={@myself}
            class="text-xs text-indigo-400 hover:text-indigo-300"
          >
            Mark all read
          </button>
        </div>

        <div :if={@notifications == []} class="px-4 py-8 text-center text-gray-400 text-sm">
          No notifications yet
        </div>

        <div :if={@notifications != []} class="divide-y divide-gray-700">
          <div
            :for={notif <- @notifications}
            phx-click="navigate_to_notification"
            phx-value-channel-slug={notif.channel_slug}
            phx-target={@myself}
            class="px-4 py-3 hover:bg-gray-700 cursor-pointer"
          >
            <div class="flex items-start gap-3">
              <div class="flex-shrink-0 w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center text-white text-xs font-medium">
                {String.first(notif.author) |> String.upcase()}
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm text-white font-medium">
                  <span>{notif.author}</span>
                  <span class="text-gray-400 font-normal"> in </span>
                  <span class="text-indigo-400">#{notif.channel_name}</span>
                </p>
                <p class="text-xs text-gray-400 mt-1 line-clamp-2">
                  {notif.message_preview}
                </p>
                <p class="text-xs text-gray-500 mt-1">
                  {format_time(notif.inserted_at)}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if connected?(socket) do
      notifications =
        Cromulent.Notifications.list_unread_notifications(assigns.current_user.id)

      {:ok,
       socket
       |> assign(:notifications, notifications)
       |> assign(:unread_count, length(notifications))
       |> assign_new(:inbox_open, fn -> false end)}
    else
      {:ok,
       socket
       |> assign(:notifications, [])
       |> assign(:unread_count, 0)
       |> assign_new(:inbox_open, fn -> false end)}
    end
  end

  def handle_event("toggle_inbox", _params, socket) do
    {:noreply, assign(socket, :inbox_open, !socket.assigns.inbox_open)}
  end

  def handle_event("close_inbox", _params, socket) do
    {:noreply, assign(socket, :inbox_open, false)}
  end

  def handle_event("mark_all_read", _params, socket) do
    Cromulent.Notifications.mark_all_read(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(:notifications, [])
     |> assign(:unread_count, 0)}
  end

  def handle_event("navigate_to_notification", %{"channel-slug" => slug}, socket) do
    send(self(), {:navigate_to_channel, slug})
    {:noreply, assign(socket, :inbox_open, false)}
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end
end
