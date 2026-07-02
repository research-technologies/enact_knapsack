# People map (research network)

An interactive network of **contributors**, the companion to the work-to-work
[relationship map](relationship-map-setup.md). Two people are linked when they
are credited on the same work; nodes are coloured by institution (their
affiliation) and sized by how many collaborators they have. It is a
reaction-stage prototype, co-designed with Nick, built from the design artifact
the team is iterating on.

- **URL:** `/people-map`
- **Controller:** `Enact::PeopleMapController` (renders `layout: false`)
- **Graph:** `Enact::PeopleGraph` + `Enact::PeopleGraph::Palette`
- **Assets:** vendored `cytoscape.js` (shared with the relationship map) plus
  `enact/people_map.{js,css}`, precompiled in
  `config/initializers/people_map_assets.rb`.

## Where the data comes from

Same single source of truth as the relationship map: the works' `contributors`
compound. `Enact::PeopleGraph`:

1. loads the works the viewer may see (ability-scoped Solr query, capped at
   `MAX_WORKS = 1000`);
2. reads each work's `contributors` entries, keeping those whose `contributor`
   member resolves to an `Enact::Contributor` (a linked, profile-backed
   contributor - free-text-only credits are skipped, as they have no stable
   identity to anchor a node or a profile link);
3. makes one **node** per contributor (label, ORCID, institution, roles,
   works count, and a `/contributors/:id` profile link);
4. makes one **edge** per pair of contributors sharing a work, weighted by how
   many works they share.

Institution colour is deterministic per affiliation (`Palette`), so a given
institution keeps its swatch across loads; contributors with no affiliation
share a neutral "unaffiliated" swatch.

## Illustrative fallback

Until a tenant carries enough real linked contributors, a live network would be
near-empty and unconvincing in a demo. So when the real graph has fewer than
`PeopleMapController::MIN_REAL_NODES` (4) nodes, the page renders an
**illustrative** dataset (`Enact::PeopleMapSample`, lifted from the design
prototype) and shows an "illustrative data" banner so no one mistakes it for
real records. Drop `MIN_REAL_NODES` to `1` once the demo tenants have real
content, and delete `PeopleMapSample` when it is no longer needed.

## Still open (for reaction)

The page ships as a working feature; these are the design defaults it takes,
still open for the team to react to:

- what "relate" means (shared work vs shared portfolio/institution/role);
- a standalone people view vs people layered onto the works map;
- whether it lives on its own page or embedded on each profile;
- whether organisations get their own nodes or stay as an institution colour.
