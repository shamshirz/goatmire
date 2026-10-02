# Goatmire — Ash + LiveView + Hologram + Gleam learning app

Minimal example of **Ash Framework** resources with three interactive UIs for the
same domain:

- **Phoenix LiveView** at `/blog`
- **Hologram** at `/hologram`
- **Gleam/Lustre SPA** at `/gleam` (JSON API + SSE)

No authentication. Data is stored in **SQLite** via **AshSqlite** (chosen so this
shared VM boots cleanly without installing Postgres).

## Domain model

- `Goatmire.Blog.Author` — `name`
- `Goatmire.Blog.Post` — `title`, `body`, `belongs_to :author`
- `Author` `has_many :posts`

## Prerequisites

- Elixir `~> 1.17` and Erlang/OTP 26+ (this VM uses Elixir 1.18.2 / OTP 27)
- **Gleam** `>= 1.6` on `PATH` (for the `/gleam` UI; `gleam --version`)
- SQLite 3 (`sqlite3` on PATH)
- Hex / Rebar (`mix local.hex`, `mix local.rebar`)
- Node.js 20+ / npm (Hologram’s compiler installs JS deps under `deps/hologram/assets`)

On this shared VM, put the toolchain on `PATH` first:

```bash
export PATH="$HOME/.elixir-install/installs/otp/27.2/bin:$HOME/.elixir-install/installs/elixir/1.18.2-otp-27/bin:$HOME/.local/bin:$PATH"
# Optional symlink layout used by older notes:
# export PATH="/home/ubuntu/.local/elixir/1.18.2/bin:/home/ubuntu/.local/otp/OTP-27.2/bin:$HOME/.local/bin:$PATH"
```

If Elixir TLS to Hex fails in a proxied environment, also set:

```bash
export HEX_UNSAFE_HTTPS=1
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

and install Hex/Rebar without `builds.hex.pm` if needed (`mix archive.install github hexpm/hex`, manual `rebar3`).

## Install deps

```bash
cd /agent/goatmire
mix deps.get
mix assets.setup
```

## Create & migrate the database

```bash
mix ash_sqlite.create
mix ash_sqlite.generate_migrations --name init_blog
mix ash_sqlite.migrate
mix run priv/repo/seeds.exs
```

Or in one step after migrations exist:

```bash
mix setup
```

`mix setup` / `mix assets.build` also compile the Gleam Lustre SPA into
`priv/static/assets/gleam/` via `mix assets.gleam`.

## Start the server

For **LiveView + Gleam** (Hologram off):

```bash
mix phx.server
```

For **LiveView + Hologram + Gleam** (required to use `/hologram` in dev/test):

```bash
mix holo
# equivalent: HOLOGRAM_START=1 mix phx.server
```

`mix holo` enables the Hologram compiler and client runtime. Plain
`mix phx.server` still serves `/blog` and `/gleam`; `/hologram` needs `HOLOGRAM_START=1`.

This app pins **Hologram `~> 0.10.1`** (works on Elixir 1.18 / OTP 27). Hologram
0.11+ needs Elixir 1.19 and OTP 28.1+.

Rebuild Gleam alone after editing `assets/gleam`:

```bash
mix assets.gleam
```

## URLs

| URL | Purpose |
| --- | --- |
| http://localhost:4000/blog | LiveView demo (create/list authors & posts) |
| http://localhost:4000/hologram | Hologram demo (same domain, isomorphic UI) |
| http://localhost:4000/gleam | Gleam/Lustre SPA (JSON API + SSE) |
| http://localhost:4000/ | Home (links to all demos) |
| http://localhost:4000/dev/dashboard | LiveDashboard (dev only) |
| http://localhost:4000/api/authors | JSON list (used by Gleam) |
| http://localhost:4000/api/blog/events | SSE blog change stream |

## Multi-tab reactivity

- **LiveView `/blog`** — resources use `Ash.Notifier.PubSub`;
  `GoatmireWeb.BlogLive` subscribes via `AshPhoenix.LiveView.keep_live/4`.
- **Hologram `/hologram`** — page subscribes to Hologram Realtime channel
  `:blog`. Creates broadcast on that channel; `GoatmireWeb.HologramBlogBridge`
  also forwards Ash PubSub `authors:changed` / `posts:changed` into
  `Hologram.Realtime.broadcast_action/2`, so LiveView creates refresh open
  Hologram tabs too.
- **Gleam `/gleam`** — browser state + `fetch` to `/api/*`. An `EventSource` on
  `/api/blog/events` listens to the same Ash PubSub topics and refetches the
  author list when anything changes (including creates from LiveView/Hologram).

See Project Agent Store docs (`gleam-comparison.md`, `hologram-comparison.md`,
`ash-liveview-app.md`) for side-by-side walkthroughs.
