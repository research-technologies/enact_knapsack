# The Research Network (People Map): User Guide

How the collaboration network is built from contributor metadata, how to read and explore
it, and why each part behaves the way it does. Written as end-of-project documentation for
repository managers, depositors, and future developers. Companion guides:
[relationship-map-user-guide.md](relationship-map-user-guide.md) for the work-to-work
relationship map, and [people-map.md](people-map.md) for developer internals (classes,
assets, open design questions).

## 1. What the Research Network is, and why

The Research Network is the people companion to the Relationship Map: where that map
connects works to works, this one connects people to people. Contributors are circles,
coloured by institution, and two people are connected when they are credited on the same
work.

**Why it works this way:** the network is derived entirely from the contributor metadata
already recorded on works. Nobody builds or maintains it by hand, so it can never drift
out of date: deposit works with proper credits and the collaboration map draws itself.

*Status note: the Research Network shipped as a working prototype, co-designed during the
project. It is fully functional as described here, and reactions to it will shape its
further development.*

## 2. Where the data comes from: crediting contributors on works

Every work in Enact carries a **Contributors** section, one row per person or
organisation. Each row records:

| Field | What it does | Why |
| --- | --- | --- |
| **Name** | The contributor's name, as a person or an organisation. | Practice research credits organisations (schools, studios, funders) as readily as individuals, and the network shows both. |
| **Roles** | One or more roles chosen with type-ahead search, for example "Conceptualization", "Data Curation", or a free-text role such as "Lead Artist". A contributor can hold several roles on one work. | The role list merges established vocabularies, including CRediT, into one seamless list. Researchers never need to know which vocabulary a term came from, and the network can say not just that two people collaborated but how. |
| **ORCID** | The contributor's ORCID identifier, where they have one. | ORCID is the authoritative identity for researchers. It disambiguates people who share a name and lets the network link out to the real record. |
| **Affiliation** | The contributor's institution. | Affiliations colour the network's nodes, making collaboration within and between institutions visible at a glance. |

The same rows also power the **contributor profiles** reached from the contributor
directory: each profile lists the person's works, roles and identifiers. Profiles can be
claimed by their owners and approved by an administrator, which links a repository account
to the published identity.

**Only profile-backed credits appear on the network.** A credit entered as free text,
without being linked to a contributor profile, is skipped: it has no stable identity to
anchor a node or a profile link. **Why:** a network node has to mean one real person or
organisation; drawing nodes from unlinked strings would scatter one person across
duplicate dots and connect no one reliably.

## 3. Opening the network

There are two ways in:

- **From a contributor profile:** the **Research network** button opens the map centred on
  that person, in a dialog over the page, exactly as the Relationship Map does. Closing it
  returns you to the profile.
- **The whole network:** the **View as network** link on the contributor directory opens
  the unfocused view, every connected contributor in the tenant at once.

## 4. Reading the map

**People and connections.** Each circle is a contributor, coloured by institution; the
legend maps colours to institutions. Circles grow with the number of collaborators, so the
network's connectors stand out. Each line means the two people are credited together on at
least one work.

**Line thickness and the number on a line.** A connection's strength is the number of
works the two people share. The line grows thicker with that count, and when a person is
focused or clicked, each highlighted line shows the count as a small number. **Why:** a
single shared work and a decade of collaboration should not look the same; the number
makes the strength of a working relationship legible at a glance, and clicking the line
lists exactly those works.

**The focused view has two tiers.** When the map is centred on a person:

- **Solid lines** connect their direct collaborators, the people credited alongside them
  on works.
- **Lighter, dashed lines** show collaborators of those collaborators, the adjacent
  communities one step beyond.

**Why two tiers:** a researcher's immediate world and the world one step beyond it answer
different questions. The solid tier shows who they work with; the dashed tier can surface
nearby communities and potential connections they did not know they had. The line key on
the map explains the encoding in place.

**Clicking a connection** opens the detail panel: the works the two people share, and each
person's roles on each work. For example, on a shared residency one person may be credited
with Conceptualization and Lead Artist and the other with Formal Analysis. This is the
"who did what" record, read directly from the works' credits.

**Clicking a person** shows their details and works, with their ORCID linking out to the
authoritative record and a link through to their full profile.

**Walking.** As with the Relationship Map, click any person to re-centre the network on
them and explore outward.

## 5. How it behaves

- **Permissions are respected.** The network is drawn only from works the current viewer
  is allowed to see, so viewers with different permissions may see different networks.
- **New tenants never see an empty canvas.** When a tenant does not yet hold enough linked
  contributors for a legible network, the page shows an illustrative example dataset
  instead, clearly marked with a banner. As soon as real deposits accumulate past that
  threshold, the real network takes over automatically. **Why:** an empty diagram teaches
  nothing; the example lets every tenant understand the feature from day one, and the
  banner ensures no one mistakes it for real data.
- **It updates itself.** Because the network is derived from work metadata, editing a
  work's contributor rows is all it takes to change the map. There is no separate network
  to administer.

## 6. Questions and answers

| Question | Answer |
| --- | --- |
| What is the number on a line? | How many works the two people share. It appears on the highlighted lines when a person is focused or clicked, and the line's thickness grows with the same count. Click the line to see the works themselves, with each person's roles on each one. |
| Someone is missing from the network. | Either they are not credited on any work the current viewer can see, or their credits are free text not yet linked to a contributor profile. Check that the works crediting them are deposited and visible, and that the credit is linked to their profile. |
| The same person appears twice. | They are credited under name entries that are not yet linked to a single profile, for example with and without an ORCID, or under a name variant. Bringing the entries under one profile brings the nodes together. |
| The page shows a banner about example data. | The tenant does not yet hold enough linked contributors for a legible real network, so the clearly marked illustrative dataset is shown instead. It disappears automatically as real deposits accumulate. |
| Two people collaborated, but no line connects them. | A line requires being credited on the same work. If they collaborated on something not deposited, or one of them is missing from the work's Contributors section, the network cannot know. Edit the work's credits and the line appears. |
| Why are some lines dashed? | Only in the focused view: solid lines are the focused person's direct collaborations; dashed lines are collaborations among the wider community one step beyond them. In the unfocused view all connections are equal. |

---

A companion to the Relationship Map, drawn from the contributors metadata on works.
