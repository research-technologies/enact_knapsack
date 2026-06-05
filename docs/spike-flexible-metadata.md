# Spike: flexible metadata (M3) on the typed-work-types prototype

Branch: `spike-flexible-metadata` off `prototype-typed-work-types`
Date: 2026-06-04
Owner: Shana for Team Violet, during Phase 1 discovery

## Why this branch exists

Q3 in `docs/phase-1-architecture-tradeoffs.md` recommended a time-boxed
M3 spike to answer: does flexible metadata drive the Enact deposit
forms cleanly, without per-subtype JS reveal logic, while still
expressing the PR Voices schema's compound objects? This branch is the
spike.

This branch does NOT pivot Portfolio from `Hyrax::Work` to
`Hyrax::PcdmCollection`. That pivot (LaRita's recommendation in
`/Users/shana/Downloads/portfolio-resource-shape.md`, ratified in the
updated Q1 of `docs/phase-1-architecture-tradeoffs.md`) is separate
work. On this branch, **Portfolio stays a Work** so we are testing one
variable at a time: the move from static-YAML-plus-Stimulus-reveal to
M3-profile-driven schema. The Collection-type pivot can layer on
later, on top of whatever this spike teaches us.

## What changed

- `docker-compose.yml`: `HYRAX_FLEXIBLE=true` (was `false`).
- `config/initializers/hyrax.rb`: env-var default flipped from `false` to `true`.
- `spec/rails_helper.rb`: env-var default flipped from `false` to `true`.
- `config/metadata_profiles/m3_profile.yaml`: new Enact M3 profile, mirroring the static schemas in `config/metadata/*.yaml`.

Nothing under `hyrax-webapp/` is touched (knapsack overrides only).

## How to bring it up

After a clean checkout of this branch:

```sh
docker compose up -d
docker compose exec web bundle exec rake hyku:flexible_schema:initialize
```

The rake task reads `config/metadata_profiles/m3_profile.yaml` (the
knapsack profile, ahead of the hyrax-webapp default profile because
`config/initializers/hyrax.rb` already unshifts `HykuKnapsack::Engine.root`
into `schema_loader_config_search_paths`) and writes a row into the
`hyrax_flexible_schemas` table for each tenant.

Then reseed demo data (the existing `enact:demo:*` rake tasks should
work without changes, since field names and predicates are preserved
from the static schema).

## What the profile contains

Classes (9):

- `AdminSetResource`, `CollectionResource`, `Hyrax::FileSet` (required by `Hyrax::FlexibleSchemaValidatorService::REQUIRED_CLASSES`).
- `Portfolio` (the parent Work).
- `PortfolioItem` (the legacy single-class PortfolioItem with `portfolio_item_type` discriminator, kept for back-compat with existing data).
- `PortfolioArtefact`, `PortfolioEvent`, `PortfolioLiterature`, `PortfolioCollection` (the prototype-typed-work-types siblings).

Properties (34):

- Hyrax core (5 + label on FileSet): `title`, `date_modified`, `date_uploaded`, `depositor`, `creator`, `label`.
- Portfolio-only scalars (7): `date_range_of_outputs`, `publisher`, `portfolio_identifier` (RAiD), `keyword`, `research_group`, `rights_statement` (PR Voices metadataRightsStatement), `ref_unit_of_assessment`.
- Portfolio + PortfolioItem-family shared scalars (5): `description`, `context_statement`, `date_created`, `date_made_public`, `file_access_level`.
- PortfolioItem-family shared scalars (4): `portfolio_item_type` (legacy only), `item_subtype`, `media_type`, `related_item`.
- Type-specific scalars (4): `place_of_publication` (Literature), `extent` / `extent_type` / `collection_order` (Collection), all also on legacy PortfolioItem.
- Compound hashes (8): `titles`, `dates`, `contributors`, `identifiers`, `funding_references`, `organisational_units`, `licenses`, `geo_locations` (last is Artefact + Event only). Range resolves to `hash` via `Hyrax::FlexibleSchema#lookup_type`.

CollectionResource carries only Hyrax core metadata (no PR Voices
fields). The collection model is in the profile because the validator
requires it; it is not the Portfolio. Portfolio is its own Work class.

Class-based field segmentation (`available_on.class`) replaces the
Stimulus per-subtype reveal logic. One `default_context` is declared
but not used to differentiate fields; contexts are reserved for
within-class variations later if needed.

## What the spike has to demonstrate

Per `docs/phase-1-architecture-tradeoffs.md` Q3 acceptance criteria:

1. **Profile-driven deposit form for at least one PortfolioItem subtype** with no per-subtype JS reveal. Open a `PortfolioLiterature` deposit form; `place_of_publication` should appear and `extent` / `geo_locations` should not.
2. **A `type: hash` compound (contributors) renders correctly** inside the profile-driven form. Add a contributor row on a Portfolio; submit; show page renders the row.
3. **The friendly subtype question maps to admin set / context** behind the scenes, without exposing "select admin set" to the depositor. This is the Rory framing; the spike just confirms it is achievable, not that it is polished.
4. **Migration sketch**, one paragraph: what does it cost to convert the existing `mvp` data shape into a profile-driven equivalent? Write it down at the bottom of this file when the spike resolves.

Out of scope for this spike: rebuilding any form UX, authoring all
four subtype profiles in polished form, addressing the
admin-set-picker UX, or touching the Portfolio-as-Work-vs-Collection
question.

## Footgun: work types must be in `Hyrax.config.flexible_classes`

