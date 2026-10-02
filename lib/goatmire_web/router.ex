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

  # SSE is text/event-stream; EventSource sets Accept accordingly.
  pipeline :sse do
    plug :put_secure_browser_headers
  end

  scope "/", GoatmireWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Ash + LiveView learning UI (Author has_many Posts)
    live "/blog", BlogLive, :index

    # Gleam/Lustre SPA shell (assets built from assets/gleam)
    get "/gleam", GleamController, :index

    # /hologram is served by Hologram (GoatmireWeb.Hologram.BlogPage) via
    # `plug Hologram.Router` in the endpoint — not a Phoenix live route.
  end

  scope "/api", GoatmireWeb.Api do
    pipe_through :api

    get "/authors", BlogController, :index_authors
    post "/authors", BlogController, :create_author
    post "/posts", BlogController, :create_post
  end

  scope "/api", GoatmireWeb.Api do
    pipe_through :sse

    get "/blog/events", BlogController, :events
  end

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
