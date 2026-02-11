defmodule Cromulent.Repo do
  use Ecto.Repo,
    otp_app: :cromulent,
    adapter: Ecto.Adapters.Postgres
end
