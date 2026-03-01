defmodule CromulentWeb.AdminLive do
  use CromulentWeb, :live_view

  on_mount {CromulentWeb.UserAuth, :ensure_authenticated}
  on_mount {CromulentWeb.UserAuth, :require_admin}

  alias Cromulent.Accounts
  alias Cromulent.Channels

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:tab, :users)
     |> assign(:users, Accounts.list_users())
     |> assign(:channels, Channels.list_channels())
     |> assign(:channel_form, to_form(%{"name" => "", "type" => "text"}))}
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) when tab in ~w(users channels) do
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
        <p class="text-gray-400 text-sm mt-1">Manage users and channels</p>
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
    </div>
    """
  end
end
