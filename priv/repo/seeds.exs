# Script for populating the database. Run with: mix run priv/repo/seeds.exs
#
# Safe to re-run: skips seeding when any author already exists.

alias Goatmire.Blog

case Blog.list_authors!() do
  [] ->
    author =
      Blog.create_author!(%{name: "Ada Lovelace"})

    Blog.create_post!(%{
      title: "Notes on the Analytical Engine",
      body: "A sample post so the UI is not empty on first boot.",
      author_id: author.id
    })

    Blog.create_post!(%{
      title: "Hello from Ash + LiveView",
      body: "Open /blog in two tabs and create another post to see PubSub updates.",
      author_id: author.id
    })

    IO.puts("Seeded author “#{author.name}” with 2 posts.")

  authors ->
    IO.puts("Skipping seeds — #{length(authors)} author(s) already present.")
end
