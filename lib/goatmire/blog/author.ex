defmodule Goatmire.Blog.Author do
  @moduledoc """
  An author who can write many posts (`has_many :posts`).
  """

  use Ash.Resource,
    otp_app: :goatmire,
    domain: Goatmire.Blog,
    data_layer: AshSqlite.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  sqlite do
    table "authors"
    repo Goatmire.Repo
  end

  # Broadcast create/update/destroy so LiveViews can refresh other tabs.
  pub_sub do
    module GoatmireWeb.Endpoint
    prefix "authors"
    publish_all :create, "changed"
    publish_all :update, "changed"
    publish_all :destroy, "changed"
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :posts, Goatmire.Blog.Post do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name]
    end

    update :update do
      primary? true
      accept [:name]
    end
  end
end
