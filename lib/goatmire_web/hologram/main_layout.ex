defmodule GoatmireWeb.Hologram.MainLayout do
  @moduledoc """
  Root layout for Hologram pages. Mirrors the Phoenix app chrome lightly
  (CSS + nav) without loading LiveView's JS runtime.
  """

  use Hologram.Component

  alias Hologram.UI.Runtime

  prop :page_title, :string, default: "Goatmire"

  def template do
    ~HOLO"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>{@page_title}</title>
        <link phx-track-static rel="stylesheet" href="/assets/css/app.css" />
        <Runtime />
      </head>
      <body class="min-h-screen bg-base-100 text-base-content">
        <header class="navbar px-4 sm:px-6 lg:px-8 border-b border-base-300">
          <div class="flex-1">
            <a href="/" class="flex items-center gap-2">
              <img src="/images/logo.svg" width="36" alt="Goatmire" />
              <span class="text-sm font-semibold">Goatmire</span>
            </a>
          </div>
          <div class="flex-none">
            <ul class="flex space-x-3 items-center">
              <li>
                <a href="/blog" class="btn btn-ghost btn-sm">LiveView /blog</a>
              </li>
              <li>
                <a href="/hologram" class="btn btn-primary btn-sm">Hologram /hologram</a>
              </li>
            </ul>
          </div>
        </header>
        <main>
          <slot />
        </main>
      </body>
    </html>
    """
  end
end
