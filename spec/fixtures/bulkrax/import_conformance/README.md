# Bulkrax import conformance fixtures

Minimal CSVs that pin down what the importer accepts today, so changes to the parser, the field
mappings or the linked-record resolvers can be checked against a known baseline.

They come out of building bulk imports for all 15 Enact pathfinder submissions — 479 rows of real
practice-research material — and running them repeatedly against the demo tenant through August and
September 2026.

No files, no zips, no hierarchy, no dependencies between rows. Upload each as a plain CSV.
**Every row's title states what it tests and what it should do**, and `expectations.yml` carries the
same thing as data.

| Fixture | Rows | Every row should… |
|---|---:|---|
| `regression_should-fail.csv` | 13 | **fail today.** A row that completes is a bug fixed. |
| `conformance_should-pass.csv` | 18 | **pass today.** A row that errors is a regression. |
| `regression_empty-id-column.csv` | 1 | fail today. Separate file because the bug is the *column*, not a value. |
| `probe_field-isolation.csv` | 32 | 30 pass. One variable per row — useful for locating a break. |

Run the first two together after a change: one tells you what you fixed, the other what you broke.

## ⚠ Contributors are global linked records

`Bulkrax::CsvEntryDecorator#extract_contributor_attrs` matches on `display_name` + `orcid` and treats
everything else as create-only enrichment, in its own words:

> orcid is also a match key; agent_type/affiliation/name_identifier are CREATE-ONLY enrichment
> … Enrichment is CREATE-ONLY: it reaches `create` only on a miss, because find_or_create is
> `match || create`.

So **`agent_type` is only ever validated on the row that creates a name.** A bad value fails there and
then silently succeeds on every later row that reuses it — this cost us a morning of misread results
before we spotted it in the entry timestamps.

Every contributor name in these fixtures is unique and prefixed (`Regress …`, `Control …`) so each row
forces a create. **On a re-run those names already exist**, so clear the contributor records between
runs or the contributor rows will pass for the wrong reason.

## Two rows never show as failures

`B12` (a `description` containing a colon and a semicolon, which splits into three values) and `B13`
(`media_viewer`, flagged controlled in the template with no published vocabulary) complete with the
wrong stored value. Marked `silent_loss` in `expectations.yml`; they need the record inspecting.

`B12` has a deliberate control: `G17` puts the same punctuation in `context_statement`, where it must
survive intact. Same characters, two fields, only one should shred.

## Also unmapped

`label`, `note` and `transcript_ids` are silently ignored on import. `transcript_ids` means a
descriptive transcript cannot be bound to its video by import, which is an accessibility feature
rather than a nicety.

## Wiring these into a spec

`expectations.yml` is keyed by fixture then `source_identifier`:

```yaml
regression_should_fail:
  reg-B07:
    expect: fail          # fail | pass | silent_loss
    code: B07
    issue: agent_type-case-sensitive
    fix: 'Case-insensitive enum matching.'
    tests: "agent_type 'Person' — enum is case-sensitive (unintended)"
```

`expect: fail` rows are the to-do list: each should flip to completing as its `issue` is fixed. A spec
that runs an importer against a fixture and compares entry status to `expect` would turn this into a
regression suite; we have deliberately not guessed at the harness.
