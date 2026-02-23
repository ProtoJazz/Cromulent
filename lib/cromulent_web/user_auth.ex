defmodule CromulentWeb.UserAuth do
  use CromulentWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Cromulent.Accounts

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_cromulent_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_user_session_token(user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      CromulentWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if token = get_session(conn, :user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, put_token_in_session(conn, token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Handles mounting and authenticating the current_user in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_user` - Assigns current_user
      to socket assigns based on user_token, or nil if
      there's no user_token or no matching user.

    * `:ensure_authenticated` - Authenticates the user from the session,
      and assigns the current_user to socket assigns based
      on user_token.
      Redirects to login page if there's no logged user.

    * `:redirect_if_user_is_authenticated` - Authenticates the user from the session.
      Redirects to signed_in_path if there's a logged user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the current_user:

      defmodule CromulentWeb.PageLive do
        use CromulentWeb, :live_view

        on_mount {CromulentWeb.UserAuth, :mount_current_user}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{CromulentWeb.UserAuth, :ensure_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:require_admin, _params, _session, socket) do
    if socket.assigns.current_user && socket.assigns.current_user.role == :admin do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    server_presences =
      CromulentWeb.Presence.list("server:all")
      |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta end)

    socket =
      socket
      |> mount_current_user(session)
      |> Phoenix.Component.assign(:join_modal_type, nil)
      |> Phoenix.Component.assign(:server_presences, server_presences)
      |> Phoenix.Component.assign(:all_members, Cromulent.Accounts.list_users())

    if socket.assigns.current_user do
      channels = Cromulent.Channels.list_joined_channels(socket.assigns.current_user)
      voice_channels = Enum.filter(channels, &(&1.type == :voice))

      socket =
        socket
        |> Phoenix.Component.assign(:channels, channels)
        |> Phoenix.Component.assign(
          :unread_counts,
          Cromulent.Notifications.unread_counts_for_user(socket.assigns.current_user.id)
        )

      # Build initial voice presences map
      voice_presences =
        voice_channels
        |> Map.new(fn ch ->
          users =
            CromulentWeb.Presence.list("voice:#{ch.id}")
            |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta end)

          {ch.id, users}
        end)

      socket =
        socket
        |> Phoenix.Component.assign(:voice_presences, voice_presences)
        |> Phoenix.Component.assign_new(:voice_channel, fn ->
          Cromulent.VoiceState.get(socket.assigns.current_user.id)
        end)

      socket =
        if Phoenix.LiveView.connected?(socket) && !socket.assigns[:presence_hook_attached] do
          for ch <- voice_channels do
            Phoenix.PubSub.subscribe(Cromulent.PubSub, "voice:#{ch.id}")
          end

          CromulentWeb.Presence.track(self(), "server:all", socket.assigns.current_user.id, %{
            user_id: socket.assigns.current_user.id,
            username: socket.assigns.current_user.username,
            online_at: System.system_time(:millisecond)
          })

          Phoenix.PubSub.subscribe(Cromulent.PubSub, "server:all")

          Phoenix.PubSub.subscribe(
            Cromulent.PubSub,
            "user:#{socket.assigns.current_user.id}"
          )

          socket
          |> Phoenix.Component.assign(:presence_hook_attached, true)
          |> Phoenix.LiveView.attach_hook(
            :presence_updates,
            :handle_info,
            &handle_presence_info/2
          )
        else
          socket
        end

      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  defp handle_presence_info(
         %Phoenix.Socket.Broadcast{event: "unread_changed", topic: "user:" <> _user_id},
         socket
       ) do
    counts =
      Cromulent.Notifications.unread_counts_for_user(socket.assigns.current_user.id)

    {:cont, Phoenix.Component.assign(socket, :unread_counts, counts)}
  end

  defp handle_presence_info(
         %Phoenix.Socket.Broadcast{event: "presence_diff", topic: "voice:" <> channel_id},
         socket
       ) do
    users =
      CromulentWeb.Presence.list("voice:#{channel_id}")
      |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta end)

    voice_presences = Map.put(socket.assigns.voice_presences, channel_id, users)
    {:cont, Phoenix.Component.assign(socket, :voice_presences, voice_presences)}
  end

  defp handle_presence_info(
         %Phoenix.Socket.Broadcast{event: "presence_diff", topic: "server:all"},
         socket
       ) do
    server_presences =
      CromulentWeb.Presence.list("server:all")
      |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta end)

    {:cont, Phoenix.Component.assign(socket, :server_presences, server_presences)}
  end

  defp handle_presence_info(_msg, socket), do: {:cont, socket}

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      if user_token = session["user_token"] do
        Accounts.get_user_by_session_token(user_token)
      end
    end)
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/"
end
