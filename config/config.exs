# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :goatmire,
  ecto_repos: [Goatmire.Repo],
  ash_domains: [Goatmire.Blog],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Required by Ash 3.33+: how string length constraints are counted.
config :ash, :default_string_length_count, :codepoints

# Ash uses Spark formatters; keep resource DSLs tidy when running `mix format`.
config :spark, :formatter,
  remove_parens?: true,
  "Ash.Resource": [
    section_order: [
      :sqlite,
      :resource,
      :code_interface,
      :actions,
      :attributes,
      :relationships,
      :identities,
      :aggregates,
      :calculations,
      :pub_sub
    ]
  ]

# Configure the endpoint
config :goatmire, GoatmireWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: GoatmireWeb.ErrorHTML, json: GoatmireWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Goatmire.PubSub,
  live_view: [signing_salt: "x3SJ97W8"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  goatmire: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  goatmire: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

