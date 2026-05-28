# Enact demo seeds

Two seeds live here, both driven by `rake enact:demo:*` tasks:

- **`enact_demo.rb`** — one Portfolio + four typed children. Reference seed for local dev.
- **`enact_demo_multi.rb`** — four Portfolios + sixteen typed children across music composition, visual art, theatre, and dance. Used for the client demo.

Each child has a themed 1200x800 placeholder PNG attached, full compound metadata, public visibility, and ingest + characterise + derivatives run synchronously. Each Portfolio's `representative_id` / `thumbnail_id` point at the first child's FileSet so Universal Viewer bootstraps and aggregates all children.

## Quick path: rake tasks

| Task | What it does |
|---|---|
| `rake enact:demo:images` | Generate sixteen themed PNGs via `generate_demo_images.sh` |
| `rake enact:demo:wipe` | Delete every Portfolio + PortfolioItem in `$ENACT_DEMO_TENANT` |
| `rake enact:demo:seed` | Run the multi-portfolio seed (4 portfolios, 16 items) |
| `rake enact:demo:seed_single` | Run the single-portfolio reference seed |
| `rake enact:demo:all` | `images` + `wipe` + `seed` |

### Run against staging demo tenant

```sh
kubectl exec -n enact-knapsack-staging deploy/enact-knapsack-staging -c hyrax -- \
  bash -c 'cd /app/samvera/hyrax-webapp && \
           ENACT_DEMO_TENANT=demo.enact-knapsack-staging.enacthyku.com \
           bundle exec rake enact:demo:all'
```

Expect ~4 minutes of run time (one ingest + characterize + derivative pipeline per file).

### Run against local dev

```sh
docker exec enact_knapsack-web-1 bash -c 'cd /app/samvera/hyrax-webapp && bundle exec rake enact:demo:all'
```

The local dev tenant default works without explicit env vars.

## Environment overrides

| Env var | Default | Purpose |
|---|---|---|
| `ENACT_DEMO_TENANT` | `demo.enact-knapsack-staging.enacthyku.com` (multi) / `dev-enact-knapsack.localhost.direct` (single) | `AccountElevator.switch!` target |
| `ENACT_DEMO_ADMIN_EMAIL` | `admin@example.com` | Depositor for every seeded record |
| `ENACT_DEMO_FILES_DIR` | `/tmp/enact_seed` | Directory the seed reads PNGs from and the script writes them to |

## Content overview (multi)

| # | Portfolio | Discipline | REF UoA |
|---|---|---|---|
| 1 | Bonfire of the Manuscripts | Music composition | 33 |
| 2 | Ten Walks Across the Fens | Visual art / drawing | 32 |
| 3 | The Glassmaker's Daughter | Playwriting / theatre | 33 |
| 4 | Bodies in Common Ground | Community dance | 33 |

Each Portfolio has Artefact / Event / Literature / Collection children. View any portfolio at `https://<tenant>/concern/portfolios/<id>`.
