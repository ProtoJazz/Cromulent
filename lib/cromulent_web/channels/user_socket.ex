defmodule CromulentWeb.UserSocket do
  use Phoenix.Socket

  channel "voice:*", CromulentWeb.VoiceChannel
  #channel "text:*", CromulentWeb.TextChannel

  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(CromulentWeb.Endpoint, "user socket", token, max_age: 86_400) do
      {:ok, user_id} ->
        user = Cromulent.Accounts.get_user!(user_id)
        {:ok, assign(socket, :current_user, user)}
      {:error, _} ->
        :error
    end
  end

  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
