defmodule Goatmire.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GoatmireWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:goatmire, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Goatmire.PubSub},
      Goatmire.Repo,
      # Bridge Ash PubSub → Hologram Realtime for /hologram multi-tab sync
      GoatmireWeb.HologramBlogBridge,
      # Start to serve requests, typically the last entry
      GoatmireWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Goatmire.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GoatmireWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
