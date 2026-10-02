# Goatmire Gleam / Lustre SPA

Browser UI for the shared Ash blog domain. Built with:

```bash
# from repo root
mix assets.gleam
# or:
cd assets/gleam && gleam run -m lustre/dev build
```

Output lands in `priv/static/assets/gleam/` and is served by Phoenix at `/gleam`.
