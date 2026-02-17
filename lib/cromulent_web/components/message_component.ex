defmodule CromulentWeb.Components.MessageComponent do
  use Phoenix.Component

  attr :message, :map, required: true
  attr :current_user, :any, required: true

  def message(assigns) do
    user = assigns.message.user
    initial = user.email |> String.first() |> String.upcase()
    display_name = user.email |> String.split("@") |> List.first()
    timestamp = Calendar.strftime(assigns.message.inserted_at, "%I:%M %p")
    is_own = user.id == assigns.current_user.id

    assigns =
      assigns
      |> assign(:initial, initial)
      |> assign(:display_name, display_name)
      |> assign(:timestamp, timestamp)
      |> assign(:is_own, is_own)

    ~H"""
    <%= if @is_own do %>
      <div class="group ms-auto flex max-w-[404px] items-start justify-end gap-2.5 px-4 py-2 hover:bg-gray-800/50">
        <div class="flex flex-col gap-1">
          <div class="flex items-center justify-end space-x-2">
            <span class="text-sm font-semibold text-white">{@display_name}</span>
            <span class="text-sm font-normal text-gray-400">{@timestamp}</span>
          </div>
          <div class="leading-1.5 ms-auto inline-flex flex-col rounded-s-xl rounded-ee-xl bg-indigo-600 p-4">
            <p class="text-sm font-normal text-white">{@message.body}</p>
          </div>
        </div>
        <div class="h-8 w-8 rounded-full bg-indigo-600 flex items-center justify-center text-white text-sm font-medium flex-shrink-0">
          {@initial}
        </div>
      </div>
    <% else %>
      <div class="group flex items-start gap-2.5 px-4 py-2 hover:bg-gray-800/50">
        <div class="h-8 w-8 rounded-full bg-indigo-600 flex items-center justify-center text-white text-sm font-medium flex-shrink-0">
          {@initial}
        </div>
        <div class="flex flex-col gap-1">
          <div class="flex items-center space-x-2">
            <span class="text-sm font-semibold text-white">{@display_name}</span>
            <span class="text-sm font-normal text-gray-400">{@timestamp}</span>
          </div>
          <div class="leading-1.5 inline-flex flex-col rounded-e-xl rounded-es-xl bg-gray-700 p-4">
            <p class="text-sm font-normal text-gray-200">{@message.body}</p>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
