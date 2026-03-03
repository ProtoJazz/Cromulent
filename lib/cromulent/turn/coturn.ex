defmodule Cromulent.Turn.Coturn do
  @moduledoc """
  TURN credentials for self-hosted Coturn server.
  Uses HMAC-SHA1 time-limited credential scheme (RFC 8489).
  Accepts turn_url and turn_secret as params (read from DB feature flags).
  """
  @behaviour Cromulent.Turn.Provider

  @impl true
  def get_ice_servers(user_id, turn_url, turn_secret)
      when is_binary(turn_url) and is_binary(turn_secret) do
    ttl = System.system_time(:second) + 3600
    username = "#{ttl}:#{user_id}"
    # Use :crypto.mac/4 — :crypto.hmac/3 was removed in OTP 26
    password = :crypto.mac(:hmac, :sha, turn_secret, username) |> Base.encode64()

    {:ok,
     [
       %{urls: "stun:stun.l.google.com:19302"},
       %{urls: turn_url, username: username, credential: password}
     ]}
  end

  def get_ice_servers(_user_id, _turn_url, _turn_secret) do
    {:error, :not_configured}
  end
end
