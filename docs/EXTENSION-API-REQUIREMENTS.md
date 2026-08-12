# Extension API — requirements, traced from the Location Tracker addon

> **STATUS: ABANDONED EXPERIMENT. Nothing here is implemented, and this branch is not going to
> merge.** The design was taken as far as a checked requirements list and a compiling-shaped port
> of the consumer, then shelved by agreement between Spuddeh and Akiway on 2026-08-13 — both had
> other projects with a stronger claim on the time, and the addon works today as a fork.
>
> It is kept because the expensive part is done: the requirement list is complete, the port
> proves the surface would have been sufficient, and the compile probes recording what redscript
> 0.5.31 does and does not allow are not obvious and cost a day to establish. Anyone restarting
> this starts from the findings, not from the diff.
>
> The two guide bugs this work turned up were fixed on `main` and are not part of the experiment.

Akiway's *Location Tracker - District Guide addon* (Nexus 32539) ships twelve files. Eleven are
purely additive and need nothing from the guide. The twelfth is a fork of `GuideController.reds`,
and this document is the list of everything that fork does, so the API can be measured against it
rather than guessed at.

## The bar

The API is finished when all of the following are true:

- Akiway ships **no** `GuideController.reds`.
- His eleven other files are unchanged, or changed only where this document says they must be.
- His addon compiles under `redscript-check -Mod NCZoningDistrictGuide -BothConfigs`.
- With no extension registered, the guide behaves exactly as it does today.

Every box below is either ticked by a hook, ticked as out of scope, or the bar is not met.

## Why a fork was the only option

Verified by compiling probes against the shipping toolchain (redscript 0.5.31):

| Annotation, targeting a class declared in redscript | Result |
| --- | --- |
| `@addField(NCZDGCardSlot)` | works; the field is readable and writable |
| `@addMethod(NCZDGCardSlot)` | `UNRESOLVED_REF` |
| `@addMethod(NCZDGGuidePopup)` | `UNRESOLVED_REF` |
| `@wrapMethod(NCZDGGuidePopup)` | `UNRESOLVED_REF` |

`NCZDGGuidePopup` fails twice over, because a class declared under `@if(ModuleExists(...))` cannot
be an annotation target at all.

So an addon cannot hook a single method of the guide by any means. **Every entry into extension
code has to be a call site the guide writes**, dispatching to a registered subclass. There is no
annotation-based alternative to design against.

`@addField` is the one thing that does work, and the API must not depend on it anyway: the
redscript 1.x rewrite reports *"this annotation attempts to modify a user-defined symbol, which is
not allowed"* as a hard error. An extension holds its own state in an array indexed by `slotIdx`,
parallel to the card pool, which costs nothing because the pool is fixed-size with stable indices.

---

## A. Layout

Every number the fork changed, and the space it had to make.

- [ ] **A1** Popup 2800x1760 -> 2880x1860
- [ ] **A2** Nav column 760 -> 720
- [ ] **A3** Page size 30 -> 24
- [ ] **A4** Card button width 230 -> 186, for a third button in the action strip
- [ ] **A5** Card text block 286 -> 274
- [ ] **A6** Title cap 74 -> 78, tags cap 50 -> 54, and a new meta cap of 44
- [ ] **A7** Search help panel 1560x540 -> 1680x640
- [ ] **A8** A new full-width strip, 76 high, between the top strip and the body
- [ ] **A9** A new 400-high panel under the nav column, taking that height off the nav scroll
- [ ] **A10** A new 44-high chip row inside every card
- [ ] **A11** Nav row height becomes a formula: text + two bars + gaps
- [ ] **A12** Nav row gap 0/18 -> 2/16
- [ ] **A13** The header chrome needs a nudge at the wider container, or Codeware's template drops
      the right-hand rectangle on its own clip edge
- [ ] **A14** The old install-filter button above the nav is removed, along with the three
      functions that sized it

