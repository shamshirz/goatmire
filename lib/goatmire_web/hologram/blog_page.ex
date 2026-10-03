defmodule GoatmireWeb.Hologram.BlogPage do
  @moduledoc """
  Hologram counterpart to `GoatmireWeb.BlogLive`.

  Same Ash Blog domain (authors has_many posts). Multi-tab updates use
  Hologram Realtime on channel `:blog`, fed by Ash PubSub via
  `GoatmireWeb.HologramBlogBridge` (and by creates from this page).
  """

  use Hologram.Page

  alias Goatmire.Blog

  route "/hologram"

  layout GoatmireWeb.Hologram.MainLayout, page_title: "Goatmire · Hologram"

  @impl true
  def init(_params, component, server) do
    component =
      put_state(component,
        authors: load_authors(),
        author_name: "",
        post_author_id: "",
        post_title: "",
        post_body: "",
        flash: nil,
        error: nil
      )

    server = put_subscription(server, :blog)

    {component, server}
  end

  # --- Client actions -------------------------------------------------------

  @impl true
  def action(:author_name_changed, params, component) do
    put_state(component, :author_name, params.event.value)
  end

  def action(:post_author_changed, params, component) do
    put_state(component, :post_author_id, params.event.value)
  end

  def action(:post_title_changed, params, component) do
    put_state(component, :post_title, params.event.value)
  end

  def action(:post_body_changed, params, component) do
    put_state(component, :post_body, params.event.value)
  end

  def action(:create_author, params, component) do
    # Prefer form $submit payload (params.event); fall back to synced state.
    name =
      params.event
      |> form_value(:name)
      |> then(fn
        "" -> component.state.author_name || ""
        value -> value
      end)
      |> String.trim()

    component
    |> put_state(flash: nil, error: nil)
    |> put_command(:create_author, name: name)
  end

  def action(:create_post, params, component) do
    event = params.event

    author_id = form_value(event, :author_id) |> fallback(component.state.post_author_id)
    title = form_value(event, :title) |> fallback(component.state.post_title) |> String.trim()
    body = form_value(event, :body) |> fallback(component.state.post_body)

    component
    |> put_state(flash: nil, error: nil)
    |> put_command(:create_post, author_id: author_id, title: title, body: body)
  end

  def action(:blog_changed, _params, component) do
    put_command(component, :reload_authors)
  end

  def action(:set_authors, %{authors: authors}, component) do
    put_state(component, :authors, authors)
  end

  def action(:author_created, %{name: name}, component) do
    put_state(component,
      author_name: "",
      flash: "Created author “#{name}”. Open another tab to see it appear live.",
      error: nil
    )
  end

  def action(:post_created, %{title: title, author_id: author_id}, component) do
    put_state(component,
      post_title: "",
      post_body: "",
      post_author_id: author_id,
      flash: "Created post “#{title}”.",
      error: nil
    )
  end

  def action(:flash_error, %{message: message}, component) do
    put_state(component, flash: nil, error: message)
  end

  # --- Server commands ------------------------------------------------------

  @impl true
  def command(:create_author, params, server) do
    case Blog.create_author(%{name: params.name}) do
      {:ok, author} ->
        # Ash PubSub → HologramBlogBridge broadcasts :blog_changed to subscribed tabs.
        put_action(server, :author_created, name: author.name)

      {:error, error} ->
        put_action(server, :flash_error, message: Exception.message(error))
    end
  end

  def command(:create_post, params, server) do
    attrs = %{
      title: params.title,
      body: params.body,
      author_id: params.author_id
    }

    case Blog.create_post(attrs) do
      {:ok, post} ->
        # List refresh for all tabs comes from Ash PubSub → HologramBlogBridge.
        put_action(server, :post_created, title: post.title, author_id: params.author_id)

      {:error, error} ->
        put_action(server, :flash_error, message: Exception.message(error))
    end
  end

  def command(:reload_authors, _params, server) do
    put_action(server, :set_authors, authors: load_authors())
  end

  # --- Template -------------------------------------------------------------

  @impl true
  def template do
    ~HOLO"""
    <div class="mx-auto max-w-3xl space-y-10 px-4 py-8">
      <header class="space-y-2">
        <p class="text-sm uppercase tracking-wide text-base-content/60">Ash + Hologram demo</p>
        <h1 class="text-3xl font-bold">Goatmire Blog</h1>
        <p class="text-base-content/80">
          Same domain as the LiveView demo: create an <strong>Author</strong>, then add
          <strong>Posts</strong>. Open this page in two browser tabs — changes sync via
          Hologram Realtime (bridged from Ash PubSub).
        </p>
      </header>

      {%if @flash}
        <div class="rounded-lg bg-success/20 px-4 py-3 text-sm" role="status">{@flash}</div>
      {/if}
      {%if @error}
        <div class="rounded-lg bg-error/20 px-4 py-3 text-sm" role="alert">{@error}</div>
      {/if}

      <section class="space-y-4" id="create-author">
        <h2 class="text-xl font-semibold">1. Create an author</h2>
        <p class="text-sm text-base-content/70">Start here if the list below is empty.</p>
        <form id="author-form" class="flex flex-wrap gap-3 items-end" $submit="create_author">
          <div class="grow min-w-48">
            <label class="label py-1" for="hologram_author_name">Name</label>
            <input
              id="hologram_author_name"
              type="text"
              name="name"
              value={@author_name}
              required
              placeholder="e.g. Ada Lovelace"
              class="input input-bordered w-full"
              $change="author_name_changed"
            />
          </div>
          <button type="submit" class="btn btn-primary">Add author</button>
        </form>
      </section>

      <section class="space-y-4" id="create-post">
        <h2 class="text-xl font-semibold">2. Create a post</h2>
        {%if @authors == []}
          <p class="rounded-lg bg-warning/20 px-4 py-3 text-sm">
            No authors yet — add one above, then you can attach posts here.
          </p>
        {%else}
          <form id="post-form" class="space-y-3" $submit="create_post">
            <div>
              <label class="label py-1" for="hologram_post_author_id">Author</label>
              <select
                id="hologram_post_author_id"
                name="author_id"
                required
                class="select select-bordered w-full"
                value={@post_author_id}
                $change="post_author_changed"
              >
                <option value="">Choose an author…</option>
                {%for author <- @authors}
                  <option value={author.id}>{author.name}</option>
                {/for}
              </select>
            </div>
            <div>
              <label class="label py-1" for="hologram_post_title">Title</label>
              <input
                id="hologram_post_title"
                type="text"
                name="title"
                value={@post_title}
                required
                placeholder="Post title"
                class="input input-bordered w-full"
                $change="post_title_changed"
              />
            </div>
            <div>
              <label class="label py-1" for="hologram_post_body">Body</label>
              <textarea
                id="hologram_post_body"
                name="body"
                rows="3"
                placeholder="A short note…"
                class="textarea textarea-bordered w-full"
                value={@post_body}
                $change="post_body_changed"
              ></textarea>
            </div>
            <button type="submit" class="btn btn-secondary">Add post</button>
          </form>
        {/if}
      </section>

      <section class="space-y-4" id="authors-list">
        <h2 class="text-xl font-semibold">Authors & posts</h2>
        {%if @authors == []}
          <p class="rounded-lg border border-dashed border-base-300 px-4 py-8 text-center text-base-content/70">
            Empty state: click <strong>Add author</strong> above to seed your first record.
          </p>
        {%else}
          <ul class="space-y-6">
            {%for author <- @authors}
              <li class="border-b border-base-300 pb-4" id={"author-#{author.id}"}>
                <h3 class="text-lg font-medium">{author.name}</h3>
                <p class="text-xs text-base-content/50 mb-2">{length(author.posts)} post(s)</p>
                {%if author.posts == []}
                  <p class="text-sm text-base-content/60 italic">No posts yet for this author.</p>
                {%else}
                  <ul class="mt-2 space-y-2 pl-4 list-disc">
                    {%for post <- author.posts}
                      <li id={"post-#{post.id}"}>
                        <span class="font-medium">{post.title}</span>
                        {%if post.body != ""}
                          <span class="text-base-content/70"> — {post.body}</span>
                        {/if}
                      </li>
                    {/for}
                  </ul>
                {/if}
              </li>
            {/for}
          </ul>
        {/if}
      </section>

      <aside class="text-sm text-base-content/60 border-t border-base-300 pt-6 space-y-1">
        <p>
          This UI is Hologram at <code class="px-1">/hologram</code>.
          Compare with LiveView at <a href="/blog" class="link">/blog</a>
          and the Gleam/Lustre server component at <a href="/gleam" class="link">/gleam</a>.
        </p>
        <p>
          Start the server with <code class="px-1">mix holo</code> (or
          <code class="px-1">HOLOGRAM_START=1 mix phx.server</code>) so Hologram’s
          compiler and runtime are enabled in dev.
        </p>
      </aside>
    </div>
    """
  end

  # --- Client helpers -------------------------------------------------------

  defp form_value(event, key) when is_map(event) do
    cond do
      Map.has_key?(event, key) -> event[key] || ""
      Map.has_key?(event, Atom.to_string(key)) -> event[Atom.to_string(key)] || ""
      true -> ""
    end
  end

  defp form_value(_, _), do: ""

  defp fallback("", other), do: other || ""
  defp fallback(nil, other), do: other || ""
  defp fallback(value, _other), do: value

  # --- Data helpers (server-only; used from init/commands) -------------------

  defp load_authors do
    Blog.list_authors!(load: [:posts])
    |> Enum.map(&dump_author/1)
  end

  defp dump_author(author) do
    posts =
      case author.posts do
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
      body: post.body || ""
    }
  end
end
