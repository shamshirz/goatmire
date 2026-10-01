defmodule GoatmireWeb.Router do
  use GoatmireWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GoatmireWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GoatmireWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Ash + LiveView learning UI (Author has_many Posts)
    live "/blog", BlogLive, :index

    # /hologram is served by Hologram (GoatmireWeb.Hologram.BlogPage) via
    # `plug Hologram.Router` in the endpoint — not a Phoenix live route.
  end

  # Other scopes may use custom stacks.
  # scope "/api", GoatmireWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:goatmire, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GoatmireWeb.Telemetry
    end
  end
end
