# Goatmire — Ash + LiveView + Hologram learning app

Minimal example of **Ash Framework** resources with two interactive UIs for the
same domain:

- **Phoenix LiveView** at `/blog`
- **Hologram** at `/hologram`

No authentication. Data is stored in **SQLite** via **AshSqlite** (chosen so this
shared VM boots cleanly without installing Postgres).

## Domain model

- `Goatmire.Blog.Author` — `name`
- `Goatmire.Blog.Post` — `title`, `body`, `belongs_to :author`
- `Author` `has_many :posts`

## Prerequisites

- Elixir `~> 1.17` and Erlang/OTP 26+ (this VM uses Elixir 1.18.2 / OTP 27 under `~/.local/`)
- SQLite 3 (`sqlite3` on PATH)
- Hex / Rebar (`mix local.hex`, `mix local.rebar`)
- Node.js 20+ / npm (Hologram’s compiler installs JS deps under `deps/hologram/assets`)

On this shared VM, put the toolchain on `PATH` first:

```bash
export PATH="/home/ubuntu/.local/elixir/1.18.2/bin:/home/ubuntu/.local/otp/OTP-27.2/bin:$HOME/.local/bin:$PATH"
```

If Elixir TLS to Hex fails in a proxied environment, also set:

```bash
export HEX_UNSAFE_HTTPS=1
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

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

## Start the server

For **LiveView only**:

```bash
mix phx.server
```

For **LiveView + Hologram** (required to use `/hologram` in dev/test):

```bash
mix holo
# equivalent: HOLOGRAM_START=1 mix phx.server
```

`mix holo` enables the Hologram compiler and client runtime. Plain
`mix phx.server` still serves `/blog`; `/hologram` needs `HOLOGRAM_START=1`.

This app pins **Hologram `~> 0.10.1`** (works on Elixir 1.18 / OTP 27). Hologram
0.11+ needs Elixir 1.19 and OTP 28.1+.

## URLs

| URL | Purpose |
| --- | --- |
| http://localhost:4000/blog | LiveView demo (create/list authors & posts) |
| http://localhost:4000/hologram | Hologram demo (same domain, isomorphic UI) |
| http://localhost:4000/ | Home (links to both demos) |
| http://localhost:4000/dev/dashboard | LiveDashboard (dev only) |

## Multi-tab reactivity

- **LiveView `/blog`** — resources use `Ash.Notifier.PubSub`;
  `GoatmireWeb.BlogLive` subscribes via `AshPhoenix.LiveView.keep_live/4`.
- **Hologram `/hologram`** — page subscribes to Hologram Realtime channel
  `:blog`. Creates broadcast on that channel; `GoatmireWeb.HologramBlogBridge`
  also forwards Ash PubSub `authors:changed` / `posts:changed` into
  `Hologram.Realtime.broadcast_action/2`, so LiveView creates refresh open
  Hologram tabs too.

See `docs/hologram-comparison.md` in the project Agent Store for a side-by-side
walkthrough.
