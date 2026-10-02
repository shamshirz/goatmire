defmodule GoatmireWeb.Api.BlogController do
  @moduledoc """
  JSON API + SSE for the Gleam/Lustre SPA at `/gleam`.

  Endpoints:
  - `GET  /api/authors` — list authors with nested posts
  - `POST /api/authors` — create author `%{name: ...}`
  - `POST /api/posts` — create post `%{title, body, author_id}`
  - `GET  /api/blog/events` — SSE stream of Ash PubSub blog changes
  """

  use GoatmireWeb, :controller

  alias Goatmire.Blog

  def index_authors(conn, _params) do
    authors = Blog.list_authors!(load: [:posts]) |> Enum.map(&dump_author/1)
    json(conn, %{data: authors})
  end

  def create_author(conn, params) do
    attrs = pick(params, ["name"])

    case Blog.create_author(attrs) do
      {:ok, author} ->
        author = Ash.load!(author, [:posts])

        conn
        |> put_status(:created)
        |> json(%{data: dump_author(author)})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: Exception.message(error)})
    end
  end

  def create_post(conn, params) do
    attrs = pick(params, ["title", "body", "author_id"])

    case Blog.create_post(attrs) do
      {:ok, post} ->
        conn
        |> put_status(:created)
        |> json(%{data: dump_post(post)})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: Exception.message(error)})
    end
  end

  @doc """
  Server-Sent Events: subscribe to Ash PubSub `authors:changed` /
  `posts:changed` and emit `blog_changed` so open Gleam tabs can refetch.
  """
  def events(conn, _params) do
    :ok = Phoenix.PubSub.subscribe(Goatmire.PubSub, "authors:changed")
    :ok = Phoenix.PubSub.subscribe(Goatmire.PubSub, "posts:changed")

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    case chunk(conn, ": connected\n\n") do
      {:ok, conn} -> sse_loop(conn)
      {:error, :closed} -> conn
    end
  end

  defp sse_loop(conn) do
    receive do
      msg ->
        if blog_notification?(msg) do
          case chunk(conn, "event: blog_changed\ndata: {}\n\n") do
            {:ok, conn} -> sse_loop(conn)
            {:error, :closed} -> conn
          end
        else
          sse_loop(conn)
        end
    after
      25_000 ->
        case chunk(conn, ": ping\n\n") do
          {:ok, conn} -> sse_loop(conn)
          {:error, :closed} -> conn
        end
    end
  end

  defp blog_notification?(%{payload: %Ash.Notifier.Notification{}}), do: true
  defp blog_notification?(%Ash.Notifier.Notification{}), do: true
  defp blog_notification?(_), do: false

  defp dump_author(author) do
    posts =
      case Map.get(author, :posts) do
        list when is_list(list) -> Enum.map(list, &dump_post/1)
        _ -> []
      end

    %{
      id: to_string(author.id),
      name: author.name,
      posts: posts
    }
  end

  defp dump_post(post) do
    %{
      id: to_string(post.id),
      title: post.title,
      body: post.body || "",
      author_id: post.author_id && to_string(post.author_id)
    }
  end

  defp pick(params, keys) do
    # JSON bodies arrive with string keys; tolerate atom keys too.
    Enum.reduce(keys, %{}, fn key, acc ->
      value =
        cond do
          Map.has_key?(params, key) ->
            Map.get(params, key)

          true ->
            atom_key =
              try do
                String.to_existing_atom(key)
              rescue
                ArgumentError -> nil
              end

            if atom_key, do: Map.get(params, atom_key), else: nil
        end

      Map.put(acc, key, value)
    end)
  end
end
