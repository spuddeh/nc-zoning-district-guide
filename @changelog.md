# Changelog

All notable changes to NC Zoning District Guide are documented here.
This project uses [semantic versioning](https://semver.org/).

## [0.1.0] - Unreleased

Initial development. Not yet released.

### Added

- Soft dependency bridge to NCZoningCore: compile-time `ModuleExists` guards, an
  `ApiVersion()` runtime gate, and subscriptions to the core's `NCZoning-DataReady`,
  `-DataRefreshed`, and `-DataError` events.
- Layer 2 district resolver: reads the player's current district and resolves it to the
  registry's district and subdistrict names, walking the district record's parent chain
  when the most specific level is not on the map.
- District change hook, wrapping `PlayerPuppet.OnDistrictChanged`, deduplicated so one
  boundary crossing reports once.
- Settings: toggles and sliders in the RCF (Redscript Configuration Framework) F8 overlay;
  the open-guide key and its modifier in Mod Settings. Both frameworks are optional and the
  mod runs on its defaults with neither installed.
- Open-guide keybind via Input Loader (default apostrophe), with an optional Shift/Alt/Ctrl
  modifier tracked through dedicated input actions, debounced against key-repeat.
- Recently-updated surfacing: reads NCZoningCore's server-computed `RecentlyUpdated()` (the /v1
  API's per-location recency bool - redscript has no in-game clock to derive it) and shows it in
  three places, all in green: a "RECENTLY UPDATED" badge on each mod card, an "N RECENT" count on
  every district/subdistrict nav row, and an "N RECENTLY UPDATED" line on the world-map district
  info panel. Counts are summed over the records already held; no extra API call.
- Guide QOL pass:
  - Card sort puts recently-updated locations first, A-Z within each group; decays back to
    plain A-Z on its own as the core's recency flags expire (two-key insertion sort in
    `NCZDG_SortByName`).
  - Card action strip (SET MARKER / TELEPORT) reveals on hover via `OnEnter`/`OnLeave` on the
    card; click-to-select kept as a fallback. The strip gained an opaque card-coloured backing -
    the buttons' `cell_fg` frames have translucent interiors, so long tag lines read straight
    through them.
  - RECENTLY UPDATED badge moved onto the meta row (right-aligned, fixed-height canvas shared
    with category+authors), out of the vertical flow, after long descriptions pushed the
    bottom-of-stack badge off the 240 card. Description hard-cap retuned 150 -> 140 (~2 wrapped
    lines; 150 reached 3), meta capped at 40 chars so it cannot reach the badge, tags capped at
    60 chars against right-edge overflow.
  - Card list scrolls back to the top on page turn, district change, and search edits - not on
    marker refreshes, which re-bind while the pointer sits on a card (`SetScrollPosition(0.0)`,
    the vanilla vendor-grid idiom).
  - CLEAR button beside the search input, pager-styled, visible only while a query is present;
    clears through Codeware's `SetText("")`, which fires the input's own `OnInput` path.
  - Hover feedback on every button (pager, CLEAR MARKER, CLEAR, per-card SET MARKER /
    TELEPORT): frame brightens to Archival White at full opacity, restored on leave. Pager
    frames switched from style-bound to direct tint to allow it. Hide sites (`CLEAR`, `CLEAR
    MARKER`) reset the hover state by hand - a button hidden mid-hover never receives its
    `OnLeave` and would reappear white.
