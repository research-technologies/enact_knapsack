# Phase 1 Architecture Tradeoffs

Drafted 2026-06-03 by Shana for Team Violet, ahead of the Phase 2 kickoff
and the Jenny/Rory acceptance-criteria meeting on the Tue/Wed of the same
week (per `docs/phase-2-plan.md`).

The team has been treating the Phase 1 architecture as one decision. It
is four, with different reversibility profiles. This doc separates them,
walks the pros and cons of each, recommends a direction with reasons,
and names what we are betting wrong about. It is intentionally short.
Where the existing ADRs in `product-direction/03-decision-records/`
already answer something, we follow them rather than reinvent.

## TL;DR

| # | Question | Recommendation | Why, in one line |
|---|---|---|---|
| 1 | Portfolio: Hyku Work or custom subclass of Hyku Collection? | **Custom `PortfolioResource < Hyrax::PcdmCollection` with a new `portfolio` `Hyrax::CollectionType`.** Ship Monday 2026-06-01 demo on the current `mvp` (Work-based) and pivot in Phase 2 Week 2-3 alongside the M3 spike from Q3. | PRVoices Portfolio has no `<files>` element and is an ordered container of typed items; `PcdmCollection` matches that shape exactly (`member_ids` is natively ordered; `CollectionBrandingInfo` covers the static banner; metadata richness is parity in Valkyrie 5.x; workflow stays on PortfolioItems which remain Works). LaRita's research in `portfolio-resource-shape.md` is more rigorous than my earlier Work-first reasoning, which defended file/workflow/IIIF capabilities at the Portfolio level that PRVoices does not actually require. |
| 2 | PortfolioItem: one class + enum, four typed work classes, M3 profiles, or hybrid? | **One class + `portfolio_item_type` enum** (revert the `prototype-typed-work-types` branch) | Three small scalar differences do not justify quadrupling forms, indexers, partials, and Bulkrax mappings forever. One-to-many is a reversible refactor; four-to-one is painful. |
| 3 | HYRAX_FLEXIBLE on or off for Year 1? | **Off for the Phase 2 demo; time-boxed M3 spike in Phase 2 Week 1; revisit for Phase 3** | ADR-002's recommended direction is conditional on a spike that has not been run. Phase 2 at 40% of budget on a 7-week clock is the wrong place to take the unknown. |
| 4 | Does PR Voices "Project" map to Hyku Collection? | **No.** Project is an external URI pointer field on Portfolio. | PR Voices `<project>` is 0-1 scalar holding an external handle. Mapping it to Hyku Collection invents a relationship the schema does not ask for and reopens the workflow problem. |

## Reading guide

Each question below follows the same shape: a one-sentence framing,
concrete options with what they look like in code, a pros/cons table,
the recommendation with reasons, and a "what reversal costs" line so the
reversibility is on the page next to the call. Recommendations cite the
first-principles rubric in `product-direction/01-first-principles/first-principles.md`
by number (P1-P8), the existing ADRs by id, and the real-object fixtures
in `product-direction/04-real-world-examples/fixtures/`.

## The long-term vision, and what Year 1 has to support to keep it open

Long-term, the dream is a Spotlight-like curated frontend that
showcases exhibits and records, with Hyku/Hyrax as the deposit and
management backend. Practically: Hyrax is where researchers (and
repository managers) deposit Portfolios and PortfolioItems, runs the
workflow, owns the files, mints PIDs, and indexes to Solr; a separate
curated frontend (Spotlight, a custom Blacklight gallery, or a
headless React/Next layer on top of the Hyrax GraphQL surface)
presents the result as visually-driven exhibits. This is a familiar
split: Hyku as the back of house, a presentation layer as the front of
house.