**What the API needs:** the `NCZDG_*()` sizing functions become fields on a layout record, seeded
from today's values and handed to extensions before anything is built. Reservation calls for the
strip, the nav footer, the card band and the extra card action, each shrinking what the guide lays
out by exactly what it hands over.

**Constraint:** nav row height is summed by `ScrollNavToSelected` before the first layout pass, so
a row's height must come from the record and be the same for every row. The fork builds its bars
even with the tracker layer switched off, and leaves them empty.

## B. Proxy index namespace

- [ ] **B1** `NCZDG_IdxImageBase` renumbered 4000 -> 9000 to make room
- [ ] **B2** New bases at 4000-8000 (detail, favourite, visited, wishlist, hidden) and 20000/30000
      (facet rows, facet author-ignore)
- [ ] **B3** `NCZDG_IdxSearchHelp` moved -8 -> -6; new singletons at -7 through -23
- [ ] **B4** New branches spliced into `OnProxyClick`, both above and inside the descending chain

**What the API needs:** a reserved floor at 100000, tested first in `OnProxyClick` and
`OnProxyHover` and handed straight to the registry. Each registered extension gets a band of 10000
and asks for local numbers only, so two addons cannot collide.

**This is the cheapest item on the list and it removes one of the two reasons the fork exists.**

## C. Regions and widgets built

- [ ] **C1** Top strip extracted into its own method; search input max length 64 -> 96
- [ ] **C2** Filter strip — SHOWING / TYPE / TAG / AUTHOR / SORT / CLEAR
- [ ] **C3** Completion panel under the nav column, built only when the tracker layer is on
- [ ] **C4** Facet picker, a full-popup overlay
- [ ] **C5** Detail sheet, a full-popup overlay that replaces the lightbox
- [ ] **C6** Search help rewritten for the new grammar
- [ ] **C7** Two progress bars in every nav row
- [ ] **C8** Four state chips, a DETAILS button and a distance readout in every card

**What the API needs:** a build hook per region, each handed a canvas already sized to what was
reserved — strip, nav footer, card band, nav row band — plus an overlay hook that runs last and
parents in a defined order, because ink draws in child order and offers no z-index.

**C5 is the only place the API must let an extension suppress guide behaviour**: the thumbnail
click opens the guide's lightbox today, and the detail sheet takes it over. A claim hook returning
a handled flag covers it.

## D. Data pipeline

- [ ] **D1** `NCZDGGuideModel` replaced wholesale by `NCZLTModel`
- [ ] **D2** `Query()` takes state, category, tag, author, sort, player position and the store
- [ ] **D3** Per-area stats: installed, visited, recent, total, and a per-category breakdown
- [ ] **D4** `Facets()` — tag and author lists with counts, for the picker
- [ ] **D5** Nine state buckets: four the guide already has, five the tracker adds
- [ ] **D6** A category filter
- [ ] **D7** Tag and author facet filters
- [ ] **D8** Three sorts: name, distance, recency
- [ ] **D9** Suppression of hidden locations and ignored authors
- [ ] **D10** The search grammar replaced

**What the API needs:** the model keeps a chain of registered predicates and a list of registered
sorts, rather than being swappable. Extensions register buckets, facet sources and sorts.

**The trap:** the per-district counts must run through the same chain as the card list, or the
numbers beside each district disagree with what the cards show. This is the item most likely to
look finished and be wrong.

**D10 is settled separately** — the guide adopts the tracker's grammar (space as AND, quoted
phrases, field prefixes, trimming) and keeps `&` as a term separator so every query anyone learned
from 1.1.1 still means what it meant. Then the parser stays the guide's, and an extension
registers field prefixes and atom matchers instead of shipping a second parser. `is:installed`,
`is:missing` and `is:recent` belong to the guide, because install state and recency come from the
Core; `is:fav`, `is:wish`, `is:visited`, `is:unvisited` and `is:hidden` are the extension's.

**Whoever owns the parser owns the help panel.** An extension contributes help lines to the
guide's panel, so the panel cannot document a parser that is not running.

