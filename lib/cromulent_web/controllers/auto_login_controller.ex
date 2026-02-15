
defmodule CromulentWeb.AutoLoginController do
  use CromulentWeb, :controller

  alias Cromulent.Accounts

  def create(conn, %{"refresh_token" => refresh_token}) do
    case Accounts.get_user_by_refresh_token(refresh_token) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> CromulentWeb.UserAuth.log_in_user(user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Your session has expired. Please log in again.")
        |> redirect(to: ~p"/users/log_in")
    end
  end
end
