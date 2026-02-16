defmodule CromulentWeb.Presence do
  use Phoenix.Presence,
    otp_app: :cromulent,
    pubsub_server: Cromulent.PubSub
end
