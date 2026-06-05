# Upstream gaps in the Hyrax compound foundation

Tracking branch: `enact-work-types` (built on `hyrax-compound-metadata`,
which locks `hyrax-webapp` to samvera/hyku PR #3093 and that in turn locks
Hyrax to `samvera/hyrax#nested-compound-metadata-foundation`).

The promise of flexible metadata is: declare a new compound in
`config/metadata_profiles/m3_profile.yaml`, run the seed task, and the
deposit form + show page render the new compound without any host-app
code change. The foundation gets us most of the way there, but a few
gaps remain. This document lists them so they can be fixed upstream and
removed from the knapsack.

## Gap 1 — Show page silently drops every compound the host app adds

**Symptom.** With HYRAX_FLEXIBLE=true and a profile that declares any
compound other than Hyrax's four sample compounds (`agents`,
`identifiers`, `compound_rights`, `relationships`), the deposit form
renders correctly and the data persists to `<name>_json_ss` on the Solr
doc, but the show page renders no rows for the new compound. No 500, no
warning visible to a user — only a dev-log line:

```
WARN -- : SolrDocument attempted to render titles, but no method exists with that name.
```

**Cause.** `Hyrax::PresentsAttributes#attribute_to_html` (in
`hyrax/app/presenters/hyrax/presents_attributes.rb`) early-returns when
the presenter does not `respond_to?(field)`. The presenter delegates
unknown reads to its `SolrDocument`. `Hyrax::SolrDocument::Metadata`
(`hyrax/app/models/concerns/hyrax/solr_document/metadata.rb`) hard-codes
`compound_attribute` declarations for exactly the four sample compounds
shipped with Hyrax:

```ruby
compound_attribute :agents
compound_attribute :identifiers
compound_attribute :compound_rights
compound_attribute :relationships
```

There is no mechanism to discover host-app-declared compounds from the
active M3 profile. A host app that adds a compound named `titles` has to
either monkey-patch `SolrDocument` to call `compound_attribute :titles`
or accept the silent drop. The Enact knapsack carried such a
monkey-patch (`app/models/solr_document_decorator.rb`) until this branch
removed it as the demonstrator. The show page is currently broken until
Hyrax addresses one of the suggested fixes below.

**Suggested upstream fix.** Two options, in order of preference:

1. **Auto-discover from the active compound schema.** In
   `Hyrax::SolrDocument::Metadata.included`, after the four sample
   declarations, iterate `Hyrax::CompoundSchema.new.compound_names` (or
   read the M3 YAML on disk via `Hyrax::Schema.m3_schema_loader`) and
   call `compound_attribute` for any name not already declared. Caveat:
   multi-tenant deployments may have per-tenant schemas — discovery
   would have to happen at request time, not at class load. A safer
   variant: declare for every compound name across all known schemas at
   boot.

2. **Make `attribute_to_html` handle compound fields without a method
   declaration.** In `PresentsAttributes#attribute_to_html`, when
   `options[:render_as].to_s == 'compound'` and the presenter does not
   respond to `field`, fall back to reading
   `solr_document["#{field}_json_ss"]` directly and pass that array of
   hashes to the renderer instead of calling `presenter.send(field)`.
   This is contained, requires no per-name pre-declaration, and matches
   how the renderer already shapes its input.

Option 2 is the minimal change; option 1 leaves room for non-rendering
code paths that also call `presenter.titles`.

## Gap 2 — Reseeding the FlexibleSchema breaks every persisted Solr doc

**Symptom.** After deleting and recreating the row in
`hyrax_flexible_schemas` (which the standard
`rake hyku:flexible_schema:initialize` task does), every previously
persisted work's show page 500s with:

```
NoMethodError (undefined method `attributes_for' for nil)
  hyrax/app/services/hyrax/m3_schema_loader.rb:43:in `definitions'
```

**Cause.** Postgres autoincrement sequences are not reset on `DELETE`,
so each reseed cycle gives the new schema a higher id (1 → 2 → 3 → …).
A persisted resource carries the id it was indexed against in its Solr
doc as `schema_version_ssi`. On show, `view_options_for(presenter)`
calls
`Hyrax::Schema.m3_schema_loader.view_definitions_for(schema: ..., version: presenter.solr_document.schema_version)`,
which routes to `M3SchemaLoader#definitions(schema_name, version, ...)`:

```ruby
schema = Hyrax::FlexibleSchema.find_by(id: version) || Hyrax::FlexibleSchema.create_default_schema
attributes = schema.attributes_for(schema_name)
```

`find_by(id: <stale-id>)` returns nil, and `create_default_schema` also
returns nil because `Hyrax::FlexibleSchema.first` exists (see
`hyrax/app/models/hyrax/flexible_schema.rb`'s
`def self.create_default_schema` — it bails when any schema is already
persisted). So `schema.attributes_for(...)` raises on nil.

**Suggested upstream fix.** When `find_by(id: version)` is nil, fall
through to `Hyrax::FlexibleSchema.current_schema_id` rather than to
`create_default_schema`. Existing records continue to render against
the current schema, and an explicit data migration can rewrite their
`schema_version_ssi` when an operator chooses to.

A simpler stopgap: when an operator reseeds, also reset the
autoincrement (`ALTER SEQUENCE hyrax_flexible_schemas_id_seq RESTART
WITH 1`) so new schemas keep id=1. But this only papers over the bug —
it breaks again the moment a second seed cycle runs.

## What to do in the knapsack today

Nothing. With these gaps open, the deposit form is the verifiable part
of the spike (the M3 profile drives form rendering end to end via the
foundation). The show page is the open question; once gap 1 lands
upstream, no host-app code is needed to display the saved compound
rows.
