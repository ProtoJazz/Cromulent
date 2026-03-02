defmodule CromulentWeb.AdminLive do
  use CromulentWeb, :live_view

  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}
  on_mount {CromulentWeb.UserAuth, :require_admin}

  alias Cromulent.Accounts
  alias Cromulent.Channels
  alias Cromulent.FeatureFlags

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tab, :users)
     |> assign(:users, Accounts.list_users())
     |> assign(:channels, Channels.list_channels())
     |> assign(:channel_form, to_form(%{"name" => "", "type" => "text"}))
     |> assign(:create_user_form, to_form(%{"email" => "", "username" => "", "password" => ""}))
     |> assign(:turn_test_result, nil)}
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) when tab in ~w(users channels settings) do
    {:noreply, assign(socket, :tab, String.to_atom(tab))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_role", %{"user_id" => user_id, "role" => role}, socket) do
    user = Accounts.get_user!(user_id)

    # Prevent removing the last admin
    if user.role == :admin && role == "member" do
      admin_count = Enum.count(socket.assigns.users, &(&1.role == :admin))

      if admin_count <= 1 do
        {:noreply, put_flash(socket, :error, "Cannot remove the last admin.")}
      else
        do_set_role(socket, user, role)
      end
    else
      do_set_role(socket, user, role)
    end
  end

  def handle_event("create_channel", %{"name" => name, "type" => type}, socket) do
    case Channels.create_channel(%{name: name, type: type}) do
      {:ok, _channel} ->
        {:noreply,
         socket
         |> put_flash(:info, "Channel ##{name} created.")
         |> assign(:channels, Channels.list_channels())
         |> assign(:channel_form, to_form(%{"name" => "", "type" => "text"}))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create channel.")
         |> assign(:channel_form, to_form(changeset))}
    end
  end

  def handle_event("delete_channel", %{"id" => id}, socket) do
    channel = Channels.get_channel!(id)

    case Channels.delete_channel(channel) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Channel ##{channel.name} deleted.")
         |> assign(:channels, Channels.list_channels())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete channel.")}
    end
  end


  def handle_event("make_default", %{"id" => id}, socket) do
    channel = Channels.get_channel!(id)
    Channels.set_default(channel, true)

     {:noreply,
         socket
         |> put_flash(:info, "Channel ##{channel.name} made default.")
         |> assign(:channels, Channels.list_channels())}
  end

  def handle_event("remove_default", %{"id" => id}, socket) do
    channel = Channels.get_channel!(id)
    Channels.set_default(channel, false)

     {:noreply,
         socket
         |> put_flash(:info, "Channel ##{channel.name} removed from default.")
         |> assign(:channels, Channels.list_channels())}
  end

  def handle_event("toggle_flag", %{"flag" => flag, "value" => value}, socket) do
    attrs = %{String.to_existing_atom(flag) => value == "true"}

    case FeatureFlags.upsert_flags(attrs) do
      {:ok, flags} ->
        {:noreply,
         socket
         |> put_flash(:info, "Setting updated.")
         |> assign(:feature_flags, flags)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update setting.")}
    end
  end

  def handle_event(
        "save_turn_config",
        %{"turn_provider" => provider, "turn_url" => url, "turn_secret" => secret},
        socket
      ) do
    attrs = %{turn_provider: provider, turn_url: url, turn_secret: secret}

    case FeatureFlags.upsert_flags(attrs) do
      {:ok, flags} ->
        test_result = test_turn_connection(flags)

        {:noreply,
         socket
         |> put_flash(:info, "TURN config saved.")
         |> assign(:feature_flags, flags)
         |> assign(:turn_test_result, test_result)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Invalid TURN config.")}
    end
  end

  def handle_event(
        "admin_create_user",
        %{"email" => email, "username" => username, "password" => password},
        socket
      ) do
    case Accounts.register_user(%{email: email, username: username, password: password}) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User #{username} created.")
         |> assign(:users, Accounts.list_users())
         |> assign(:create_user_form, to_form(%{"email" => "", "username" => "", "password" => ""}))}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create user.")
         |> assign(:create_user_form, to_form(changeset))}
    end
  end

  defp test_turn_connection(%{turn_provider: "coturn", turn_url: url, turn_secret: secret})
       when is_binary(url) and is_binary(secret) do
    case Cromulent.Turn.Coturn.get_ice_servers("test_user", url, secret) do
      {:ok, _servers} -> {:ok, "Connection successful — credentials generated."}
      {:error, reason} -> {:error, "Failed: #{inspect(reason)}"}
    end
  end

  defp test_turn_connection(%{turn_provider: "metered", turn_url: url, turn_secret: key})
       when is_binary(url) and is_binary(key) do
    case Cromulent.Turn.Metered.get_ice_servers("test_user", url, key) do
      {:ok, _servers} -> {:ok, "Connection successful — ICE servers returned."}
      {:error, reason} -> {:error, "Failed: #{inspect(reason)}"}
    end
  end

  defp test_turn_connection(_flags), do: nil

  defp do_set_role(socket, user, role) do
    case Accounts.set_user_role(user, String.to_atom(role)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Updated #{user.username}'s role to #{role}.")
         |> assign(:users, Accounts.list_users())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update role.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto py-6">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-white">Admin</h1>
        <p class="text-gray-400 text-sm mt-1">Manage users, channels, and settings</p>
      </div>

      <%!-- Tab nav --%>
      <div class="border-b border-gray-700 mb-6">
        <ul class="flex flex-wrap -mb-px text-sm font-medium text-center">
          <li class="me-2">
            <.link
              patch={~p"/admin?tab=users"}
              class={[
                "inline-flex items-center justify-center p-4 border-b-2 rounded-t-lg group",
                if(@tab == :users,
                  do: "text-indigo-400 border-indigo-400",
                  else: "text-gray-400 border-transparent hover:text-gray-300 hover:border-gray-600"
                )
              ]}
            >
              <.icon name="hero-users" class="w-4 h-4 me-2" />
              Users
            </.link>
          </li>
          <li class="me-2">
            <.link
              patch={~p"/admin?tab=channels"}
              class={[
                "inline-flex items-center justify-center p-4 border-b-2 rounded-t-lg group",
                if(@tab == :channels,
                  do: "text-indigo-400 border-indigo-400",
                  else: "text-gray-400 border-transparent hover:text-gray-300 hover:border-gray-600"
                )
              ]}
            >
              <.icon name="hero-hashtag" class="w-4 h-4 me-2" />
              Channels
            </.link>
          </li>
          <li class="me-2">
            <.link
              patch={~p"/admin?tab=settings"}
              class={[
                "inline-flex items-center justify-center p-4 border-b-2 rounded-t-lg group",
                if(@tab == :settings,
                  do: "text-indigo-400 border-indigo-400",
                  else: "text-gray-400 border-transparent hover:text-gray-300 hover:border-gray-600"
                )
              ]}
            >
              <.icon name="hero-cog-6-tooth" class="w-4 h-4 me-2" />
              Settings
            </.link>
          </li>
        </ul>
      </div>

      <%!-- Users tab --%>
      <div :if={@tab == :users}>
        <div class="relative overflow-x-auto rounded-lg border border-gray-700">
          <table class="w-full text-sm text-left text-gray-400">
            <thead class="text-xs text-gray-400 uppercase bg-gray-700">
              <tr>
                <th scope="col" class="px-6 py-3">Username</th>
                <th scope="col" class="px-6 py-3">Email</th>
                <th scope="col" class="px-6 py-3">Role</th>
                <th scope="col" class="px-6 py-3">Joined</th>
                <th scope="col" class="px-6 py-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={user <- @users}
                class="bg-gray-800 border-b border-gray-700 hover:bg-gray-750"
              >
                <td class="px-6 py-4 font-medium text-white">
                  <%= user.username %>
                  <span :if={user.id == @current_user.id} class="ml-2 text-xs text-gray-500">(you)</span>
                </td>
                <td class="px-6 py-4"><%= user.email %></td>
                <td class="px-6 py-4">
                  <span class={[
                    "text-xs font-medium px-2.5 py-0.5 rounded",
                    if(user.role == :admin,
                      do: "bg-indigo-900 text-indigo-300",
                      else: "bg-gray-700 text-gray-300"
                    )
                  ]}>
                    <%= user.role %>
                  </span>
                </td>
                <td class="px-6 py-4 text-gray-500 text-xs">
                  <%= Calendar.strftime(user.inserted_at, "%b %d, %Y") %>
                </td>
                <td class="px-6 py-4">
                  <div :if={user.id != @current_user.id} class="flex gap-2">
                    <button
                      :if={user.role == :member}
                      phx-click="set_role"
                      phx-value-user_id={user.id}
                      phx-value-role="admin"
                      class="text-xs font-medium text-indigo-400 hover:text-indigo-300 cursor-pointer"
                    >
                      Make admin
                    </button>
                    <button
                      :if={user.role == :admin}
                      phx-click="set_role"
                      phx-value-user_id={user.id}
                      phx-value-role="member"
                      class="text-xs font-medium text-red-400 hover:text-red-300 cursor-pointer"
                    >
                      Remove admin
                    </button>
                  </div>
                  <span :if={user.id == @current_user.id} class="text-xs text-gray-600">—</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <%!-- Create User form --%>
        <div class="mt-6 p-4 bg-gray-800 rounded-lg border border-gray-700">
          <h2 class="text-sm font-semibold text-white mb-3">Create User</h2>
          <.form for={@create_user_form} phx-submit="admin_create_user" class="flex gap-3 items-end flex-wrap">
            <div>
              <label class="block mb-1 text-xs font-medium text-gray-400">Email</label>
              <input type="email" name="email" value={@create_user_form[:email].value}
                placeholder="user@example.com"
                class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5" />
            </div>
            <div>
              <label class="block mb-1 text-xs font-medium text-gray-400">Username</label>
              <input type="text" name="username" value={@create_user_form[:username].value}
                placeholder="coolperson42"
                class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5" />
            </div>
            <div>
              <label class="block mb-1 text-xs font-medium text-gray-400">Password</label>
              <input type="password" name="password"
                placeholder="••••••••"
                class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5" />
            </div>
            <button type="submit"
              class="text-white bg-indigo-600 hover:bg-indigo-700 font-medium rounded-lg text-sm px-4 py-2.5">
              Create User
            </button>
          </.form>
        </div>
      </div>

      <%!-- Channels tab --%>
      <div :if={@tab == :channels}>
        <%!-- Create channel form --%>
        <div class="p-4 mb-6 bg-gray-800 rounded-lg border border-gray-700">
          <h2 class="text-sm font-semibold text-white mb-3">Create Channel</h2>
          <.form for={@channel_form} phx-submit="create_channel" class="flex gap-3 items-end">
            <div class="flex-1">
              <label class="block mb-1 text-xs font-medium text-gray-400">Name</label>
              <input
                type="text"
                name="name"
                value={@channel_form[:name].value}
                placeholder="e.g. announcements"
                class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5"
              />
            </div>
            <div>
              <label class="block mb-1 text-xs font-medium text-gray-400">Type</label>
              <select
                name="type"
                class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block p-2.5"
              >
                <option value="text">Text</option>
                <option value="voice">Voice</option>
              </select>
            </div>
            <button
              type="submit"
              class="text-white bg-indigo-600 hover:bg-indigo-700 focus:ring-4 focus:ring-indigo-800 font-medium rounded-lg text-sm px-4 py-2.5"
            >
              Create
            </button>
          </.form>
        </div>

        <%!-- Channel list --%>
        <div class="relative overflow-x-auto rounded-lg border border-gray-700">
          <table class="w-full text-sm text-left text-gray-400">
            <thead class="text-xs text-gray-400 uppercase bg-gray-700">
              <tr>
                <th scope="col" class="px-6 py-3">Name</th>
                <th scope="col" class="px-6 py-3">Type</th>
                <th scope="col" class="px-6 py-3">Default</th>
                <th scope="col" class="px-6 py-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={channel <- @channels}
                class="bg-gray-800 border-b border-gray-700 hover:bg-gray-750"
              >
                <td class="px-6 py-4 font-medium text-white">
                  <span class="text-gray-500 mr-1"><%= if channel.type == :text, do: "#", else: "🔊" %></span>
                  <%= channel.name %>
                </td>
                <td class="px-6 py-4">
                  <span class={[
                    "text-xs font-medium px-2.5 py-0.5 rounded",
                    if(channel.type == :text,
                      do: "bg-blue-900 text-blue-300",
                      else: "bg-green-900 text-green-300"
                    )
                  ]}>
                    <%= channel.type %>
                  </span>
                </td><td class="px-6 py-4">
                  <%= if channel.is_default do %>
                    <button
                      phx-click="remove_default"
                      phx-value-id={channel.id}
                      class="text-xs font-medium text-red-400 hover:text-red-300 cursor-pointer"
                    >
                      Remove Default
                    </button>
                  <% end %>

                     <%= if !channel.is_default do %>
                    <button
                      phx-click="make_default"
                      phx-value-id={channel.id}
                      class="text-xs font-medium text-green-400 hover:text-green-300 cursor-pointer"
                    >
                      Make Default
                    </button>
                  <% end %>
                </td>
                <td class="px-6 py-4">
                  <button
                    phx-click="delete_channel"
                    phx-value-id={channel.id}
                    data-confirm={"Delete ##{channel.name}? This cannot be undone."}
                    class="text-xs font-medium text-red-400 hover:text-red-300 cursor-pointer"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Settings tab --%>
      <div :if={@tab == :settings}>
        <%!-- Feature flag toggles --%>
        <div class="p-4 mb-6 bg-gray-800 rounded-lg border border-gray-700">
          <h2 class="text-sm font-semibold text-white mb-4">Feature Flags</h2>
          <div class="space-y-4">

            <%!-- Voice Channels toggle --%>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-white">Voice Channels</p>
                <p class="text-xs text-gray-400">Enable or disable voice channel features</p>
              </div>
              <label class="inline-flex items-center cursor-pointer">
                <input type="checkbox" checked={@feature_flags.voice_enabled}
                  phx-click="toggle_flag" phx-value-flag="voice_enabled"
                  phx-value-value={!@feature_flags.voice_enabled}
                  class="sr-only peer" />
                <div class="relative w-11 h-6 bg-gray-600 peer-focus:outline-none peer-focus:ring-4
                            peer-focus:ring-indigo-800 rounded-full peer peer-checked:after:translate-x-full
                            rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white
                            after:content-[''] after:absolute after:top-[2px] after:start-[2px]
                            after:bg-white after:border-gray-300 after:border after:rounded-full
                            after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
              </label>
            </div>

            <%!-- User Registration toggle --%>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-white">User Registration</p>
                <p class="text-xs text-gray-400">Allow new users to register accounts</p>
              </div>
              <label class="inline-flex items-center cursor-pointer">
                <input type="checkbox" checked={@feature_flags.registration_enabled}
                  phx-click="toggle_flag" phx-value-flag="registration_enabled"
                  phx-value-value={!@feature_flags.registration_enabled}
                  class="sr-only peer" />
                <div class="relative w-11 h-6 bg-gray-600 peer-focus:outline-none peer-focus:ring-4
                            peer-focus:ring-indigo-800 rounded-full peer peer-checked:after:translate-x-full
                            rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white
                            after:content-[''] after:absolute after:top-[2px] after:start-[2px]
                            after:bg-white after:border-gray-300 after:border after:rounded-full
                            after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
              </label>
            </div>

            <%!-- Link Previews toggle --%>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-white">Link Previews</p>
                <p class="text-xs text-gray-400">Show Open Graph preview cards for URLs</p>
              </div>
              <label class="inline-flex items-center cursor-pointer">
                <input type="checkbox" checked={@feature_flags.link_previews_enabled}
                  phx-click="toggle_flag" phx-value-flag="link_previews_enabled"
                  phx-value-value={!@feature_flags.link_previews_enabled}
                  class="sr-only peer" />
                <div class="relative w-11 h-6 bg-gray-600 peer-focus:outline-none peer-focus:ring-4
                            peer-focus:ring-indigo-800 rounded-full peer peer-checked:after:translate-x-full
                            rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white
                            after:content-[''] after:absolute after:top-[2px] after:start-[2px]
                            after:bg-white after:border-gray-300 after:border after:rounded-full
                            after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
              </label>
            </div>

            <%!-- Email Confirmation toggle --%>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-white">Require Email Confirmation</p>
                <p class="text-xs text-gray-400">New accounts must confirm email before login. Enabling this will lock out existing unconfirmed users.</p>
              </div>
              <label class="inline-flex items-center cursor-pointer">
                <input type="checkbox" checked={@feature_flags.email_confirmation_required}
                  phx-click="toggle_flag" phx-value-flag="email_confirmation_required"
                  phx-value-value={!@feature_flags.email_confirmation_required}
                  class="sr-only peer" />
                <div class="relative w-11 h-6 bg-gray-600 peer-focus:outline-none peer-focus:ring-4
                            peer-focus:ring-indigo-800 rounded-full peer peer-checked:after:translate-x-full
                            rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white
                            after:content-[''] after:absolute after:top-[2px] after:start-[2px]
                            after:bg-white after:border-gray-300 after:border after:rounded-full
                            after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
              </label>
            </div>

          </div>
        </div>

        <%!-- TURN Config section --%>
        <div class="p-4 bg-gray-800 rounded-lg border border-gray-700">
          <h2 class="text-sm font-semibold text-white mb-1">TURN Server Configuration</h2>
          <p class="text-xs text-gray-400 mb-4">Configure TURN relay for voice behind restrictive firewalls</p>
          <form phx-submit="save_turn_config" class="space-y-3">
            <div>
              <label class="block mb-1 text-xs font-medium text-gray-400">Provider</label>
              <select name="turn_provider"
                class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5">
                <option value="disabled" selected={@feature_flags.turn_provider == "disabled"}>Disabled (STUN only)</option>
                <option value="coturn" selected={@feature_flags.turn_provider == "coturn"}>Coturn (self-hosted)</option>
                <option value="metered" selected={@feature_flags.turn_provider == "metered"}>Metered (managed)</option>
              </select>
            </div>
            <div>
              <label class="block mb-1 text-xs font-medium text-gray-400">Server URL / API URL</label>
              <input type="text" name="turn_url" value={@feature_flags.turn_url || ""}
                placeholder="turn:yourdomain.com:3478 or https://yourapp.metered.live"
                class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5" />
            </div>
            <div>
              <label class="block mb-1 text-xs font-medium text-gray-400">Secret / API Key</label>
              <input type="password" name="turn_secret" value={@feature_flags.turn_secret || ""}
                placeholder="••••••••"
                class="bg-gray-700 border border-gray-600 text-white text-sm rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block w-full p-2.5" />
            </div>
            <button type="submit"
              class="text-white bg-indigo-600 hover:bg-indigo-700 font-medium rounded-lg text-sm px-4 py-2.5">
              Save & Test
            </button>
          </form>

          <%!-- TURN test result --%>
          <%= if @turn_test_result do %>
            <div class={["mt-3 text-sm px-3 py-2 rounded",
              case @turn_test_result do
                {:ok, _} -> "bg-green-900 text-green-300"
                {:error, _} -> "bg-red-900 text-red-300"
              end
            ]}>
              <%= case @turn_test_result do
                {:ok, msg} -> msg
                {:error, msg} -> msg
              end %>
            </div>
          <% end %>
        </div>

      </div>
    </div>
    """
  end
end
