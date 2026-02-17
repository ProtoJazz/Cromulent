defmodule Cromulent.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CromulentWeb.Telemetry,
      Cromulent.Repo,
      {DNSCluster, query: Application.get_env(:cromulent, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Cromulent.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Cromulent.Finch},
      # Start a worker by calling: Cromulent.Worker.start_link(arg)
      # {Cromulent.Worker, arg},
      # Start to serve requests, typically the last entry
      CromulentWeb.Presence,
      Cromulent.VoiceState,
      {Registry, keys: :unique, name: Cromulent.RoomRegistry},
      {DynamicSupervisor, name: Cromulent.RoomSupervisor, strategy: :one_for_one},
      CromulentWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cromulent.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CromulentWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
