# McLean sample-data Bulkrax import builder

One-shot converter that turns Will McLean's "Enact Pathfinders" Word template
into a Bulkrax-importable zip:

```
enact_mclean_bulkrax.zip
  manifest.csv     # 1 Portfolio + 99 PortfolioItem rows
  files/<name>     # source file for each row (96-99 depending on docx typos)
```

## Inputs

Both live in the shared drive `04 - Engineering / PRI Enact / Sample Data/`:

- `McLean_Enact Pathfinders template FINAL.docx` - the narrative template Will filled in.
- `OneDrive_2026-05-29.zip` - the source binaries Will exported from OneDrive.

If those filenames change, update the constants at the top of `build_import.py`.

## Output

`enact_mclean_bulkrax.zip` (~420 MB), written next to the script's working
directory and copied to the same shared-drive folder.

## Run

```sh
python3 tools/mclean_import/build_import.py
```

Python 3.10+. No external deps; uses stdlib `zipfile`, `csv`, `xml.etree`.

## Mapping decisions (Phase 1)

| docx column | CSV column |
|---|---|
| Title | `title` |
| File name | `file` (and used to locate the binary in the source zip) |
| Ethics approval? | not currently mapped |
| What is this? | `portfolio_item_type` + `item_subtype` (via SUBTYPE_MAP heuristic) |
| Date info | `date_created` (best-effort year extraction) + `media_type` (raw) |
| Contributor name(s) | `contributor` (free-text "Name; Name; Name") |
| Description | `description` |
| Location / Venue | `based_near` |
| Keywords | `keyword` (pipe-separated) |
| Rights, licensing, credits | `rights_statement` (free-text) |
| URL | `related_url` |
| Public? | `visibility` (Y -> open, else restricted) + `file_access_level` |
| Additional info | `additional_information` |

**Compound contributors are not yet mapped** - the import lands names as free
text in `contributor`. Wiring the full PR Voices compound (name + role +
ORCID + affiliation) needs a Bulkrax custom field mapping; deferred to
Phase 2 per CLAUDE.md.

The subtype heuristic (`SUBTYPE_MAP` in `build_import.py`) covers every value
Will used in the template; new values fall back to `Artefact / documentation`.

## Filename matching

Some docx-side filenames have typos / case differences vs the source zip:

| Docx | Zip |
|---|---|
| `MG_3657.JPG` | `IMG_3657.JPG` |
| `Planets.jpg` | `planets.jpg` |
| `alry-17-9-07-156Bxl.jpg` | `dalry-17-9-07-156Bxl.jpg` |

`find_source_files` matches case-insensitive then tries an `i`/`d` prefix as a
last-ditch fix. One file Will referenced is genuinely missing from the OneDrive
bundle - `Edinburgh_Bruce_Architecture_Will_Fiona.ppt`. That row imports with
metadata only (no file attached); the depositor can upload it later.

## Importing into Hyku

1. Sign in to the target tenant as an admin.
2. Sidebar -> Importers -> New importer.
3. Parser: **Bulkrax CSV parser**. Name: `mclean-sample`.
4. Upload `enact_mclean_bulkrax.zip`. Submit.
5. Bulkrax extracts the zip, reads `manifest.csv`, creates the Portfolio first
   and then each PortfolioItem (parents column points at the Portfolio's
   `source_identifier`). Files in `files/` get attached as FileSets.

Expect 2-5 minutes of run time, depending on derivative pipeline throughput.
