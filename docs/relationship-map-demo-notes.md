# Relationship Map - Demo notes (for Rory)

Interactive view of the typed, curated relationships between works (the
"patch cables", Object Handling Spec v0.2 Sec 3.5). Six DataCite-aligned
relationship types; every edge carries a curatorial *note* (the "why"). Built
on the real `relationships` metadata on staging, not mock data.

**The story (Bruce McLean / Dalry Primary School commission):** a public
artwork, *A Machine for Learning*, sits at the centre. The drawings and models
that led to it, the media that documents it, and the writing that responds to
it all link in.

## Before you start
- Enter the basic-auth popup with `samvera` / `hyku`, then sign in as admin
  (`admin@example.com`).
- **Type the basic-auth creds into the browser popup - do NOT use a
  `https://user:pass@...` link.** Embedded credentials break the page JS.
- All the related works are published, so the graph looks the same logged in
  or out.

## Click-path (about 3-4 min)

1. **Show it in context first** - open the centre work's page and scroll to the
   **Relationships** card:
   <https://demo.enact-knapsack-staging.enacthyku.com/concern/portfolio_artefacts/362b75bc-44d2-49fe-80bf-36f4ea5dbf19?locale=en>
   Point out: each relationship has a **type** and a **curatorial note**. Then
   click the **"Relationship map"** button on that card.

2. **The wheel** (one work, many relationships) - it opens here:
   <https://demo.enact-knapsack-staging.enacthyku.com/relationship-map?focus=362b75bc-44d2-49fe-80bf-36f4ea5dbf19&locale=en>
   - Click an **edge** -> relationship type, DataCite mapping, and curatorial note.
   - Click the **centre node** -> detail panel (thumbnail, type, date, all its relationships).
   - Legend (right) maps each colour to its spec/DataCite term.

3. **Expand outward** (it is a web, not a fixed star) - click the
   **Pythagorean School steel structure** node; it re-centres and shows it
   *continues to* the finished work and *comes from* the scale model. Then click
   **Scale model for Pythagorean school** - a non-central node with **3
   relationships of 3 types**:
   <https://demo.enact-knapsack-staging.enacthyku.com/relationship-map?focus=4ded9722-4a65-403e-8efd-be95ce5386a7&locale=en>
   This traces the making-of chain:
   *Elevation drawing -> Scale model -> Steel structure -> A Machine for Learning*.

4. **"show all x"** returns to the whole connected web.

## Talking points
- Relationships are **directed and typed** (six types, DataCite-aligned, so
  they are interoperable / RAiD-ready).
- Every edge carries a **curatorial note** - the research context; "the
  connection carries the meaning."
- The map **walks**: focus shows one work plus its direct links; click any
  neighbour to step outward. **No depth limit** - it links as far as the
  relationships are authored.
- Same data drives the in-page Relationships card and the map - one source of
  truth.

## Good to know
- A node with no lines just means that work has no authored relationships yet -
  not a bug. The "show all" view only includes works that take part in a
  relationship.
- Safety cap is 1,000 works per map (a backstop; you will not approach it in
  the demo).

## Direct links
- Centre work (show page): <https://demo.enact-knapsack-staging.enacthyku.com/concern/portfolio_artefacts/362b75bc-44d2-49fe-80bf-36f4ea5dbf19?locale=en>
- Map focused on centre (the wheel): <https://demo.enact-knapsack-staging.enacthyku.com/relationship-map?focus=362b75bc-44d2-49fe-80bf-36f4ea5dbf19&locale=en>
- Map focused on Scale model (multi-type + expands further): <https://demo.enact-knapsack-staging.enacthyku.com/relationship-map?focus=4ded9722-4a65-403e-8efd-be95ce5386a7&locale=en>
- Whole connected web (unfocused): <https://demo.enact-knapsack-staging.enacthyku.com/relationship-map?locale=en>
