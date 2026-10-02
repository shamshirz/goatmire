defmodule GoatmireWeb.GleamController do
  @moduledoc """
  Serves the HTML shell that mounts the Gleam/Lustre SPA at `/gleam`.
  """

  use GoatmireWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
