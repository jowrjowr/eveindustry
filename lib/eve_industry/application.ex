defmodule EveIndustry.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # data-specific caches
      Supervisor.child_spec({Cachex, name: :adjusted_price}, id: :adjusted_price),
      Supervisor.child_spec({Cachex, name: :min_sell_price}, id: :min_sell_price),
      Supervisor.child_spec({Cachex, name: :max_buy_price}, id: :max_buy_price),
      EveIndustry.Repo,
      EveIndustry.Scheduled.PriceUpdater,
      {Phoenix.PubSub, name: EveIndustry.PubSub},
      EveIndustryWeb.Endpoint

    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EveIndustry.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    EveIndustryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