`Hyrax::Resource.inherited` only includes the `Hyrax::Flexibility`
module (and therefore only routes attributes through the M3 profile)
when the subclass name is listed in `Hyrax.config.flexible_classes`.
The default list when flex is on is just
`[collection_model, file_set_model, admin_set_model]`. Work types are
NOT in the default. Without listing them, instantiating
`PortfolioArtefact.new` produces a vanilla Valkyrie struct with no
`depositor=`, `title=`, etc. The first place this surfaces is
`Hyrax::WorksControllerBehavior#new` at the line
`curation_concern.depositor = current_user.user_key`, raising
`NoMethodError: undefined method 'depositor=' for an instance of
PortfolioArtefact`.

Fix: declare every Enact work type in `config.flexible_classes` in
`config/initializers/hyrax.rb` (already done on this branch). The
config is read by the `inherited` callback at class-load time, so it
must be set in the same boot cycle as the class definitions. Setting
it inside an `after_initialize` block works because Rails autoloads
classes lazily in dev and eager-loads after `after_initialize` in
production.

## Footgun: `Site.instance.available_works` is a DB column, not a config

Hyku decorates `Hyrax::QuickClassificationQuery` (see
`hyrax-webapp/app/services/hyrax/quick_classification_query_decorator.rb`)
to draw the work-type list from `Site.instance.available_works`, an
ActiveRecord column that is **seeded once** at tenant creation from
`Hyrax.config.registered_curation_concern_types` (see
`hyrax-webapp/app/models/site.rb:29-34`) and then persisted forever.
Renaming a curation concern (which this branch does, completing the
`portfolio_collection` -> `portfolio_item_collection` WIP rename
inherited from the parent branch) updates the Ruby constants and the
initializer, but leaves the stale string in the DB. The symptom is
`NameError: uninitialized constant PortfolioCollection` raised from
`QuickClassificationQuery#normalized_model_names` when the homepage,
admin links, or any "create new work" UI tries to constantize the
stored list.

Fix once per tenant after bringing the branch up:

```sh
docker compose exec web bundle exec rails runner "Account.find_each { |acct| Apartment::Tenant.switch(acct.tenant) { Site.instance.update!(available_works: Hyrax.config.registered_curation_concern_types) } }"
```

The flexible schema profile is also serialized into a DB column
(`hyrax_flexible_schemas.profile`). If `hyku:flexible_schema:initialize`
was run on the parent branch before the rename, the stored profile
holds the old class names too. Reseed:

```sh
docker compose exec web bundle exec rails runner "Account.find_each { |acct| Apartment::Tenant.switch(acct.tenant) { Hyrax::FlexibleSchema.destroy_all } }"
docker compose exec web bundle exec rake hyku:flexible_schema:initialize
```

## Knobs to flip if you need to compare against the static path

To run with the static SimpleSchemaLoader schemas (the
`prototype-typed-work-types` shape), set in your environment:

```sh
export HYRAX_FLEXIBLE=false
```

The initializer respects an explicit env override before falling back
to the branch default. This is useful for side-by-side comparison
during the spike.

## Findings (fill in as the spike runs)

- [x] Profile loads without validation errors via `hyku:flexible_schema:initialize`
- [x] PortfolioArtefact deposit form shows `geo_locations`; Portfolio / Literature /
      ItemCollection forms omit it (class-based segmentation from `available_on.class`)
- [x] All 7 (Portfolio) / 8 (Artefact + Event) PR Voices compounds render in deposit
      forms with the M3-declared `groups:` visible as h4 cluster sub-headings
- [ ] Contributors compound row persists and reads back (need a deposit to confirm)
- [ ] Show page renders compound cards (need a saved Portfolio to verify
      `view_options_for(presenter)` + `render_compound_cards`)
- [ ] Solr indexes per-subfield Solr fields match the `indexing:` directives in M3
- [ ] Migration paragraph for converting existing records: ___

## What changed when we wired in samvera/hyku PR #3093 (2026-06-05)

After LaRita's PR landed on the hyku branch `hyrax-compound-metadata` (Hyrax gem
on the `nested-compound-metadata-foundation` branch), the knapsack-side
compound rendering scaffolding became obsolete. End-to-end rendering of
compounds now comes from `config/metadata_profiles/m3_profile.yaml`:

- the M3 entry declares `type: hash`, `subfields:`, `groups:`, `view: { render_as: compound }`
- the Hyrax compound foundation supplies `compound_terms`, `render_compound_field(f, term)`,
  `render_compound_cards(presenter)`, and `compound_card_field?(presenter, field)`
- Hyrax's own `_form_metadata.html.erb`, `_attribute_rows.html.erb`, and `show.html.erb` consume those helpers

Knapsack scaffolding removed in the bump:

- `app/views/hyrax/compounds/_compound_section.html.erb`, `_compound_row.html.erb`, `_compound_script.html.erb`
- per-work `_form_metadata.html.erb` overrides for portfolios / portfolio_items / portfolio_artefacts / portfolio_events / portfolio_literatures / portfolio_item_collections
- per-work `_attribute_rows.html.erb` overrides for portfolios / portfolio_items
- `app/indexers/enact_compound_label_helpers.rb` and the `COMPOUND_INDEX_MAP` / `to_solr` overrides in each indexer
- `COMPOUND_ATTRIBUTES`, `COMPOUND_FIELD_GROUPS`, populators, `build_permitted_params`, and `deserialize!` in each `*_form.rb`
- the `enact.compound_fields.*` i18n branch (no longer referenced)
- `spec/forms/portfolio_form_spec.rb` (tested behavior the form classes no longer own)

Still in place because they are not view code: `EnactCompoundNormalization`
(Postgres JSONB round-trip defense - keep until the foundation's persistence
path is confirmed unaffected).
