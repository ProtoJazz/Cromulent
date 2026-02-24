defmodule CromulentWeb.Components.UserPopover do
  use Phoenix.Component

  @doc """
  Wraps content (username) with a popover trigger and renders the hidden popover panel.

  ## Attrs
  - user: The user map/struct (must have :id, :username, :role)
  - online: Boolean indicating online status
  - context: String to differentiate popover instances (default: "default")
  - placement: Where to position the popover relative to trigger (default: "top")
  - class: Optional additional CSS classes for the trigger span
  """
  attr :user, :map, required: true
  attr :online, :boolean, default: false
  attr :context, :string, default: "default"
  attr :placement, :string, default: "top"
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def user_popover_wrapper(assigns) do
    ~H"""
    <span
      data-popover-target={"user-popover-#{@context}-#{@user.id}"}
      data-popover-trigger="hover"
      data-popover-placement={@placement}
      class={["inline cursor-default", @class]}
    >
      <%= render_slot(@inner_block) %>
    </span>

    <div
      data-popover
      id={"user-popover-#{@context}-#{@user.id}"}
      role="tooltip"
      class="absolute z-50 invisible inline-block w-64 text-sm transition-opacity duration-300 bg-gray-800 border border-gray-700 rounded-lg shadow-lg opacity-0"
    >
      <div class="p-3">
        <div class="flex items-center gap-3">
          <%!-- Avatar circle --%>
          <div class="relative flex-shrink-0">
            <div class="w-10 h-10 rounded-full bg-indigo-600 flex items-center justify-center text-white text-lg font-medium">
              <%= String.first(@user.username) |> String.upcase() %>
            </div>
            <span class={[
              "absolute bottom-0 right-0 w-3 h-3 border-2 border-gray-800 rounded-full",
              if(@online, do: "bg-green-500", else: "bg-gray-500")
            ]}></span>
          </div>

          <%!-- User info --%>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-white truncate"><%= @user.username %></p>
            <div class="flex items-center gap-1.5 mt-1">
              <span class={[
                "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
                role_classes(@user.role)
              ]}>
                <%= role_label(@user.role) %>
              </span>
              <span class={["text-xs", if(@online, do: "text-green-400", else: "text-gray-400")]}>
                <%= if @online, do: "Online", else: "Offline" %>
              </span>
            </div>
          </div>
        </div>
      </div>
      <div data-popper-arrow></div>
    </div>
    """
  end

  defp role_classes(:admin), do: "bg-red-600/20 text-red-400"
  defp role_classes(:moderator), do: "bg-purple-600/20 text-purple-400"
  defp role_classes(_), do: "bg-gray-600/20 text-gray-400"

  defp role_label(:admin), do: "Admin"
  defp role_label(:moderator), do: "Moderator"
  defp role_label(_), do: "Member"
end