Spotlight itself is explicitly out of Year 1 scope per the signed SOW
("Enhanced features: Spotlight/Blacklight gallery, visual portfolio
tools..." under Section 5). The job for Year 1 architecture is not to
build the Spotlight layer, it is to *not foreclose* it, while shipping
a working Hyrax-first repository on the seven-week timeline.

What "not foreclose" means concretely:

- **Solr indexing has to be clean.** Whatever Year 2's frontend is, it almost certainly reads from Solr (Spotlight does, headless Blacklight does, GraphQL-on-Solr does). The Year 1 indexer choices (compound label flattening, faceted fields, type discriminators) are the durable handoff. We are already shaping these well in `app/indexers/`.
- **Portfolio and PortfolioItem identity has to survive the transition.** Whatever a Portfolio is in Hyrax (Work or Collection), the Year 2 frontend will represent it as an Exhibit (or similar). The Hyrax identity has to be stable enough that a Year 2 Spotlight Exhibit can be pinned to a Hyrax Portfolio by PID.
- **Rich rendering at the Portfolio show page is a Year 1 obligation, not a Year 2 one.** The Phase 1 demo (Monday 2026-06-01), the Phase 2 demo, and the pathfinder feedback loops all consume the Hyrax `show` view, not a Spotlight exhibit. Whatever we ship has to render a Portfolio's hero image, context statement, embedded media, and items list inside Hyrax for Year 1.
- **The Year 2 swap should not require remodeling Portfolios.** The wrong outcome is "we built Portfolio as X in Year 1, and to plug Spotlight in we have to rebuild it as Y." The Year 1 choice has to leave Year 2 a one-way Solr-and-PID consumption, not a data migration.

This framing matters most for Question 1 (Work vs Collection), where
the impulse to "model it the way Spotlight will eventually consume it"
is real. The answer turns out to be that Spotlight does not constrain
the Year 1 choice much: Spotlight Exhibits read Solr docs and curate
them, and both Hyrax Works and Hyrax Collections index to Solr in
shapes Spotlight can consume. The Year 1 choice should be driven by
Year 1 engineering cost and Year 1 demo obligations, not by what the
Year 2 frontend might prefer.

---

## Question 1: Is Portfolio a Hyku Work, or a custom subclass of Hyku Collection?

The team's proposal: a new custom Portfolio class that *inherits from*
`Hyrax::PcdmCollection` and adds PR Voices fields (RAiD identifier,
narrative context statement, portfolio_date_range, the compound rows
for contributors / funding / licenses / etc.). LaRita's writeup in
`/Users/shana/Downloads/portfolio-resource-shape.md` works the same
question more rigorously than this doc's earlier draft did, and her
conclusions are sound. This section is updated to reflect that.

A note I should keep on the record: an earlier draft of this doc
argued for Work largely on the basis of the legacy "actor stack" and
on "free parent-level files / workflow / IIIF" being needed at the
Portfolio level. Both arguments were wrong. The actor stack is not a
differentiator in Hyrax 5.x with Valkyrie (both Works and Collections
use the `Hyrax::Transactions::*` pattern). And the parent-level
file/workflow/IIIF features I was defending are not actually required
by the PRVoices schema at the Portfolio level. So those arguments come
out; the genuine tradeoffs are below.

### Options

- **(A) `Portfolio < Hyrax::Work`.** Portfolio is a Work; PortfolioItems are child works linked via Hyrax's `NestedWorks` relationship. This is the current state of the `mvp` branch.
- **(B) `PortfolioResource < Hyrax::PcdmCollection` with a new `portfolio` `Hyrax::CollectionType`** (PR Voices fields included via `Hyrax::Schema`, RAiD identifier as a scalar attribute, branding via `Hyku::CollectionBrandingInfo`, membership via standard `CollectionMemberService`). PortfolioItems are works that hold collection membership in their `member_of_collection_ids`. This is LaRita's recommendation and the team's proposal.

### Pros and cons

The table below is rewritten to focus on the real tradeoffs after
LaRita's analysis. The pre-LaRita table over-credited Work for
capabilities the PRVoices Portfolio doesn't need.

| Capability | A: `< Hyrax::Work` | B: `< Hyrax::PcdmCollection` + new CollectionType |
|---|---|---|
| **PRVoices schema fidelity** (Portfolio = ordered container of typed items, no `<files>` on Portfolio itself) | Mismatch: Work brings FileSet plumbing the schema does not ask for ("leaky abstraction" per LaRita: empty FileSets, no characterization, no derivatives) | Direct match |
| **Ordered member set** (PRVoices: "PortfolioItems is an ordered set") | NestedWorks parent/child is implementable but does not preserve member order the same way | Native: `PcdmCollection#member_ids` is `Valkyrie::Types::Array.of(...).meta(ordered: true)` |
| Workflow states (Sipity) at the Portfolio level | Free for Works | `assigns_workflow?: false` is the right CollectionType setting; workflow stays on PortfolioItems (which remain Works). The thing I argued was a Work advantage isn't one we'd actually use. |
| Per-Portfolio branding / visual identity (the prototype's `palette: "#7a5a3b"` gesture) | Would need bespoke code | `brandable?: true` + Hyku's `CollectionBrandingInfo` handles a static banner natively. Richer per-Portfolio identity (themes, custom layout) is presentation-layer work in either world. |
| Hero image / cover media at the Portfolio level (for the Brickfield-Newham-style landing page) | Free via `representative_id` + FileSet | `CollectionBrandingInfo` covers a static banner; richer "hero video at the Portfolio landing" is either (a) bubbled from a designated cover PortfolioItem, (b) covered in the Year 2 presentation layer, or (c) bespoke. PRVoices does not define this at the Portfolio level, so all three are acceptable. |
| IIIF manifest at the Portfolio level | `Hyrax::ManifestBuilderService` available | Not native; bespoke if we ever need it. PRVoices does not define multi-canvas at the Portfolio level; Year 2 Spotlight handles its own IIIF presentation anyway. |
| RAiD field on Portfolio (scalar string with `identifierType="RAiD"`) | One-line attribute via schema include | One-line attribute via schema include. **Parity.** |
| RAiD *minting* (auto-issuance via ARDC API on Portfolio create) | Year 2+ per CLAUDE.md; not contracted. Hyrax has DOI minting (Bolognese/DataCite), not RAiD. New integration code in either world. | Same: greenfield integration code. **No Work-side machinery for the Collection to be missing.** |
| Per-instance metadata (scalars, dates, compound hashes via `type: hash`) | Full | Full via `Hyrax::Schema` includes on the PcdmCollection subclass. **Parity in Valkyrie 5.x.** |
| Many-to-many membership (a PortfolioItem belongs to multiple Portfolios) | NestedWorks is single-parent; cross-Portfolio reuse requires a duplicate or a related-work pointer | Native: `allow_multiple_membership?` is a CollectionType setting. (Default for the `portfolio` CollectionType is an open question, LaRita's table flags it.) |
| Bulkrax round-tripping with PRVoices XSD | More travelled path | Less travelled but doable; PR Voices field mapping is custom work in either world |
| Solr indexing and facets (Year 2 Spotlight handoff) | Standard work indexer | Collections index; type discrimination free. **Parity.** Spotlight Exhibits map naturally to Hyrax Collections, slight conceptual win for B. |
| Conceptual readability for team and pathfinders | "Work with member works" reads as plumbing | "Custom Collection type with curated, ordered members" reads naturally and matches PRVoices' own language |
| Year 1 build cost on a 7-week clock with Sarah out | Smallest *right now*: `mvp` is already here, Monday 2026-06-01 demo ships on this | Pivot: ~Phase 2 Week 2-3 of work. Define the `portfolio` CollectionType seed, define `PortfolioResource < Hyrax::PcdmCollection`, port the metadata schema, rewrite forms (Hyrax collection forms differ from work forms), update indexers and partials, reseed demo data. Bounded but real. |
| Existing prototype state | On `mvp`; demo Monday 2026-06-01 ships on this | Not built |

### Recommendation

**Option B. `PortfolioResource < Hyrax::PcdmCollection` with a new
`portfolio` `Hyrax::CollectionType`.** This is LaRita's recommendation
in `portfolio-resource-shape.md` and the team's proposal; I updated my
position after reading her analysis.

The strongest single argument is PRVoices schema fidelity. The
PRVoices Portfolio is an ordered container of typed items with
narrative metadata and no `<files>` element of its own; that is the
exact shape of `Hyrax::PcdmCollection` (ordered `member_ids`, its own
metadata, its own ACL, its own discovery surface, no direct FileSet
membership). Modeling it as a Work means carrying FileSet plumbing
(characterization jobs, derivative generation, IIIF manifest service,
`representative_id`) that the schema does not use. LaRita calls this a
"leaky abstraction" and that is exactly what it is.

The capabilities I previously framed as Work advantages mostly
dissolve under closer reading:

- **Workflow at the Portfolio level** is a `CollectionType` setting (`assigns_workflow?`). LaRita correctly sets it `false`: workflow lives on PortfolioItems (which stay Works under both options), not on the Portfolio. The Portfolio doesn't need Sipity; pathfinder workflows we have seen (Vron's staged visibility, Bridget's mediated deposit) are per-item.
- **Parent-level files / hero image** are handled by `CollectionBrandingInfo` (Hyku) for the static banner case, by a designated cover PortfolioItem for the richer-media case, or by the Year 2 presentation layer for full Brickfield-Newham-style landing pages. PRVoices does not put files on Portfolios; we should not invent the requirement just because Work would give us the capability.
- **IIIF at the Portfolio level** is not in the PRVoices schema and is presentation-layer work in either model. Year 2 Spotlight handles its own IIIF.
- **DOI/RAiD minting machinery** is Year 1-irrelevant. RAiD is a placeholder field per `CLAUDE.md`; minting is Year 2+ and not contracted. When minting comes, the integration is greenfield because Hyrax has DOI minting (Bolognese), not RAiD, regardless of curation concern type. The Work has no Year-1 advantage here.

What option B actively gains over option A:

- **Native ordered membership** that matches PRVoices' "ordered set" language directly, with no NestedWorks shim.
- **Native many-to-many membership** via `allow_multiple_membership?`, important if pathfinders eventually want a PortfolioItem pinned to multiple Portfolios (Staircase in a personal Portfolio and in a curated BAFTSS shortlist Portfolio).
- **The `CollectionBrandingInfo` + `brandable?: true` path** for per-Portfolio visual identity, which the prototype's per-Portfolio `palette` field already gestures at.
- **Conceptual fit** with the team's mental model and with how Spotlight Exhibits in Year 2 will be organized.

### Timing

Don't pivot before the Monday 2026-06-01 demo. The Phase 1 demo ships
on the current `mvp` branch (Portfolio-as-Work). The pivot to
`PcdmCollection` + `portfolio` CollectionType happens in Phase 2 Week
2-3, deliberately overlapping with the M3 spike from Q3 (the spike and
the pivot both touch the metadata schema definitions, so doing them in
the same window avoids reshaping the same files twice). If the M3
spike clears, do the pivot with M3-driven schema; if it doesn't, do
the pivot with static `Hyrax::Schema` includes. The architecture works
either way, and that is a strength of LaRita's design: the
PcdmCollection pivot does not actually require flipping
`HYRAX_FLEXIBLE`, even though her writeup pairs them.

### Things to confirm with LaRita before the pivot starts

LaRita's CollectionType settings table flags these as "discuss with
the team":

- `allow_multiple_membership?` (her default: false). The discovery
  corpus has cross-portfolio *relationships* more than cross-portfolio
  *membership*, but if any pathfinder shows up wanting a single
  PortfolioItem pinned to multiple Portfolios, true is the answer. The
  Tue/Thu feedback loops will surface this.
- `require_membership?` (her default: true). Whether a PortfolioItem
  can exist without a parent Portfolio. Probably true, but worth one
  line of confirmation.
- `assigns_workflow?` (her default: false). Sanity check that
  Portfolio-level approval flow is not on the pathfinder ask list.

### What reversal costs

Both directions reversible inside Year 1. The data shape is the same
in both options (same fields, same compound hashes, same PRVoices
mapping); only the curation concern type differs. If we pivot to B and
later find a hard requirement that only A satisfies, it is a one-way
write from `member_of_collection_ids` to a NestedWorks parent
relationship plus a class re-stamp. If we stay on A and later need to
move to B, it is the inverse migration plus the work LaRita's
implementation plan describes. Neither is a one-line change, but
neither is a re-architecture either.

The largest reversibility cost is *not* doing the pivot at all and
shipping Year 1 on Work. That looks cheap now (we are already there),
but it commits us to fixing the leaky abstraction (empty FileSet
plumbing on Portfolios) for the lifetime of those records, and it
locks pathfinders out of multi-Portfolio item reuse without a custom
shim. Doing the pivot in Phase 2 is buying out of that long-tail cost
while the data set is still small enough to reseed.

---

## Question 2: PortfolioItem as one class with an enum, four typed classes, M3 profiles, or hybrid?

The team has been ping-ponging. The CLAUDE.md decision from 2026-05-11
was one PortfolioItem class with a required `portfolio_item_type` enum
(Artefact / Event / Literature / Collection) and per-type conditional
scalars (`place_of_publication`, `extent`, `extent_type`,
`collection_order`, `geo_locations`). The current
`prototype-typed-work-types` branch reverses that, splitting the class
into four sibling Hyrax work types each with its own YAML, model,
form, indexer, and `register_curation_concern` entry.

### Options

- **(A) One class + `portfolio_item_type` enum.** Single `PortfolioItem` Valkyrie resource. Three small per-type scalar differences handled by per-type form sections (revealed by a Stimulus controller) and per-type show partials. This is what CLAUDE.md described and what the `mvp` branch is.
- **(B) Four typed Hyrax work classes.** `PortfolioArtefact`, `PortfolioEvent`, `PortfolioLiterature`, `PortfolioItemCollection`. Four YAMLs (one per type), four models, four forms, four indexers, four show partials, four sets of registered curation concerns. This is the current `prototype-typed-work-types` branch.
- **(C) One class + M3 metadata profile per subtype.** Single `PortfolioItem` resource; the deposit form changes by subtype because a Houndstooth metadata profile is bound to the chosen subtype. No bespoke JS keeps fields in sync; the profile drives the form. Requires `HYRAX_FLEXIBLE=true` (Question 3).
- **(D) Hybrid.** Keep one class for data shape; let M3 drive the form *if and when* `HYRAX_FLEXIBLE` flips later. Equivalent to (A) now, (C) later. This is what ADR-002 sub-decision 1 implicitly recommends.

### Pros and cons

| Concern | A: One + enum | B: Four classes | C: M3 profiles | D: Hybrid (A now, C later) |
|---|---|---|---|---|
| Lines of model/form/indexer code today | Smallest | ~4x A | ~A + profile authoring | A today |
| Bulkrax mapping surface | One mapping | Four mappings | One mapping + profile-aware | One mapping today |
| Cost of adding a new subtype later | Add an enum value, maybe one conditional field | New class + YAML + form + indexer + partial + register | Add a profile | Same as A today |
| Cross-type queries ("all PortfolioItems in this portfolio") | Single Solr type | Multi-type Solr facet aggregation | Single Solr type | Single Solr type |
| Per-type form/show UX | Stimulus reveal + per-type partial fragment | Per-type form/show class | Profile drives form; per-type show partial | Stimulus today, profile later |
| Business logic in front-end JS (P7 anti-pattern) | Some (the reveal Stimulus controller) | None inside Hyrax core; per-class config carries it | None | Some today, none after flip |
| Divergence from Hyku Main | Smallest | Largest (4 extra registered concerns + 4 indexers + 4 forms) | Medium (M3 is Hyrax's own path) | Smallest today |
| Reversibility | Easy to split later (Bulkrax migration) | Hard to collapse (data spread across types) | Easy | Easy |
| Distinguishes types in admin / dashboards | Facet on `portfolio_item_type` | Free via type | Facet on `portfolio_item_type` | Facet today |
| Maps to PR Voices schema | Clean: type discriminator + subtype | Clean: each class = one PR Voices type | Clean: profile per PR Voices type | Clean today |
| Demo readiness for Monday 2026-06-01 | On `mvp` | On this branch but new and lightly tested | Not built | On `mvp` |

### Recommendation

**Option A. Revert the `prototype-typed-work-types` branch back to the
single-class-with-enum design that `mvp` is on, and proceed to D (the
hybrid) as part of Question 3's spike.**

Reasoning, by principle:

- **P7 (low divergence, no free lunch).** Four typed work classes are four registered curation concerns, four `Hyrax::Resource` subclasses, four `Hyrax::Forms::ResourceForm` descendants, four `Hyrax::ValkyrieWorkIndexer` descendants, four show partials, and four sets of view tests, paid forever on every Hyku/Hyrax upgrade. The user-visible payoff is being able to handle three small scalar differences (`place_of_publication` on Literature, `extent`/`extent_type`/`collection_order` on Collection, `geo_locations` on Artefact + Event). That ratio does not pencil out.
- **P6 (minimal stepping stone).** Option A is the smallest move that gets every Phase 1 demo behavior the team has identified; nothing in `docs/phase-1-demo-script.md` step 6 ("walk into a Portfolio, click into one typed child of each kind") requires four classes.
- **Type 1 vs Type 2.** Splitting one class into four later is a well-trodden Bulkrax-style migration: read each existing record, dispatch to the new class by `portfolio_item_type`, persist. Collapsing four classes into one later is a noisier migration and (unlike the split) breaks every URL of the form `/concern/portfolio_artefacts/:id`, every saved search, and every dashboard facet path. The cheaper-to-reverse direction is A.
- **The prototype itself is showing the tax.** On the current branch, each typed model has a custom `human_readable_type` override; each typed indexer extends `COMPOUND_INDEX_MAP` to add or omit `geo_locations`; the `register_curation_concern` list quadrupled; backward-compat aliases were added (`PortfolioResourceForm = PortfolioItem unless defined?(PortfolioResourceForm)`) to keep older code working. None of that is wrong per se, but it is the cost showing up as code.

Why not C (M3 profiles per subtype) right now: because Question 3's
spike has not been run yet. If the spike clears in Phase 2 Week 1, A
flows naturally into C with no data migration: the same Valkyrie
resource gets driven by a profile instead of by Stimulus. That is path
D, and it is what ADR-002's recommended direction maps to.

### What reversal costs

If we revert today, the diff is bounded and listed in the appendix.
Nothing on `prototype-typed-work-types` has been merged to `mvp`;
nothing has hit a tenant database that we cannot reseed. If three
months from now a pathfinder demands four-typed classes, the split is
a one-to-many Bulkrax migration with predictable scope.

---

## Question 3: HYRAX_FLEXIBLE on or off for Year 1?

The repo currently has `HYRAX_FLEXIBLE=false` in `docker-compose.yml`,
`config/initializers/hyrax.rb`, and `spec/rails_helper.rb`. The May-11
decision (CLAUDE.md) was off. ADR-002's recommended direction is on,
conditional on the spike. The spike has not been run.

### Options

- **(A) Off for all of Year 1.** Static YAML defines fields; a Stimulus controller toggles per-subtype reveal. Compound objects are `type: hash` JSONB. Current state.
- **(B) On from Phase 1.** Flip the flag; author the M3 metadata profile; rebuild forms around the profile-driven path. ADR-002's recommendation, if the spike clears.
- **(C) Off for the Phase 2 demo; time-boxed spike in Week 1 of Phase 2; flip in Phase 3 if the spike clears.** A staged version of B.

### Pros and cons

| Concern | A: Off all year | B: On from Phase 1 | C: Spike now, flip in P3 if clear |
|---|---|---|---|
| Risk to the Monday 2026-06-01 demo | None | High (Phase 1 demo is in days) | None |
| Resolves the "no business logic in front-end JS" anti-pattern (P7) | No: the reveal logic stays in Stimulus | Yes | Yes, in Phase 3 |
| Compound-object pattern (ADR-003) | Built mode-agnostically anyway | Built mode-agnostically anyway | Built mode-agnostically anyway |
| Admin-set / context UX problem (Hyku's "pick your admin set first") | Avoided | Has to be solved with friendly UI | Faced in Phase 3, with more time |
| Contributability back to Hyrax | Lower (YAML+JS isn't the platform path) | Higher | Higher (eventually) |
| Data migration on flip | Some: shifting subtype field reveal from Stimulus to profile | n/a | Small: the field shapes do not change; only the form does |
| Buys information for the call | None | None: commits before learning | Yes: the spike *is* the Type-1 information buy |
| Phase 2 budget at risk (40% concentration) | None | Significant | Bounded: the spike is the only new thing |

### Recommendation

**Option C. Keep `HYRAX_FLEXIBLE=false` for the Phase 2 demo. Run a
time-boxed (3 day) M3 spike in Phase 2 Week 1 against the *Making Odd
Kin* fixture (book + animation + podcast + website, four genuinely
heterogeneous subtypes in one portfolio). Report findings to Rory and
the team. Plan to flip to on in Phase 3 if the spike clears.**

Reasoning:

- **The Type-1 information buy is the spike, not the flip.** ADR-002 names the spike as "the one unknown that could change the recommendation." Running it now is the principled move; flipping before running it is not.
- **Phase 2 is the wrong place to take an unknown.** Per SOW, Phase 2 carries 40% of budget on a 7-week clock, with Sarah out (`docs/phase-2-plan.md` risks section). The room for unexpected work is small.
- **Phase 3 is the natural flip point.** Phase 3 is "Custom theming and layout; visual-first discovery interface" per SOW Section 4.3. We are already going to redo the form UX (dual-mode deposit, per-subtype affordances). That is the moment to swap the form-driving mechanism from Stimulus to a profile.
- **The compound-object pattern (ADR-003) is mode-agnostic regardless.** Per ADR-003 point 3 and ADR-002 sub-decision 1: the agent / hierarchical-nested-metadata work must work both ways. That work is on the Phase 2 roadmap (Track A items 3-4 in `docs/phase-2-plan.md`) and does not block on this decision.

The spike's success criteria, written down so it cannot become a feature
branch by accident:

1. An M3 profile drives the deposit form for one PortfolioItem subtype without any per-subtype JS reveal logic.
2. A `type: hash` compound (contributors) renders correctly inside that profile-driven form.
3. The friendly subtype-question UI (Rory's framing) maps to the underlying admin-set / context behind the scenes, without exposing "select admin set" to the depositor.
4. Migration sketch: what does it cost to convert the existing `mvp` data shape into a profile-driven equivalent? One paragraph, not a project plan.

Out of scope for the spike: rewriting any production code, building a
new form, or authoring profiles for all four subtypes. One profile, one
form path, three days.

### Coupling to Q1's Portfolio-as-PcdmCollection pivot

The Q1 pivot to `PortfolioResource < Hyrax::PcdmCollection` does not
strictly require flex mode (PcdmCollection accepts static
`Hyrax::Schema` includes the same way Work does), but LaRita's
writeup pairs them. Doing both in Phase 2 Week 2-3 lets us touch the
metadata schema definitions once instead of twice. If the spike
clears, the Q1 pivot lands with M3-driven schema and we move directly
toward the Phase 3 form rebuild; if the spike does not clear, the
pivot lands with static schema includes and we revisit flex in Phase
3. Either way, the Q1 destination is the same.

### What reversal costs

Tiny. Running a spike has no production cost. If we decide later to
stay off for Year 1, we delete the spike branch and we lose three
person-days. If we decide later to flip, we have data on what flipping
takes.

---

## Question 4: Does PR Voices "Project" map to Hyku Collection?

This one mostly trips the team because of vocabulary collision. PR
Voices has a term "Project" that surfaces in the schema and the report;
Hyku has a top-level type "Collection." The question is whether they
are the same thing.

### What PR Voices actually says

From the PR Voices schema wiki and the Final Report (Appendix A):
`<project>` is an attribute on the Portfolio element. It holds an
external URI pointing at a project record elsewhere (a handle, a
Crossref project DOI, a Gateway-to-Research entry). It is described as
"a project with which the portfolio item is associated," 0-1
occurrences, optional. It is a *pointer*, not a *container*.

There is no PR Voices entity called Project that has its own deposit,
workflow, contributors, file attachment, narrative, or
representation. The Portfolio is what carries narrative and items; the
Project field locates the Portfolio in a wider project context if one
exists externally.

### Options

- **(A) `project_uri` scalar field on Portfolio.** Simplest. Free text or URI validation. Matches PR Voices' 0-1 optional.
- **(B) `project` compound hash on Portfolio.** Slightly richer. Holds e.g. `{ uri, title, identifier_scheme }` so the show page can render a clickable, labeled link instead of a bare URL. Same shape as our other compounds.
- **(C) Project as Hyku Collection.** A `Hyrax::PcdmCollection` whose members are Portfolios. Portfolios then belong to one or more Project collections.

### Pros and cons

| Concern | A: scalar | B: compound | C: Hyku Collection |
|---|---|---|---|
| Faithful to PR Voices semantics | Yes | Yes | No: invents container semantics PR Voices does not have |
| Re-opens the Q1 workflow problem | No | No | Yes, in a smaller way (collections still lack the workflow we want) |
| Show-page rendering | Plain URL | Labeled link | Tenant page |
| Bulkrax round-tripping with PR Voices XSD | Direct | Direct | Requires a mapping layer that does not exist in the XSD |
| Cross-portfolio grouping (the team's actual underlying need) | Use `related_portfolio` (Track A item 2, Phase 2) or RAiD | Same | Yes, but at the cost of A's faithfulness |
| Cost today | Smallest | Small (matches existing compound pattern) | Largest |

### Recommendation

**Option B. Add `project` as a small compound hash on Portfolio,
shaped as `{ uri, title, identifier_scheme }`. Treat Hyku Collections
as available for tenant-level groupings (e.g., "Westminster School of
Architecture") but not as the home for PR Voices Projects.**

Reasoning:

- **Faithful to the source schema (P3, additive layer).** PR Voices Project is a pointer to an external thing. Modeling it as an internal container forces relationships PR Voices does not ask for and that pathfinders have not asked for.
- **Cross-portfolio grouping has a better home.** The Phase 2 roadmap already has `related_portfolio` (Track A item 2 in `docs/phase-2-plan.md`) for the "Scott points at a collaborator's Portfolio" case, and RAiD will handle the "envelope" grouping case in Year 2 per the PR Voices framework.
- **Reuses the existing pattern.** A compound hash is what we already do for `funding_references`, `identifiers`, `organisational_units`. The display logic, the indexer, and the form partial are all the same shape.

Pick scalar over compound only if the team is sure the show page will
never render the project as a labeled link (the compound is one extra
field; not picking it now is mild future churn).

### What reversal costs

Trivial. A scalar to a compound is a one-migration upgrade. A compound
to a Hyku Collection would be a redesign and is exactly what we want
to avoid by skipping option C now.

### Follow-up flagged by LaRita

LaRita's writeup flags `PRVoices Project`, `Research Group`, and
`Organisational Unit` as "separate top-level entities the schema also
defines," and suggests that if a Project itself carries narrative
metadata and ordered Portfolio members it could be another
`Hyrax::PcdmCollection` (a sibling of the `portfolio` collection
type), rather than the simple scalar-field-on-Portfolio answer above.
The PRVoices `<project>` element inside Portfolio is what the answer
above models; whether PRVoices defines a richer top-level Project
entity is worth one read of the schema wiki's Project page before the
Phase 2 acceptance-criteria meeting. If it does, this question gets
its own ADR.

---

## What changes vs CLAUDE.md / what stays

If the team accepts the recommendations above, the May-11 `CLAUDE.md`
decisions hold for the **data shape and scalar field choices** but the
**curation concern type for Portfolio changes**. Specifically:

**Stays:**

- HYRAX_FLEXIBLE=false for Year 1 *for the Phase 2 demo* (Q3 spike runs in Phase 2 Week 1; flip in Phase 3 if it clears).
- One PortfolioItem class with `portfolio_item_type` enum (not four typed work classes). LaRita's writeup independently arrives at the same recommendation.
- Compound attributes via `type: hash` on JSONB.
- Authority lookup tables in Phase 2 (`enact_funders`, `enact_org_units`, `enact_contributors`).
- All scalar field decisions (no `creator`; `date_made_public` not `date_accepted`; `metadata_rights_statement` on Portfolio only; etc.).

**Changes:**

- **Portfolio becomes a custom `Hyrax::PcdmCollection` subclass with a new `portfolio` `Hyrax::CollectionType`**, not a `Hyrax::Work`. Pivot lands in Phase 2 Week 2-3 alongside the Q3 M3 spike. CLAUDE.md currently says "Two Hyrax work types: `PortfolioResource` (parent) and `PortfolioItemResource` (child)"; that sentence becomes "One custom Hyrax collection type (`PortfolioResource < Hyrax::PcdmCollection` via the `portfolio` CollectionType) and one Hyrax work type (`PortfolioItemResource`)." (Question 1.)
- Add a `project` compound hash on Portfolio, with the follow-up question about whether a richer Project entity also needs to be a sibling PcdmCollection (Question 4).
- Revert `prototype-typed-work-types`: delete `portfolio_artefact`, `portfolio_event`, `portfolio_literature`, `portfolio_item_collection` models, YAMLs, forms, indexers, and partials (Question 2).
- Add the M3 spike to Phase 2 Week 1 in `docs/phase-2-plan.md` (Question 3).
- Add the Portfolio-to-PcdmCollection pivot to Phase 2 Week 2-3 in `docs/phase-2-plan.md` (new work; see appendix sketch).

**Documents the team should still write after this:**

- A short ratification note on each of the four questions inside `product-direction/03-decision-records/`. ADR-001 already covers Q1; ADR-002 needs amending to record "C: spike-then-flip"; ADR-004 (new) for Q2; ADR-005 (new) for Q4. Following the existing template: Context, Rubric pass, Decision, Consequences, Open questions.

## Questions for Jenny / Rory (Phase 2 acceptance-criteria meeting)

Add to the Tue/Wed Jenny meeting per `docs/phase-2-plan.md` "This week" item 2:

1. Surface the Portfolio-as-PcdmCollection pivot (LaRita's recommendation, ratified here): we are migrating Portfolio from a Hyrax Work to a custom Hyrax Collection type in Phase 2 Week 2-3 because it matches the PRVoices schema shape more directly and lets us drop FileSet plumbing PRVoices does not use. The Phase 1 demo on Monday 2026-06-01 still ships on the Work-based `mvp`.
2. Confirm that PRVoices `<project>` is the 0-1 external URI pointer on Portfolio. If CoSector is planning a richer top-level Project entity in the schema (with its own metadata, ordered Portfolio members), that becomes another PcdmCollection and needs its own ADR.
3. Confirm that per-subtype deposit forms are acceptable as a Phase 3 polish item; we will not have the M3-driven form path in the Phase 2 demo.
4. Add the M3 spike's findings (and the Q1 pivot's findings) as acceptance-criteria inputs for Phase 3 scope.

## Appendix A: Revert sketch for the `prototype-typed-work-types` branch (Q2)

If Q2 recommendation is accepted. This is what the diff looks like; it
is bounded and does not touch any data:

- Delete `app/models/portfolio_artefact.rb`, `portfolio_event.rb`, `portfolio_literature.rb`, `portfolio_item_collection.rb`.
- Delete `config/metadata/portfolio_artefact.yaml`, `portfolio_event.yaml`, `portfolio_literature.yaml`, `portfolio_item_collection.yaml`.
- Delete the parallel `app/forms/portfolio_artefact_form.rb`, `portfolio_event_form.rb`, `portfolio_literature_form.rb`, `portfolio_item_collection_form.rb`.
- Delete the parallel `app/indexers/portfolio_artefact_indexer.rb`, `portfolio_event_indexer.rb`, `portfolio_literature_indexer.rb`, `portfolio_item_collection_indexer.rb`.
- Delete the parallel controllers, views, and specs (the rename you can see in `git status` for `portfolio_collection` -> `portfolio_item_collection` shows the shape).
- In `config/initializers/hyrax.rb`, shrink `register_curation_concern` back to `:portfolio, :portfolio_item`.
- Remove the backward-compat aliases (`PortfolioResourceForm = PortfolioItem unless defined?(PortfolioResourceForm)` and similar).
- Verify `mvp` parity by running the smoke suite and seeding one Portfolio with one of each `portfolio_item_type`.

Estimated effort: half a day of careful deletion, half a day of test
runs.

## Appendix B: Portfolio-to-PcdmCollection pivot sketch (Q1)

Phase 2 Week 2-3, alongside the Q3 M3 spike. The order matters: do the
CollectionType seed first so PortfolioResource has somewhere to live;
then redefine the class; then port the metadata; then update the
ingest/show/index surfaces.

1. **Seed the `portfolio` CollectionType.** Hyrax provides `Hyrax::CollectionTypeService` for programmatic creation. Hyku has an existing seed pattern for built-in collection types; follow it. Settings per LaRita's table: `nestable?: false`, `discoverable?: true`, `brandable?: true`, `sharable?: true`, `share_applies_to_new_works?: true`, `allow_multiple_membership?` (team confirm; default false), `require_membership?` (team confirm; default true), `assigns_workflow?: false`, `assigns_visibility?: false`.
2. **Redefine `PortfolioResource`** to inherit from `Hyrax::PcdmCollection` (not `Hyrax::Work`). Include the Portfolio metadata schema. Set `collection_type_gid` default to the `portfolio` CollectionType.
3. **Port the Portfolio metadata schema.** Move the contents of `config/metadata/portfolio.yaml` into a `Hyrax::Schema(:portfolio)` include (or, if Q3 spike clears and we are flipping flex, into an M3 profile). All the existing scalar fields, compound `type: hash` fields, and indexer mappings come over with no shape changes.
4. **Rewrite the Portfolio form.** Hyrax collection forms differ from work forms; the existing `PortfolioForm` (a `Hyrax::Forms::ResourceForm`) becomes a `Hyrax::Forms::PcdmCollectionForm` subclass. The compound-row populators we already have (`build_compound_rows`, `compound_row_from`) port across; the surrounding scaffold changes.
5. **Update the Portfolio indexer.** From `Hyrax::ValkyrieWorkIndexer` to `Hyrax::Indexers::PcdmCollectionIndexer` (with our `HykuIndexing` + `EnactCompoundLabelHelpers` mixins). The compound label flattening logic ports unchanged.
6. **Update the show partial.** The Portfolio show page (`app/views/hyrax/portfolios/_portfolio.html.erb` and friends) shifts to render an ordered list of `member_works`. Most of the existing partial fragments (compound rows, hero, items list) are reusable; the wrapper changes.
7. **Update the controller.** `Hyrax::PortfoliosController < Hyrax::CollectionsController` (instead of `WorksController`).
8. **Update PortfolioItem membership.** PortfolioItem stays `Hyrax::Work`. Where the current `mvp` uses NestedWorks membership, switch to `CollectionMemberService.add_members(collection_id: portfolio.id, members: [item], user: current_user)`. The "Add to portfolio" affordance from the prototype is one form-submit-handler change.
9. **Reseed demo data.** Throw away the existing `mvp` Portfolio records and reseed via the `enact:demo:*` rake tasks against the new shape. We have no production data; this is free.
10. **Update specs.** Mostly type rename + a few `member_of_collection_ids` updates from the work-membership equivalents.
11. **Update `docs/phase-1-demo-script.md`** step references that say "Portfolio Work" to say "Portfolio Collection." Add a one-line context note at step 3 ("Architecture decisions") that the May-11 Work-based call was updated based on LaRita's PRVoices schema analysis.

Estimated effort: 3-5 days of careful work, parallelizable with the Q3
spike. The two largest pieces are the form rewrite and the demo data
reseed; everything else is mechanical.

What this pivot does *not* touch: the data shape (same fields, same
compounds, same PRVoices mapping), the PortfolioItem class (stays a
Hyrax::Work with the `portfolio_item_type` enum from Q2), the
authority lookup table work (Phase 2 Track A items 3-5), the IIIF / AV
work (Phase 2 Track B), the theme work (Phase 3).

## References

- `CLAUDE.md` (root): May-11 architecture decisions this doc gently amends
- `docs/phase-1-demo-script.md`: the Monday 2026-06-01 demo this doc must not break
- `docs/phase-2-plan.md`: where the M3 spike and the revert land in the schedule
- `config/metadata/portfolio.yaml`, `config/metadata/portfolio_item.yaml`: the as-built data shape
- Drive: `product-direction/01-first-principles/first-principles.md`: rubric (P1-P8)
- Drive: `product-direction/03-decision-records/ADR-001-portfolio-as-work.md`: governs Q1
- Drive: `product-direction/03-decision-records/ADR-002-flexible-vs-static-metadata.md`: governs Q3
- Drive: `product-direction/03-decision-records/ADR-003-agent-and-compound-object-modeling.md`: orthogonal to all four questions but informs Q2/Q3
- Drive: `product-direction/04-real-world-examples/fixtures/making-odd-kin.md`: the spike fixture
- `/Users/shana/Downloads/portfolio-resource-shape.md`: LaRita's analysis that Q1's updated recommendation follows
- PR Voices schema wiki: https://github.com/research-technologies/prvoices_schema/wiki
- PR Voices Final Report, June 2023 (Drive: `PRVOICES SCHEMA/PRVoices Final Report for Publication June 2023.pdf`)
