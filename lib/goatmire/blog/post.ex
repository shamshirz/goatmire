defmodule Goatmire.Blog.Post do
  @moduledoc """
  A post that belongs to one author (`belongs_to :author`).
  """

  use Ash.Resource,
    otp_app: :goatmire,
    domain: Goatmire.Blog,
    data_layer: AshSqlite.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  sqlite do
    table "posts"
    repo Goatmire.Repo
  end

  pub_sub do
    module GoatmireWeb.Endpoint
    prefix "posts"
    publish_all :create, "changed"
    publish_all :update, "changed"
    publish_all :destroy, "changed"
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :body, :string do
      allow_nil? false
      public? true
      default ""
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :author, Goatmire.Blog.Author do
      allow_nil? false
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title, :body, :author_id]
    end

    update :update do
      primary? true
      accept [:title, :body]
    end
  end
end
