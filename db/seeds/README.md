# Enact demo seed

Seeds one Portfolio + four typed PortfolioItem children (Artefact / Event /
Literature / Collection), each with an image file, full compound metadata,
public visibility, ingested + characterised + with derivatives generated,
and the Portfolio wired so Universal Viewer shows all four children as
canvases.

## One-time setup: placeholder images

Inside the web container, generate four 1200x800 PNGs (used as canvas
content for each child):

```sh
docker exec enact_knapsack-web-1 sh -c '
  mkdir -p /tmp/enact_seed && cd /tmp/enact_seed
  convert -size 1200x800 xc:"#2c3e50" -gravity center -fill white -pointsize 64 \
    -annotate +0-40 "Lacrimae Rerum" \
    -pointsize 28 -fill "#bdc3c7" -annotate +0+40 "Full Score (composition)" \
    artefact-score.png
  convert -size 1200x800 xc:"#34495e" -gravity center -fill white -pointsize 56 \
    -annotate +0-50 "Three Performances of Erasure" \
    -pointsize 24 -fill "#bdc3c7" -annotate +0+30 "Tate Modern, London 2024-08" \
    event-exhibition.png
  convert -size 1200x800 xc:"#7f8c8d" -gravity center -fill white -pointsize 48 \
    -annotate +0-60 "Notes on Erasure" \
    -pointsize 34 -annotate +0-10 "as Compositional Method" \
    -pointsize 22 -fill "#bdc3c7" -annotate +0+40 "Journal article" \
    literature-article.png
  convert -size 1200x800 xc:"#95a5a6" -gravity center -fill white -pointsize 56 \
    -annotate +0-40 "Workbook \& Sketchbooks" \
    -pointsize 30 -fill "#ecf0f1" -annotate +0+40 "2024-2025 curated_set" \
    collection-sketchbook.png
'
```

Substitute your own assets here for a more interesting demo.

## Run the seed

```sh
# (Optional) wipe existing Portfolio / PortfolioItem records first
docker exec -i enact_knapsack-web-1 sh -c \
  'cd /app/samvera/hyrax-webapp && bundle exec rails runner /app/samvera/db/seeds/enact_demo_wipe.rb'

# Then seed
docker exec -i enact_knapsack-web-1 sh -c \
  'cd /app/samvera/hyrax-webapp && bundle exec rails runner /app/samvera/db/seeds/enact_demo.rb'
```

Open `https://dev-enact-knapsack.localhost.direct/concern/portfolios/<id>` — UV renders with all four children in the left filmstrip, all rows badge as Public, and the catalog shows them with thumbnails + Type / Subtype facets.

## Environment overrides

| Env var | Default | Purpose |
| --- | --- | --- |
| `ENACT_DEMO_TENANT` | `dev-enact-knapsack.localhost.direct` | `AccountElevator.switch!` target |
| `ENACT_DEMO_ADMIN_EMAIL` | `admin@example.com` | Depositor for every seeded record |
| `ENACT_DEMO_FILES_DIR` | `/tmp/enact_seed` | Directory holding the four placeholder PNGs |
