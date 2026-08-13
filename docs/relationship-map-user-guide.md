# The Relationship Map: User Guide

How to record relationships between works, how to read and explore the map, and why each
part behaves the way it does. Written as end-of-project documentation for repository
managers, depositors, and future developers. Companion guides:
[people-map-user-guide.md](people-map-user-guide.md) for the research network,
[relationship-map-setup.md](relationship-map-setup.md) for tenant configuration, and
[relationship-map-demo-notes.md](relationship-map-demo-notes.md) for a demo click-path.

## 1. What the Relationship Map is, and why

Practice research outputs rarely stand alone. A finished artwork sits at the end of a
chain of drawings, models and events, is documented by photographs and film, and is
responded to in writing. Enact records these connections as structured, curated metadata
on each work, and the Relationship Map draws them as an interactive diagram: works are
circles, relationships are arrows.

**Why it works this way:** nothing on the map is inferred or automatic. Every arrow is a
connection a researcher deliberately recorded, which makes the map a piece of research
narrative rather than a systems diagram. The same recorded relationships drive both the
list on the work page and the map, so there is one source of truth and nothing to keep in
sync.

## 2. Recording relationships

Relationships are entered in the **Relationships** section of a work's edit form. Add one
row per connection; a work can carry as many as needed. Each row has the following fields:

| Field | What it does | Why |
| --- | --- | --- |
| **Item** (required) | The thing this work is related to: either another work in the repository, or any external URL such as a DOI, an archive record or a project website. | Research context does not stop at the repository's edge, so relationships can point outward as well as inward. External targets appear on the map as link nodes. |
| **Type** | How the works relate, chosen with type-ahead search from a controlled vocabulary, for example "Documents", "Continues", "Is Derived From", "Reviews". | The vocabulary is aligned with DataCite's relationType standard (see section 3), so the connections are interoperable rather than a local convention. The type also sets the arrow's colour on the map. |
| **Type: Other** | Choosing "Other" as the type reveals two free-text fields: the relationship as it reads from this work's side, and how it should read from the other work's side. The second field can be left blank when the relationship reads the same both ways. | No vocabulary anticipates every connection practice research can assert. The escape hatch keeps the researcher's own language without weakening the controlled list. |
| **Position** | An optional order number for sequenced relationships; the lowest number is shown first. | Some chains, such as the stages of a making process, have a meaningful order that alphabetical or arbitrary ordering would obscure. |
| **Note** | A free-text curatorial note explaining why the two works are connected, for example "Local press response following the unveiling of the work". | The type says how works relate; the note carries what the connection means, the research context. Notes are indexed, so they are searchable alongside the rest of the metadata. |

**Direction and inverses.** A relationship is recorded once, on one work, and reads
correctly from both ends: if the video clip "Documents" the artwork, the artwork's page
shows "Is Documented By" the video clip. Every controlled type knows its inverse, so
nobody enters the same fact twice and the two sides can never disagree.

## 3. The relationship vocabulary and DataCite

The controlled types are aligned with **DataCite's relationType vocabulary**, the
international standard used in DOI metadata. Each Enact type records its DataCite
equivalent, and the map shows that equivalent in grey alongside the type in the legend and
the detail panel.

**Why:** storing connections in standard terms means they are ready to travel. When works
carry DOIs, or in future RAiD project identifiers, these curated relationships translate
directly into standard related-identifier metadata.

Two kinds of relationship will show a type but no DataCite term: free-text "Other"
relationships, and relationships recorded under an earlier version of the vocabulary. Both
remain fully functional on the page and the map.

## 4. Reading relationships on a work's page

A work's page lists its relationships on the **Relationships** card: each entry shows the
related item, the relationship type as it reads from this work's side, and the curatorial
note. Relationships recorded on other works that point at this one appear too, reading in
their inverse form.

When the map has something to draw, the card also offers a **Relationship map** button.

