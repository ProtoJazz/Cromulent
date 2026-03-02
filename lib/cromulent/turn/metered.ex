defmodule Cromulent.Turn.Metered do
  @moduledoc """
  TURN credentials via Metered.ca managed service REST API.
  Accepts api_url and api_key as params (read from DB feature flags).
  """
  @behaviour Cromulent.Turn.Provider

  @impl true
  def get_ice_servers(_user_id, api_url, api_key)
      when is_binary(api_url) and is_binary(api_key) do
    url = "#{api_url}/api/v2/turn/credentials?secretKey=#{api_key}"

    case Finch.build(:get, url) |> Finch.request(Cromulent.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        # Metered returns a list of credential objects
        # Normalize each entry to RTCPeerConnection iceServers format
        servers =
          body
          |> Jason.decode!()
          |> Enum.map(fn cred ->
            %{
              urls: cred["urls"],
              username: cred["username"],
              credential: cred["credential"]
            }
          end)

        {:ok, servers}

      {:ok, %Finch.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_ice_servers(_user_id, _api_url, _api_key) do
    {:error, :not_configured}
  end
end
