defmodule GoatmireWeb.HologramBlogBridge do
  @moduledoc """
  Forwards Ash PubSub blog notifications into Hologram Realtime.

  LiveView already subscribes to `authors:changed` / `posts:changed` via
  `AshPhoenix.LiveView.keep_live/4`. Hologram pages subscribe to the
  `:blog` channel instead; this process bridges the two so a create in
  `/blog` updates open `/hologram` tabs (and vice versa, alongside the
  page’s own `put_broadcast`).
  """

  use GenServer

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ok = Phoenix.PubSub.subscribe(Goatmire.PubSub, "authors:changed")
    :ok = Phoenix.PubSub.subscribe(Goatmire.PubSub, "posts:changed")
    {:ok, %{}}
  end

  @impl true
  def handle_info(msg, state) do
    if blog_notification?(msg) do
      broadcast_hologram()
    end

    {:noreply, state}
  end

  defp blog_notification?(%{payload: %Ash.Notifier.Notification{}}), do: true
  defp blog_notification?(%Ash.Notifier.Notification{}), do: true
  defp blog_notification?(_), do: false

  defp broadcast_hologram do
    if function_exported?(Hologram, :enabled?, 0) and Hologram.enabled?() do
      Hologram.Realtime.broadcast_action(:blog, :blog_changed)
    end
  rescue
    error ->
      Logger.debug("HologramBlogBridge skip broadcast: #{Exception.message(error)}")
  end
end
