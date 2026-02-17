defmodule CromulentWeb.Components.MessageComponent do
  use Phoenix.Component

  attr :message, :map, required: true

  def message(assigns) do
    user = assigns.message.user
    initial = user.email |> String.first() |> String.upcase()
    display_name = user.email |> String.split("@") |> List.first()
    timestamp = Calendar.strftime(assigns.message.inserted_at, "%I:%M %p")

    assigns =
      assigns
      |> assign(:initial, initial)
      |> assign(:display_name, display_name)
      |> assign(:timestamp, timestamp)

    ~H"""
    <div class="flex items-start px-4 py-2 hover:bg-gray-800/50 group">
      <div class="w-10 h-10 rounded-full bg-indigo-600 flex items-center justify-center text-white text-sm font-medium flex-shrink-0 mt-0.5">
        {@initial}
      </div>
      <div class="ml-3 min-w-0">
        <div class="flex items-baseline gap-2">
          <span class="text-sm font-semibold text-white">{@display_name}</span>
          <span class="text-xs text-gray-500">{@timestamp}</span>
        </div>
        <p class="text-sm text-gray-300">{@message.body}</p>
      </div>
    </div>
    """
  end
end
