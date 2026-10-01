defmodule GoatmireWeb.BlogLive do
  @moduledoc """
  Interactive Blog UI: create authors and posts, list them together.

  Multi-tab reactivity:
  1. Resources publish via `Ash.Notifier.PubSub` (see Author/Post).
  2. This LiveView uses `AshPhoenix.LiveView.keep_live/4` to subscribe
     and refetch when notifications arrive.
  3. Open `/blog` in two tabs — create in one, watch the other update.
  """

  use GoatmireWeb, :live_view

  import AshPhoenix.LiveView

  alias Goatmire.Blog

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:author_form, to_form(%{"name" => ""}, as: :author))
      |> assign(:post_form, to_form(%{"title" => "", "body" => "", "author_id" => ""}, as: :post))
      |> keep_live(
        :authors,
        fn _socket ->
          Blog.list_authors!(load: [:posts])
        end,
        subscribe: ["authors:changed", "posts:changed"],
        results: :lose
      )

    {:ok, socket}
  end

  @impl true
  def handle_info(%{topic: topic, payload: %Ash.Notifier.Notification{}}, socket) do
    {:noreply, handle_live(socket, topic, [:authors])}
  end

  def handle_info({:refetch, assign, opts}, socket) do
    {:noreply, handle_live(socket, :refetch, assign, opts)}
  end

  @impl true
  def handle_event("create_author", %{"author" => params}, socket) do
    case Blog.create_author(params) do
      {:ok, author} ->
        {:noreply,
         socket
         |> assign(:author_form, to_form(%{"name" => ""}, as: :author))
         |> put_flash(:info, "Created author “#{author.name}”. Open another tab to see it appear live.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, Exception.message(error))}
    end
  end

  def handle_event("create_post", %{"post" => params}, socket) do
    case Blog.create_post(params) do
      {:ok, post} ->
        {:noreply,
         socket
         |> assign(
           :post_form,
           to_form(%{"title" => "", "body" => "", "author_id" => params["author_id"]}, as: :post)
         )
         |> put_flash(:info, "Created post “#{post.title}”.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, Exception.message(error))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-3xl space-y-10 px-4 py-8">
        <header class="space-y-2">
          <p class="text-sm uppercase tracking-wide text-base-content/60">Ash + LiveView demo</p>
          <h1 class="text-3xl font-bold">Goatmire Blog</h1>
          <p class="text-base-content/80">
            Create an <strong>Author</strong>, then add <strong>Posts</strong> for that author.
            Open this page in two browser tabs — changes sync without refresh via Ash PubSub notifications.
          </p>
        </header>

        <section class="space-y-4" id="create-author">
          <h2 class="text-xl font-semibold">1. Create an author</h2>
          <p class="text-sm text-base-content/70">Start here if the list below is empty.</p>
          <.form for={@author_form} id="author-form" phx-submit="create_author" class="flex flex-wrap gap-3 items-end">
            <div class="grow min-w-48">
              <label class="label py-1" for="author_name">Name</label>
              <input
                id="author_name"
                type="text"
                name="author[name]"
                value={@author_form[:name].value}
                required
                placeholder="e.g. Ada Lovelace"
                class="input input-bordered w-full"
              />
            </div>
            <button type="submit" class="btn btn-primary">Add author</button>
          </.form>
        </section>

        <section class="space-y-4" id="create-post">
          <h2 class="text-xl font-semibold">2. Create a post</h2>
          <%= if @authors == [] do %>
            <p class="rounded-lg bg-warning/20 px-4 py-3 text-sm">
              No authors yet — add one above, then you can attach posts here.
            </p>
          <% else %>
            <.form for={@post_form} id="post-form" phx-submit="create_post" class="space-y-3">
              <div>
                <label class="label py-1" for="post_author_id">Author</label>
                <select id="post_author_id" name="post[author_id]" required class="select select-bordered w-full">
                  <option value="">Choose an author…</option>
                  <%= for author <- @authors do %>
                    <option value={author.id} selected={@post_form[:author_id].value == author.id}>
                      {author.name}
                    </option>
                  <% end %>
                </select>
              </div>
              <div>
                <label class="label py-1" for="post_title">Title</label>
                <input
                  id="post_title"
                  type="text"
                  name="post[title]"
                  value={@post_form[:title].value}
                  required
                  placeholder="Post title"
                  class="input input-bordered w-full"
                />
              </div>
              <div>
                <label class="label py-1" for="post_body">Body</label>
                <textarea
                  id="post_body"
                  name="post[body]"
                  rows="3"
                  placeholder="A short note…"
                  class="textarea textarea-bordered w-full"
                >{@post_form[:body].value}</textarea>
              </div>
              <button type="submit" class="btn btn-secondary">Add post</button>
            </.form>
          <% end %>
        </section>

        <section class="space-y-4" id="authors-list">
          <h2 class="text-xl font-semibold">Authors & posts</h2>
          <%= if @authors == [] do %>
            <p class="rounded-lg border border-dashed border-base-300 px-4 py-8 text-center text-base-content/70">
              Empty state: click <strong>Add author</strong> above to seed your first record.
            </p>
          <% else %>
            <ul class="space-y-6">
              <%= for author <- @authors do %>
                <li class="border-b border-base-300 pb-4" id={"author-#{author.id}"}>
                  <h3 class="text-lg font-medium">{author.name}</h3>
                  <p class="text-xs text-base-content/50 mb-2">{length(author.posts)} post(s)</p>
                  <%= if author.posts == [] do %>
                    <p class="text-sm text-base-content/60 italic">No posts yet for this author.</p>
                  <% else %>
                    <ul class="mt-2 space-y-2 pl-4 list-disc">
                      <%= for post <- author.posts do %>
                        <li id={"post-#{post.id}"}>
                          <span class="font-medium">{post.title}</span>
                          <%= if post.body not in [nil, ""] do %>
                            <span class="text-base-content/70"> — {post.body}</span>
                          <% end %>
                        </li>
                      <% end %>
                    </ul>
                  <% end %>
                </li>
              <% end %>
            </ul>
          <% end %>
        </section>

        <aside class="text-sm text-base-content/60 border-t border-base-300 pt-6">
          <p>
            This UI is LiveView at <code class="px-1">/blog</code>.
            Compare with the Hologram UI at <a href="/hologram" class="link">/hologram</a>
            (start the server with <code class="px-1">mix holo</code>).
          </p>
        </aside>
      </div>
    </Layouts.app>
    """
  end
end
