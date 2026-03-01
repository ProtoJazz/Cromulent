defmodule CromulentWeb.Components.MessageComponent do
  use Phoenix.Component
  import CromulentWeb.Components.UserPopover

  attr :message, :map, required: true
  attr :current_user, :any, required: true

  def message(assigns) do
    user = assigns.message.user
    initial = user.username |> String.first() |> String.upcase()
    timestamp = Calendar.strftime(assigns.message.inserted_at, "%I:%M %p")
    is_own = user.id == assigns.current_user.id

    mentioned_user_ids =
      assigns.message.mentions
      |> Enum.filter(&(&1.mention_type == :user))
      |> MapSet.new(& &1.user_id)

    is_mentioned =
      MapSet.member?(mentioned_user_ids, assigns.current_user.id) or
        Enum.any?(assigns.message.mentions, &(&1.mention_type in [:here, :everyone]))

    segments = parse_segments(assigns.message.body)

    assigns =
      assigns
      |> assign(:initial, initial)
      |> assign(:timestamp, timestamp)
      |> assign(:is_own, is_own)
      |> assign(:is_mentioned, is_mentioned)
      |> assign(:is_admin, assigns.current_user.role == :admin)
      |> assign(:segments, segments)

    ~H"""
    <div class={[
      "group relative flex items-start gap-2.5 px-4 py-2 hover:bg-gray-800/50",
      if(@is_mentioned, do: "bg-yellow-500/5 border-l-2 border-yellow-500/50 hover:bg-yellow-500/10"),
      if(@is_own, do: "flex-row-reverse")
    ]}>
      <%!-- Admin delete button — invisible until row is hovered --%>
      <div
        :if={@is_admin}
        class="absolute right-3 top-2 opacity-0 group-hover:opacity-100 transition-opacity"
      >
        <button
          phx-click="delete_message"
          phx-value-id={@message.id}
          class="p-1 rounded text-gray-500 hover:text-red-400 hover:bg-gray-700 transition-colors"
          title="Delete message"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
            />
          </svg>
        </button>
      </div>

      <%!-- Avatar --%>
      <div class="h-8 w-8 rounded-full bg-indigo-600 flex items-center justify-center text-white text-sm font-medium flex-shrink-0">
        {@initial}
      </div>

      <%!-- Content --%>
      <div class={["flex flex-col gap-1", if(@is_own, do: "items-end")]}>
        <div class={[
          "flex items-center space-x-2",
          if(@is_own, do: "flex-row-reverse space-x-reverse")
        ]}>
          <.user_popover_wrapper user={@message.user} online={false} context={@message.id}>
            <span class="text-sm font-semibold text-white">{@message.user.username}</span>
          </.user_popover_wrapper>
          <span class="text-sm font-normal text-gray-400">{@timestamp}</span>
        </div>

        <div class={[
          "leading-1.5 inline-flex flex-col p-3 text-sm font-normal",
          if(@is_own,
            do: "rounded-s-xl rounded-ee-xl bg-indigo-600 text-white",
            else: "rounded-e-xl rounded-es-xl bg-gray-700 text-gray-200"
          )
        ]}>
          <p class="break-words">
            <%= for segment <- @segments do %>
              <%= case segment do %>
                <% {:mention, token} -> %>
                  <.mention_pill
                    token={token}
                    current_user={@current_user}
                    mentions={@message.mentions}
                  />
                <% text -> %>
                  {text}
              <% end %>
            <% end %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  # ── Mention pill component ─────────────────────────────────────────────────

  attr :token, :string, required: true
  attr :current_user, :any, required: true
  attr :mentions, :list, required: true

  defp mention_pill(assigns) do
    style = mention_style(assigns.token, assigns.mentions, assigns.current_user)
    assigns = assign(assigns, :style, style)

    ~H"""
    <span class={[
      "inline-flex items-center rounded px-1 py-0.5 text-xs font-semibold cursor-default",
      @style
    ]}>
      @{@token}
    </span>
    """
  end

  defp mention_style(token, mentions, current_user) do
    targets_me =
      Enum.any?(mentions, fn m ->
        case m.mention_type do
          :user -> m.user_id == current_user.id and token == current_user.username
          :here -> token == "here"
          :everyone -> token in ["everyone", "all"]
          _ -> false
        end
      end)

    if targets_me do
      "bg-yellow-500/20 text-yellow-300 ring-1 ring-yellow-500/40"
    else
      "bg-indigo-500/20 text-indigo-300 ring-1 ring-indigo-500/30"
    end
  end

  defp parse_segments(body) do
    ~r/@([\w]+)/
    |> Regex.split(body, include_captures: true, trim: false)
    |> Enum.map(fn part ->
      case Regex.run(~r/^@([\w]+)$/, part, capture: :all_but_first) do
        [token] -> {:mention, token}
        nil -> part
      end
    end)
    |> Enum.reject(&(&1 == ""))
  end
end
