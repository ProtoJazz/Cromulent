defmodule CromulentWeb.Components.MentionAutocomplete do
  use Phoenix.Component

  @doc """
  Renders a mention autocomplete dropdown above the message input.

  ## Examples

      <.mention_autocomplete
        open={@autocomplete_open}
        results={@autocomplete_results}
        selected_index={@autocomplete_index}
      />
  """
  attr :open, :boolean, required: true
  attr :results, :list, required: true
  attr :selected_index, :integer, required: true

  def mention_autocomplete(assigns) do
    ~H"""
    <div
      :if={@open}
      class="absolute bottom-full left-0 mb-1 w-72 bg-gray-800 border border-gray-600 rounded-lg shadow-lg z-50"
      role="listbox"
      id="mention-listbox"
      aria-label="Mention suggestions"
    >
      <ul class="max-h-[220px] overflow-y-auto py-1">
        <li
          :for={{item, idx} <- Enum.with_index(@results)}
          role="option"
          id={"mention-option-#{idx}"}
          aria-selected={to_string(idx == @selected_index)}
          phx-click="autocomplete_select"
          phx-value-index={idx}
          class={[
            "px-3 py-2 flex items-center gap-3 cursor-pointer text-sm",
            if(idx == @selected_index,
              do: "bg-gray-700 text-white",
              else: "text-gray-300 hover:bg-gray-700/50"
            )
          ]}
        >
          <%= case item.type do %>
            <% :user -> %>
              <div class="h-7 w-7 rounded-full bg-indigo-600 flex items-center justify-center text-white text-xs font-medium flex-shrink-0">
                <%= String.first(item.user.username) |> String.upcase() %>
              </div>
              <div class="flex flex-col overflow-hidden">
                <span class="text-white truncate"><%= item.user.username %></span>
                <span class="text-gray-400 text-xs truncate">@<%= item.user.username %></span>
              </div>
            <% :broadcast -> %>
              <div class="h-7 w-7 rounded-full bg-indigo-600 flex items-center justify-center text-white text-xs font-medium flex-shrink-0">
                @
              </div>
              <div class="flex flex-col overflow-hidden">
                <span class="text-indigo-400 font-medium truncate"><%= item.label %></span>
                <span class="text-gray-400 text-xs truncate"><%= item.description %></span>
              </div>
            <% :group -> %>
              <div class={[
                "h-7 w-7 rounded-full flex items-center justify-center text-white text-xs font-medium flex-shrink-0",
                if(item.group.color, do: "bg-[#{item.group.color}]", else: "bg-green-600")
              ]}>
                <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z" />
                </svg>
              </div>
              <div class="flex flex-col overflow-hidden">
                <span class="text-green-400 font-medium truncate">@<%= item.group.slug %></span>
                <span class="text-gray-400 text-xs truncate"><%= item.group.name %></span>
              </div>
          <% end %>
        </li>
      </ul>
    </div>
    """
  end
end
