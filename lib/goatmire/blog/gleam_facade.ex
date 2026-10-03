defmodule Goatmire.Blog.GleamFacade do
  @moduledoc """
  Thin Elixir façade so the Gleam/Lustre **server component** can call Ash
  in-process via `@external(erlang, ...)`.

  Returns plain string-keyed maps (and `{:ok, map} | {:error, binary}`) that
  Gleam decodes — no JSON HTTP hop.
  """

  alias Goatmire.Blog

  @doc "List authors with nested posts as string-keyed maps."
  def list_authors do
    Blog.list_authors!(load: [:posts])
    |> Enum.map(&dump_author/1)
  end

  @doc "Create an author by name. Returns `{:ok, map}` or `{:error, message}`."
  def create_author(name) when is_binary(name) do
    case Blog.create_author(%{name: name}) do
      {:ok, author} ->
        author = Ash.load!(author, [:posts])
        {:ok, dump_author(author)}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  @doc "Create a post. Returns `{:ok, map}` or `{:error, message}`."
  def create_post(author_id, title, body)
      when is_binary(author_id) and is_binary(title) and is_binary(body) do
    attrs = %{author_id: author_id, title: title, body: body}

    case Blog.create_post(attrs) do
      {:ok, post} ->
        {:ok, dump_post(post)}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp dump_author(author) do
    posts =
      case Map.get(author, :posts) do
        list when is_list(list) -> Enum.map(list, &dump_post/1)
        _ -> []
      end

    %{
      "id" => to_string(author.id),
      "name" => author.name,
      "posts" => posts
    }
  end

  defp dump_post(post) do
    %{
      "id" => to_string(post.id),
      "title" => post.title,
      "body" => post.body || "",
      "author_id" => post.author_id && to_string(post.author_id)
    }
  end
end
