defmodule CromulentWeb.Components.MembersSidebar do
  use Phoenix.Component
  import CromulentWeb.Components.UserPopover

  attr :server_presences, :list, default: []
  attr :all_members, :list, default: []
  attr :voice_presences, :map, default: %{}

  def members_sidebar(assigns) do
    online_ids =
      assigns.server_presences
      |> Enum.map(& &1.user_id)
      |> MapSet.new()

    online_members =
      Enum.filter(assigns.all_members, &MapSet.member?(online_ids, &1.id))

    offline_members =
      Enum.filter(assigns.all_members, &(not MapSet.member?(online_ids, &1.id)))

    voice_channel_by_user =
      assigns.voice_presences
      |> Enum.flat_map(fn {channel_id, users} ->
        Enum.map(users, fn u -> {u.user_id, channel_id} end)
      end)
      |> Map.new()

    assigns =
      assigns
      |> assign(:online_members, online_members)
      |> assign(:offline_members, offline_members)
      |> assign(:voice_channel_by_user, voice_channel_by_user)

    ~H"""
    <aside
      id="drawer-members"
      class="fixed top-0 right-0 z-40 w-60 h-screen bg-gray-800 border-l border-gray-700
         transition-transform translate-x-full lg:translate-x-0"
      aria-label="Members"
      data-drawer-placement="right"
    >
      <div class="flex flex-col h-full">
        <div class="px-4 py-4 border-b border-gray-700">
          <h2 class="text-xs font-semibold tracking-wide uppercase text-gray-400">Members</h2>
        </div>

        <div class="flex-1 overflow-y-auto px-3 py-4 space-y-6">
          <%!-- Online --%>
          <div :if={length(@online_members) > 0}>
            <p class="px-2 mb-2 text-xs font-semibold tracking-wide uppercase text-gray-400">
              Online — {length(@online_members)}
            </p>
            <ul class="space-y-0.5">
              <li :for={member <- @online_members}>
                <div class="flex items-center gap-2.5 px-2 py-1.5 rounded-md hover:bg-gray-700 group cursor-default">
                  <%!-- Avatar with online indicator --%>
                  <div class="relative flex-shrink-0">
                    <div class="w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center text-xs font-semibold text-white">
                      {String.first(member.username) |> String.upcase()}
                    </div>
                    <span class="absolute bottom-0 right-0 w-2.5 h-2.5 bg-green-500 border-2 border-gray-800 rounded-full">
                    </span>
                  </div>
                  <%!-- Name + voice badge --%>
                  <div class="flex-1 min-w-0">
                    <.user_popover_wrapper user={member} online={true} context="sidebar-online" placement="left">
                      <p class="text-sm font-medium text-gray-200 truncate">{member.username}</p>
                    </.user_popover_wrapper>
                    <%= if _channel_id = Map.get(@voice_channel_by_user, member.id) do %>
                      <p class="text-xs text-green-400 truncate flex items-center gap-1">
                        <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M7 4a3 3 0 016 0v6a3 3 0 11-6 0V4z" />
                          <path d="M5.5 9.643a.75.75 0 00-1.5 0V10a6 6 0 0012 0v-.357a.75.75 0 00-1.5 0V10a4.5 4.5 0 01-9 0v-.357z" />
                        </svg>
                        In voice
                      </p>
                    <% end %>
                  </div>
                </div>
              </li>
            </ul>
          </div>

          <%!-- Offline --%>
          <div :if={length(@offline_members) > 0}>
            <p class="px-2 mb-2 text-xs font-semibold tracking-wide uppercase text-gray-400">
              Offline — {length(@offline_members)}
            </p>
            <ul class="space-y-0.5">
              <li :for={member <- @offline_members}>
                <div class="flex items-center gap-2.5 px-2 py-1.5 rounded-md hover:bg-gray-700 cursor-default">
                  <div class="relative flex-shrink-0">
                    <div class="w-8 h-8 rounded-full bg-gray-600 flex items-center justify-center text-xs font-semibold text-gray-400">
                      {String.first(member.username) |> String.upcase()}
                    </div>
                    <span class="absolute bottom-0 right-0 w-2.5 h-2.5 bg-gray-600 border-2 border-gray-800 rounded-full">
                    </span>
                  </div>
                  <.user_popover_wrapper user={member} online={false} context="sidebar-offline" placement="left">
                    <p class="text-sm font-medium text-gray-500 truncate">{member.username}</p>
                  </.user_popover_wrapper>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </aside>
    """
  end
end
