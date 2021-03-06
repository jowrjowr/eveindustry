# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :eve_industry,
  ecto_repos: [EveIndustry.Repo]

config :eve_industry, EveIndustry.Repo, database: "priv/sde/eve.db"

# Configures the endpoint
config :eve_industry, EveIndustryWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "AZYLbeRdVL835h6vB3voTKZOdM1dottSbU8KcklnsMhCYRvuyRbZRWBr6ZAahJyT",
  render_errors: [view: EveIndustryWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: EveIndustry.PubSub,
  live_view: [signing_salt: "kNYJCFPj"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :logger, level: :info

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
