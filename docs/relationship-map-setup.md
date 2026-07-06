# Relationship map - enabling it for a tenant

The relationship map (the interactive network diagram of typed, curated links
between works) is **opt-in**. It only appears when a tenant's metadata profile
declares the `relationships` compound. Without that compound there is nothing to
draw, so:

- the standalone page (`/relationship-map`) returns **404**, and
- the in-page **"Relationship map"** button never renders (it only shows inside
  the `relationships` compound card, which the profile drives).

This doc is how to turn it on.

## How the gate works

`Enact::RelationshipMapController` includes `Enact::RequiresRelationshipsCompound`
and runs `before_action :require_relationships_compound`. That check (via
`relationships_compound_configured?`) tests, on each request, whether the
tenant's metadata declares a `relationships` compound:

- **Flexible mode (`HYRAX_FLEXIBLE=true`)** - the compound lives in the active
  M3 profile's `properties`, not in the work classes, so the gate reads the
  current `Hyrax::FlexibleSchema` profile and looks for a `relationships`
  property. (Class-level `attribute_names` only carries the base Valkyrie
  attributes in flexible mode, so checking it alone gives a false negative -
  which is why an early version of this gate wrongly 404'd on flexible tenants.)
- **Classic mode** - falls back to whether any registered curation concern type
  declares a `relationships` attribute at the class level.

If neither is true, the controller renders a 404.

## Steps to enable

1. **Add the `relationships` compound to the metadata profile** for the work
   types that should support it. It is a repeatable hash (one row per link):

   ```yaml
   relationships:
     type: hash
     multiple: true
     available_on:
       properties: [Portfolio, PortfolioArtefact, PortfolioEvent, ...]  # your work types
     view: { render_as: compound }
   # members (each an entry key on a relationships row):
   relationships_item:      { type: work_or_url, name: item }   # target work id or external URL
   relationships_type:      { type: controlled,  name: type, authority: relationship_types }
   relationships_position:  { type: string,      name: position }  # optional, orders a sequence
   relationships_note:      { type: string,      name: note }      # optional curatorial "why"
   ```

   Under `HYRAX_FLEXIBLE=false`, mirror the same compound in
   `config/metadata/compound_metadata.yaml` so both modes expose it (Hyrax ships
   a sample compound schema you override).

2. **Define the relation-type vocabulary.** The six DataCite-aligned terms, their
   colours, and DataCite mappings live in `Enact::RelationshipMapController`
   (`REL_COLOR`, `REL_DATACITE`) with human labels in
   `config/locales/en.yml` under `enact.relationships.*`. Terms:
   `sequence`, `source-of`, `pair-with`, `response-to`, `documents`,
   `juxtaposed-with`. Adjust the list/labels/colours for your vocabulary.

3. **Reindex** so the derived Solr fields populate
   (`relationships_item_ssim`, `relationships_type_sim`, `relationships_json_ss`).
   The map and the reverse-lookup (inbound edges) read these.

4. **Author relationships** on works - via the deposit/edit form (the compound
   renders as repeatable rows) or bulk import. A work links to another work (by
   id) or to an external URL, with a type and an optional note.

## Verifying

- Visit a work or portfolio show page: the **Relationship map** button appears on
  the Relationships card once the compound is present and the work has links.
- Visit `/relationship-map` directly:
  - configured -> the graph (or an empty-state message if no links exist yet);
  - not configured -> `404 Relationship map is not enabled for this repository.`
- Quick data check:
  `curl -s '<host>/relationship-map?portfolio=<id>'` and confirm the
  `#relationship-map-data` JSON island lists your nodes/links.

## Notes

- Scopes: `/relationship-map?focus=<work_id>` centres on one work;
  `?portfolio=<portfolio_id>` scopes to a project (portfolio + members);
  no params shows the whole accessible, connected corpus (capped at
  `MAX_WORKS = 1000`).
- Assets (`cytoscape.js`, `enact/relationship_map.{js,css}`) are precompiled via
  `config/initializers/relationship_map_assets.rb`; run `assets:precompile` after
  deploying so the digested manifest picks them up.
