defmodule Goatmire.Blog do
  @moduledoc """
  Blog domain: authors and their posts.

  Code interfaces below are thin wrappers so LiveViews can call
  `Goatmire.Blog.create_author!(%{name: "Ada"})` instead of building
  Ash changesets by hand.
  """

  use Ash.Domain

  resources do
    resource Goatmire.Blog.Author do
      define :list_authors, action: :read
      define :create_author, action: :create
    end

    resource Goatmire.Blog.Post do
      define :list_posts, action: :read
      define :create_post, action: :create
    end
  end
end
