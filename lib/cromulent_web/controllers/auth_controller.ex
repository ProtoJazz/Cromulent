defmodule CromulentWeb.Api.AuthController do
  use CromulentWeb, :controller

  alias Cromulent.Accounts

  def login(conn, %{"email" => email, "password" => password} = params) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      device_info = %{
        device_name: params["device_name"] || "Unknown Device",
        device_type: params["device_type"] || "electron",
        ip_address: to_string(:inet_parse.ntoa(conn.remote_ip))
      }

      refresh_token = Accounts.generate_user_refresh_token(user, device_info)

      json(conn, %{
        success: true,
        refresh_token: refresh_token,
        user: %{
          id: user.id,
          email: user.email
        }
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{success: false, error: "Invalid email or password"})
    end
  end

  def logout(conn, %{"refresh_token" => refresh_token}) do
    Accounts.delete_user_refresh_token(refresh_token)
    json(conn, %{success: true})
  end

  def verify(conn, %{"refresh_token" => refresh_token}) do
    case Accounts.get_user_by_refresh_token(refresh_token) do
      {:ok, user} ->
        json(conn, %{
          success: true,
          user: %{
            id: user.id,
            email: user.email
          }
        })

      {:error, _} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "Invalid or expired token"})
    end
  end
end
