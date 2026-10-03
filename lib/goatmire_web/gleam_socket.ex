defmodule GoatmireWeb.GleamSocket do
  @moduledoc """
  Phoenix.Socket.Transport for a per-connection Lustre **server component**.

  Each browser tab gets its own Gleam/Lustre runtime on the BEAM. Ash is called
  in-process from Gleam via `Goatmire.Blog.GleamFacade`. Ash PubSub notifications
  are forwarded as `:blog_changed` so open tabs refetch (same class of sync as
  LiveView `keep_live` / Hologram Realtime).
  """

  @behaviour Phoenix.Socket.Transport

  require Logger

  @impl true
  def child_spec(_opts) do
    :ignore
  end

  @impl true
  def connect(map) do
    Goatmire.GleamLoader.ensure_loaded!()
    {:ok, Map.take(map, [:connect_info])}
  end

  @impl true
  def init(state) do
    {:module, _} = Code.ensure_loaded(:goatmire_gleam)
    app = apply(:goatmire_gleam, :component, [])
    {:ok, runtime} = :lustre.start_server_component(app, nil)

    subject = :gleam@erlang@process.new_subject()
    :lustre.send(runtime, :lustre@server_component.register_subject(subject))

    :ok = Phoenix.PubSub.subscribe(Goatmire.PubSub, "authors:changed")
    :ok = Phoenix.PubSub.subscribe(Goatmire.PubSub, "posts:changed")

    {:ok, Map.merge(state, %{runtime: runtime, subject: subject})}
  end

  @impl true
  def handle_in({msg, _opts}, state) when is_binary(msg) do
    case :gleam@json.parse(msg, :lustre@server_component.runtime_message_decoder()) do
      {:ok, runtime_message} ->
        :lustre.send(state.runtime, runtime_message)

      {:error, reason} ->
        Logger.debug("GleamSocket ignored client message: #{inspect(reason)}")
    end

    {:ok, state}
  end

  def handle_in(_other, state), do: {:ok, state}

  @impl true
  def handle_info({tag, client_message}, %{subject: {:subject, _pid, tag}} = state) do
    json =
      client_message
      |> :lustre@server_component.client_message_to_json()
      |> :gleam@json.to_string()

    {:push, {:text, json}, state}
  end

  # Ash PubSub → dispatch Gleam Msg BlogChanged (zero-arity → atom :blog_changed)
  def handle_info(msg, state) do
    if blog_notification?(msg) do
      :lustre.send(state.runtime, :lustre.dispatch(:blog_changed))
    end

    {:ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    if runtime = state[:runtime] do
      :lustre.send(runtime, :lustre@server_component.deregister_subject(state.subject))
      :lustre.send(runtime, :lustre.shutdown())
    end

    :ok
  end

  defp blog_notification?(%{payload: %Ash.Notifier.Notification{}}), do: true
  defp blog_notification?(%Ash.Notifier.Notification{}), do: true
  defp blog_notification?(_), do: false
end
