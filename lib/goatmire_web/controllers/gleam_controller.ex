defmodule GoatmireWeb.GleamController do
  @moduledoc """
  Serves the HTML shell that mounts a Lustre **server component** at `/gleam`.

  The browser loads `lustre-server-component.min.mjs` and connects to
  `GoatmireWeb.GleamSocket` at `/gleam/socket/websocket`. Gleam/Ash run on the BEAM.
  """

  use GoatmireWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