**Why the button sometimes does not appear:** the button is shown only when opening the
map would show something. A relationship whose target has been deleted, is not visible to
the current viewer, or has no type recorded still appears in the list, but cannot be
drawn, so a work with only such relationships offers no button. This guarantees no one
ever opens an empty diagram.

## 5. Using the map

**Opening and closing.** The map opens in a dialog over the page you are reading, so
exploring a work's context never means losing your place. Closing the dialog returns you
exactly where you were. Every map view also has its own web address, so a particular view
can be bookmarked or shared, and in a browser without JavaScript the button simply
navigates to that page.

**The canvas.** Works are circles, with thumbnails where available. Relationships are
arrows, coloured by type. External URLs appear as link nodes and open the URL itself.

**Focused view and walking.** Opened from a work, the map centres on that work and its
direct connections. Click any neighbouring work to re-centre on it and step outward; there
is no depth limit, so the web extends as far as researchers have recorded it. "Show all"
displays every connected work at once. A work with no lines in that view simply has no
recorded relationships yet.

**Detail panels.** Clicking an **arrow** shows the relationship type, its DataCite
equivalent where one exists, and the curatorial note. Clicking a **work** shows its
thumbnail, type, date and all of its relationships, with a link through to the work's
page.

**The legend.** Lists only the relationship types present in the current graph, with their
colours and DataCite terms. Click a type to hide or show those arrows; useful for
isolating one kind of connection in a dense web.

**Layouts and search.** Three arrangements are available: Force (natural clusters), Radial
(rings around the focused work) and Tree (best for chains and hierarchies). A search box
jumps to a work by title in larger webs.

## 6. Portfolio maps: the whole project at once

On a portfolio's page, the Relationship map button opens a project-wide view: the
portfolio, its member works, and every relationship among them.

The project map also follows relationships **one step beyond the project's boundary**, in
both directions. A connection from a member work to a work in another project, or from
another project into this one, is drawn rather than silently dropped. Works brought in
this way appear only to complete the project's own connections; connections between two
outside works are not drawn.

**Why one step and no further:** the purpose of the project map is to show this project in
its context. Following outside works' own connections onward would grow every project map
into a diagram of the whole repository.

## 7. Access, limits and accessibility

- **Permissions are respected everywhere.** Every part of the map, including the project
  boundary itself, is scoped to what the current viewer is allowed to see. Two viewers
  with different permissions may legitimately see different maps of the same work.
- **Scale.** Maps are capped at 1,000 works as a safety backstop, far beyond current use.
  If anything ever has to be left out, the map says so plainly rather than truncating
  silently.
- **Accessibility.** The dialog returns keyboard focus to the button that opened it when
  closed. The "no related works are visible to you" message exists only when the map is
  truly empty, so screen readers never encounter it beside a populated graph.

## 8. Questions and answers

| Question | Answer |
| --- | --- |
| A work lists relationships, but there is no map button. Why? | None of its relationships can currently be drawn: the targets may be works the viewer cannot see, works that no longer exist, or entries with no type recorded. Fix the entries, or view the work as a user with wider permissions. |
| A related work is listed on the page but missing from the map. | Same causes as above, applied to a single entry. The list shows everything recorded; the map draws what resolves for the current viewer and carries a type. |
| An arrow shows a type but no DataCite term. | It is a free-text "Other" relationship, or one recorded under an earlier vocabulary. It remains fully functional; re-editing the work and selecting a current controlled type adds the DataCite alignment. |
| Can a particular map view be shared? | Yes. Every view has its own web address; copy it from the browser. The recipient sees the map scoped to their own permissions. |
| Why does the same relationship read differently on the two works' pages? | By design. A relationship is directional, and each side shows it from its own point of view: "Documents" on one page, "Is Documented By" on the other. Both come from a single recorded entry. |

---

Relationship data model per the PR Voices Object Handling Specification v0.2, section 3.5.
