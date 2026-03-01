defmodule Cromulent.Turn.Coturn do
  @moduledoc """
  TURN credentials for self-hosted Coturn server.
  Uses HMAC-SHA1 time-limited credential scheme (RFC 8489).
  Requires env vars: TURN_SECRET, TURN_URL
  """
  @behaviour Cromulent.Turn.Provider

  @impl true
  def get_ice_servers(user_id) do
    secret = System.get_env("TURN_SECRET") || raise "TURN_SECRET env var not set"
    turn_url = System.get_env("TURN_URL") || raise "TURN_URL env var not set"

    ttl = System.system_time(:second) + 3600
    username = "#{ttl}:#{user_id}"
    # Use :crypto.mac/4 — :crypto.hmac/3 was removed in OTP 26
    password = :crypto.mac(:hmac, :sha, secret, username) |> Base.encode64()

    {:ok,
     [
       %{urls: "stun:stun.l.google.com:19302"},
       %{urls: turn_url, username: username, credential: password}
     ]}
  end
end