## E. Binding and refresh

- [ ] **E1** `BindCard` sets chip states, the distance readout and the install badge
- [ ] **E2** `UpdateNavRows` rewrites each row's count, recency, label colour and two bars, and
      replaces `ApplyNavFilter` and `FilteredAreaCount`
- [ ] **E3** `UpdateStatsPanel` for the selected district
- [ ] **E4** `UpdateFilterLabels` for the filter strip
- [ ] **E5** `Refresh` reads the player position once and parses the query once, then drives all
      of the above
- [ ] **E6** `SetCardActions` reveals chips with the hover, and leaves active ones showing

**What the API needs:** `OnCardBound(slot, loc)`, `OnNavRowBound(row, area)`, `OnRefresh()` and
`OnCardHover(slot, entered)`. The fork finds its own widgets inside a row with a named lookup, so
an extension can do the same once it has the row.

## F. Interaction

- [ ] **F1** Roughly fifteen new branches in `OnProxyClick`
- [ ] **F2** Chip hover handling in `OnProxyHover`
- [ ] **F3** Favourite / visited / wishlist / hidden toggles, from a card and from the detail sheet
- [ ] **F4** Ignore-this-author toggle
- [ ] **F5** `DoWaypoint` and `DoTeleport` split so each has a form taking a location rather than a
      slot, because the detail sheet acts on a remembered id after a refresh may have rebound the
      slot it came from
- [ ] **F6** Detail sheet open, close and update
- [ ] **F7** Picker open, close, rebuild and pick
- [ ] **F8** Category cycle, sort cycle, clear-all
- [ ] **F9** A shared after-a-filter-changed path: reset the page, scroll to top, refresh

**What the API needs:** B's dispatch covers F1 and F2. **F5 has to change in the guide** —
`DoWaypointFor(loc)` and `DoTeleportFor(loc)` become public, with the slot forms calling them.
F3, F4, F6, F7, F8 and F9 are the extension's own code once it can be reached.

## G. Needs nothing from the guide

Already additive; listed so the bar is not confused about them.

- [x] **G1** `TrackerStore` — RedFileSystem persistence
- [x] **G2** `TrackerPins` — map pins, its own `ScriptableSystem`
- [x] **G3** `TrackerMapTooltip` — annotations on the game's own mappin controllers
- [x] **G4** `TrackerRCF` — its own `DVRCF_Provider`
- [x] **G5** `TrackerBrand`, `TrackerUtil`, `TrackerFilters`
- [x] **G6** Nineteen translation slots
- [x] **G7** Auto-visit on proximity, mark-visited on teleport

## H. Guide fixes the fork found, to land regardless of the API

- [x] **H1** `NCZDG_DescCap()` was declared twice, 128 and 140, the later winning
- [x] **H2** Every `Refresh` hid and re-fetched every visible thumbnail. `BindCard` called
      `SetCardImageState` unconditionally, which clears `slot.image`, then re-queued the fetch —
      and an applied fetch has already been erased from the pending queue, so nothing deduped it.
      `Refresh` runs on every search keystroke. Fixed the fork's way: the slot remembers `locId`
      and `thumbUrl`, and skips both calls when neither changed.
- [x] **H3** ~~The install badge should test `NCZDG_InstallDetection()`~~ — **not a bug.** The
      Core's `GetInstallState` returns `Unknown` whenever the registry is absent or the scan has
      not run, so `Installed` cannot come back early. The fork's extra check is redundant.
- [ ] **H4** Search input max length 64 is short for a query with field prefixes and quoted
      phrases. Only worth changing alongside the grammar.

## Needs Akiway's agreement, not just his review

1. **The grammar.** Adopting it changes his mod's behaviour rather than its plumbing, and the
   guide taking ownership of the parser means his becomes registrations.
2. **Moving onto the reserved index band.** Mechanical, but it is his code that changes.
3. **`&` as a term separator**, which his parser currently treats as an ordinary character.
