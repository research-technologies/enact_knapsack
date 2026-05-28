#!/usr/bin/env sh
# Generate sixteen 1200x800 themed PNGs for enact_demo_multi.rb.
# Run inside the web container:
#   kubectl exec -n enact-knapsack-staging deploy/enact-knapsack-staging -c hyrax -- \
#     sh /app/samvera/db/seeds/generate_demo_images.sh

set -eu
OUT="${ENACT_DEMO_FILES_DIR:-/tmp/enact_seed}"
mkdir -p "$OUT"
cd "$OUT"

# Helper. Args: bg-color, accent-color, slug, line1, line2, line3
gen() {
  bg="$1"; accent="$2"; slug="$3"; t1="$4"; t2="$5"; t3="$6"
  convert -size 1200x800 \
    xc:"$bg" \
    -gravity center \
    -fill white -pointsize 60 -annotate +0-80 "$t1" \
    -fill "$accent" -pointsize 36 -annotate +0+10 "$t2" \
    -fill "$accent" -pointsize 26 -annotate +0+80 "$t3" \
    "$slug.png"
}

# Portfolio 1: Bonfire of the Manuscripts (composition - dark navy)
gen "#1f2d3d" "#a9c3e0" bonfire-artefact   "Lacrimae Rerum"              "Full Score"                  "Composition (Artefact)"
gen "#1f2d3d" "#a9c3e0" bonfire-event      "Three Performances of Erasure" "Tate Modern, London"        "Exhibition (Event)"
gen "#1f2d3d" "#a9c3e0" bonfire-literature "Notes on Erasure"            "Journal Article"             "Practice as Research in Music"
gen "#1f2d3d" "#a9c3e0" bonfire-collection "Workbook & Sketchbooks"      "2024-2025"                   "Curated Set (Collection)"

# Portfolio 2: Ten Walks Across the Fens (visual art - earth greens)
gen "#2f3e2e" "#b8c9a6" fens-artefact      "Walk #3: Wicken Fen"         "Charcoal on Khadi"           "Drawing (Artefact)"
gen "#2f3e2e" "#b8c9a6" fens-event         "Saltmarsh Light"             "Sainsbury Centre"            "Solo Exhibition (Event)"
gen "#2f3e2e" "#b8c9a6" fens-literature    "On Walking and Drawing"      "Book Chapter"                "Practice in the Field"
gen "#2f3e2e" "#b8c9a6" fens-collection    "Field Notebooks"             "2023-2024"                   "Curated Set (Collection)"

# Portfolio 3: The Glassmaker's Daughter (theatre - warm amber)
gen "#3d2914" "#e8a85a" glassmaker-artefact   "The Glassmaker's Daughter" "Rehearsal Draft"            "Script (Artefact)"
gen "#3d2914" "#e8a85a" glassmaker-event      "World Premiere"            "Royal Court Theatre"        "Performance (Event)"
gen "#3d2914" "#e8a85a" glassmaker-literature "Devising in Public"        "Contemporary Theatre Review" "Journal Article (Literature)"
gen "#3d2914" "#e8a85a" glassmaker-collection "Rehearsal Documentation"   "Three R&D Residencies"      "Archive (Collection)"

# Portfolio 4: Bodies in Common Ground (dance - deep purple)
gen "#2b1f3d" "#d4a5e0" common-artefact    "12 Bodies in a Square"       "Choreographic Score"         "Score (Artefact)"
gen "#2b1f3d" "#d4a5e0" common-event       "Community Performance"       "Piccadilly Gardens"          "Performance (Event)"
gen "#2b1f3d" "#d4a5e0" common-literature  "Towards a Common Ground"     "Research in Dance Education" "Journal Article (Literature)"
gen "#2b1f3d" "#d4a5e0" common-collection  "Workshop Sequences"          "2022-2025"                   "Curated Set (Collection)"

echo "Generated $(ls -1 *.png | wc -l) PNGs in $OUT"
ls -la *.png
