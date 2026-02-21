defmodule CromulentWeb.Components.Sidebar do
  use Phoenix.Component
  use CromulentWeb, :verified_routes
  import CromulentWeb.Components.VoiceBar

  attr :channels, :list, required: true
  attr :current_user, :any, default: nil
  attr :voice_presences, :map, default: %{}
  attr :voice_channel, :any, default: nil
  attr :current_channel, :any, default: nil
  attr :join_modal_type, :atom, default: nil

  def sidebar(assigns) do
    text_channels = Enum.filter(assigns.channels, &(&1.type == :text))
    voice_channels = Enum.filter(assigns.channels, &(&1.type == :voice))

    assigns =
      assigns
      |> assign(:text_channels, text_channels)
      |> assign(:voice_channels, voice_channels)

    ~H"""
    <aside
      class="fixed top-0 left-0 z-40 w-64 h-screen transition-transform -translate-x-full bg-gray-800 border-r border-gray-700 lg:translate-x-0"
      aria-label="Sidebar"
      id="drawer-navigation"
    >
      <div class="flex flex-col h-full">
        <%!-- Server header --%>
        <div class="px-4 py-4 border-b border-gray-700 flex items-center justify-between">
          <h1 class="text-xl font-bold text-white">Cromulent</h1>
          <%= if @current_user && @current_user.role == :admin do %>
            <.link
              navigate={~p"/admin"}
              class="text-gray-400 hover:text-white transition-colors"
              title="Admin settings"
            >
              <svg
                class="w-5 h-5"
                aria-hidden="true"
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                fill="none"
                viewBox="0 0 24 24"
              >
                <path
                  stroke="currentColor"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M21 13v-2a1 1 0 0 0-1-1h-.757l-.707-1.707.535-.536a1 1 0 0 0 0-1.414l-1.414-1.414a1 1 0 0 0-1.414 0l-.536.535L14 4.757V4a1 1 0 0 0-1-1h-2a1 1 0 0 0-1 1v.757l-1.707.707-.536-.535a1 1 0 0 0-1.414 0L4.929 6.343a1 1 0 0 0 0 1.414l.536.536L4.757 10H4a1 1 0 0 0-1 1v2a1 1 0 0 0 1 1h.757l.707 1.707-.535.536a1 1 0 0 0 0 1.414l1.414 1.414a1 1 0 0 0 1.414 0l.536-.535 1.707.707V20a1 1 0 0 0 1 1h2a1 1 0 0 0 1-1v-.757l1.707-.708.536.536a1 1 0 0 0 1.414 0l1.414-1.414a1 1 0 0 0 0-1.414l-.535-.536.707-1.707H20a1 1 0 0 0 1-1Z"
                />
                <path
                  stroke="currentColor"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"
                />
              </svg>
            </.link>
          <% end %>
        </div>

        <%!-- Channel list --%>
        <div class="flex-1 overflow-y-auto px-3 py-4">
          <%!-- Text Channels --%>
          <div class="mb-4">
            <div class="flex items-center justify-between px-2 mb-2">
              <h2 class="text-xs font-semibold tracking-wide uppercase text-gray-400">
                Text Channels
              </h2>
              <button
                phx-click="open_join_modal"
                phx-value-type="text"
                class="text-gray-500 hover:text-gray-300 transition-colors rounded p-0.5 hover:bg-gray-700 cursor-pointer"
                title="Browse text channels"
              >
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2.5"
                    d="M12 4v16m8-8H4"
                  />
                </svg>
              </button>
            </div>
            <ul class="space-y-1">
              <li :for={ch <- @text_channels}>
                <.link
                  patch={~p"/channels/#{ch.slug}"}
                  class={[
                    "flex items-center px-2 py-1.5 text-sm font-medium rounded-md group",
                    if(@current_channel && @current_channel.id == ch.id,
                      do: "bg-gray-700 text-white",
                      else: "text-gray-300 hover:bg-gray-700 hover:text-white"
                    )
                  ]}
                >
                  <svg
                    class={[
                      "w-5 h-5 mr-2 group-hover:text-gray-300",
                      if(@current_channel && @current_channel.id == ch.id,
                        do: "text-gray-300",
                        else: "text-gray-400"
                      )
                    ]}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14"
                    />
                  </svg>
                  {ch.name |> String.replace("# ", "")}
                </.link>
              </li>
            </ul>
          </div>

          <%!-- Voice Channels --%>
          <div>
            <div class="flex items-center justify-between px-2 mb-2">
              <h2 class="text-xs font-semibold tracking-wide uppercase text-gray-400">
                Voice Channels
              </h2>
              <button
                phx-click="open_join_modal"
                phx-value-type="voice"
                class="text-gray-500 hover:text-gray-300 transition-colors rounded p-0.5 hover:bg-gray-700 cursor-pointer"
                title="Browse voice channels"
              >
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2.5"
                    d="M12 4v16m8-8H4"
                  />
                </svg>
              </button>
            </div>
            <ul class="space-y-1">
              <li :for={ch <- @voice_channels}>
                <button
                  phx-click="join_voice"
                  phx-value-channel-id={ch.id}
                  class={[
                    "flex items-center w-full px-2 py-1.5 text-sm font-medium rounded-md cursor-pointer group",
                    if(@voice_channel && @voice_channel.id == ch.id,
                      do: "bg-gray-700 text-white",
                      else: "text-gray-300 hover:bg-gray-700 hover:text-white"
                    )
                  ]}
                >
                  <svg
                    class="w-5 h-5 mr-2 text-gray-400 group-hover:text-gray-300"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"
                    />
                  </svg>
                  {ch.name}
                </button>
                <%= if users = @voice_presences[ch.id] do %>
                  <ul class="ml-7 mt-0.5 space-y-0.5">
                    <li :for={user <- users} class="flex items-center px-2 py-1 text-xs text-gray-400">
                      <div class="w-5 h-5 rounded-full bg-gray-600 flex items-center justify-center text-white text-[10px] font-medium mr-2 flex-shrink-0">
                        {user.email |> String.first() |> String.upcase()}
                      </div>
                      <span class="truncate">{user.email}</span>
                    </li>
                  </ul>
                <% end %>
              </li>
            </ul>
          </div>
        </div>

        <%!-- Voice connection bar --%>
        <%= if @voice_channel do %>
          <.voice_bar voice_channel={@voice_channel} />
        <% end %>

        <%!-- User panel at bottom --%>
        <%= if @current_user do %>
          <div class="px-3 py-2 border-t border-gray-700">
            <div class="flex items-center justify-between">
              <div class="flex items-center min-w-0">
                <div class="w-8 h-8 rounded-full bg-gray-600 flex items-center justify-center text-white text-sm font-medium flex-shrink-0">
                  {String.first(@current_user.email) |> String.upcase()}
                </div>
                <div class="ml-2 min-w-0">
                  <p class="text-sm font-medium text-white truncate">{@current_user.email}</p>
                </div>
              </div>
              <div class="flex items-center gap-1 flex-shrink-0">
                <.link
                  href={~p"/users/settings"}
                  class="p-1.5 text-gray-400 hover:text-white rounded hover:bg-gray-700"
                  title="Settings"
                >
                  <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                    <path
                      fill-rule="evenodd"
                      d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </.link>
                <.link
                  href={~p"/users/log_out"}
                  method="delete"
                  class="p-1.5 text-gray-400 hover:text-white rounded hover:bg-gray-700"
                  title="Log out"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
                    />
                  </svg>
                </.link>
              </div>
            </div>
          </div>
        <% end %>
      </div>
      <%= if @join_modal_type do %>
        <.live_component
          module={CromulentWeb.JoinChannelModal}
          id="join-channel-modal"
          current_user={@current_user}
          channel_type={@join_modal_type}
        />
      <% end %>
    </aside>
    """
  end
end
