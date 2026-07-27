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
- Settings: every setting, the keybind included, in the RCF (Redscript Configuration
  Framework) 2.0.0 F8 overlay. RCF is optional in the sense that the mod runs on its defaults
  without it, but nothing can then be rebound. **Mod Settings is not used at all.** Earlier in
  0.1.0 the keybind lived there, because RCF 1.3.0 had no keybind row kind, no `EInputKey`
  channel and a popup that handled only `n"click"`. RCF 2.0.0 (2026-07-26) added
  `Keybind`/`PadKeybind`/`AnyKeybind`/`ModifierKeybind` rows and a bundled `DVRCFInput`
  RED4ext plugin, so the split stopped being forced and the dependency was dropped. *One
  owner per setting* is unchanged — it never rested on the keybind limitation, and only which
  framework owns the keybind changed.
- Open-guide keybind via Input Loader (default apostrophe; N is photo mode), rebindable in
  the RCF panel and debounced against key-repeat. The row key, the `NCZDGKeybind.openGuideKey`
  field and `overridableUI="openGuideKey"` in `nczdg.xml` are one name in three places;
  RCF pushes the captured key through `RCFInput.SetKeyOverride`, and the listener still
  matches only the action name, never the key.
- Optional modifier held with the open key: **any** key, not one of Shift/Alt/Ctrl, via RCF's
  `localOnly` `ModifierKeybind` row. Held state is tracked in `NCZDGModifierWatch` on
  Codeware's `n"Input/Key"` `KeyInputEvent`. This replaced three dedicated Input Loader
  actions (`NCZDG_ModShift`/`ModAlt`/`ModCtrl`) plus their listener branches, which existed
  on the reasoning that `IsShiftDown()` lives on `inkInputEvent` and is unreachable from a
  gameplay `ListenerAction` callback — true of that path, but `KeyInputEvent` is not a UI
  event and exposes `GetKey()`, `GetAction()`, `IsShiftDown()`, `IsControlDown()` and
  `IsAltDown()`. Note one deliberate behaviour change: the old check also required that *no*
  modifier be held when None was chosen, so `Shift+'` would not fire a plain `'` binding.
  With an arbitrary modifier key there is no bounded set of others to test, so that no longer
  holds.
- Logging through RedLogger (`RedLog.Append`), a hard dependency, into
  `r6\logs\mods\NCZoningDistrictGuide__<date_time>.log`. `NCZDGLog` and its ~74 call sites
  now **ship**; the wrapper body was the only line that changed. `Logging.reds` is not and
  must never become a `Logs.reds` — the latter carries a `native func` declaration, and
  redscript compiles every installed mod into one unit, so two mods each shipping one is a
  duplicate declaration that breaks every redscript mod on the machine. RedLogger's signature
  ships once inside the plugin. `InkDebug.reds` is still stripped before release: it is a
  widget-tree dumper, not logging, and the distinction now matters because "strip it with the
  rest of the logging" would read as an instruction to keep it.
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
