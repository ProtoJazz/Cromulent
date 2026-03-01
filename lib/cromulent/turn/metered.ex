defmodule Cromulent.Turn.Metered do
  @moduledoc """
  TURN credentials via Metered.ca managed service REST API.
  Requires env vars: TURN_API_KEY, TURN_API_URL (e.g. https://yourapp.metered.live)
  """
  @behaviour Cromulent.Turn.Provider

  @impl true
  def get_ice_servers(_user_id) do
    api_key = System.get_env("TURN_API_KEY") || raise "TURN_API_KEY env var not set"
    base_url = System.get_env("TURN_API_URL") || raise "TURN_API_URL env var not set"
    url = "#{base_url}/api/v2/turn/credentials?secretKey=#{api_key}"

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
end
