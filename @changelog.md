# Changelog

All notable changes to NC Zoning District Guide are documented here.
This project uses [semantic versioning](https://semver.org/).

## [0.1.0] - Unreleased

Initial development. Not yet released.

### Added

- Soft dependency bridge to NCZoningCore: compile-time `ModuleExists` guards, an `ApiVersion()`
  runtime gate, and subscriptions to the core's `NCZoning-DataReady`, `-DataRefreshed`,
  `-DataError` and `-InstallScanComplete` events.
- Layer 2 district resolver: reads the player's current district and resolves it to the
  registry's district and subdistrict names, walking the district record's parent chain
  when the most specific level is not on the map.
- District change hook, wrapping `PlayerPuppet.OnDistrictChanged`, deduplicated so one
  boundary crossing reports once.
- Four surfaces: the district-enter banner, the fast-travel arrival panel, the world map's
  district info panel, and the keybind-opened guide.
- The guide window builds a no-data state when the registry has no data: the red no-data
  headline plus the core-owned reason sentence, centred in the body. The nav, search, filter
  and cards are not built - a list of zero-count districts reads as "every district is empty"
  when nothing is known at all.
- `openOnCurrentArea` setting (RCF toggle "Open on Your District", default ON): the guide opens
  on the player's resolved district, or with the setting off on the ALL LOCATIONS row. Off-map
  opens on ALL either way.
- The fast-travel arrival panel is removed when a fullscreen menu opens (`UI_System.IsInMenu`
  delayed blackboard listener): its virtual-window host does not hide with the HUD, so inside
  the panel's 6s life it drew over the pause menu and inventory. The banner-path panel is
  HUD-hosted and never had the problem.
- The nearest-location line draws at random among near-ties: any location within 25 m
  (`NCZDG_NearestTieband`) of the closest is an equal candidate, so clustered mods of the same
  building rotate instead of pinning the line to one winner.
- The nav scrolls to the selected row at open (`ScrollNavToSelected`): row offsets are summed
  from the shared row-height constants over visible rows (layout has not run yet, so nothing is
  measurable) and written to the scroll controller as a normalised position, which it applies at
  first layout. Once at open only - never on a click, which would move the row under the pointer.

- **The guide, as a three-across gallery.** Cards carry a full-width image on top with the text
  beneath. Popup height 1760, sized so two full rows fit plus a sliver of the third. Every card is
  the same height and reserves the same image box; a location with no image shows a placeholder,
  because in a grid a short card beside two tall ones does not line up.
  - The column count is what makes a banner image affordable. Ink cannot crop, so image height
    follows width: at two columns (902 wide) a 16:9 image is 507 tall and the card reaches ~750; at
    three (~593 wide) the image is ~334 and the card lands near 620.
  - Card height is derived (image + text + button band), never typed, so the three cannot drift.
  - The action strip has its own reserved band beneath the tags. Not over the image, which lays a
    control panel across the photograph, and not sharing the tags' line with the tags hidden on
    hover, which costs every card its tags - and the tags appear nowhere else in the mod.
  - Each button carries its own chamfered fill. One rectangle spanning both buttons and the gap
    between them reads as a slab pasted onto the card. The fill cannot be dropped either:
    `cell_fg` has a translucent interior, so with none the card's text reads through the buttons.
  - The card background is an `inkImage` on `cell_bg`, not an `inkRectangle`. A rectangle is
    square, so the navy draws straight through the frame's chamfered corner.
  - **Every text cap is measured in-game, not derived.** Width arithmetic predicts ~39 description
    characters per line; the real figure is ~49. A cap cannot be derived from one measured line
    either - three lines held 133-141 characters across seven overflowing cards, because a
    proportional font gives a different count per line and per string. Title 74, description 128,
    tags 50.
  - Top strip is one row, 96 high. The count sits inside the pager row rather than above it, so
    both columns finish level and no dead space is left under the search box.
  - PREV/NEXT grey out and leave the input path when there is nowhere to page to, and the page
    number is bounded on the click as well, so a filter change that shrinks the result set cannot
    leave it pointing past the end.

- **The waypoint flow, verified in game.** SHOW ON MAP places the waypoint, opens the world map
  from script, centres it on the pin and fills the player-tracked slot, so the route draws with no
  player action. Two settings, `openMapOnMarker` and `autoTrackMarker`, both defaulting ON and both
  wired into RCF.
  - Opening the map calls `SpawnMenuInstanceDataEvent`, a protected native declared on
    **`gameuiBaseMenuGameController`**, not on `inkGameController`. An `@addMethod` on
    `gameuiInGameMenuGameController` may call it; the live instance is captured on that
    controller's `OnInitialize`. The event name is conditional on the `radial_hub_menu_enabled`
    fact, and the wrong one opens nothing with no error anywhere.
  - The map open fires from the popup's `OnHidden`, **not a timer**. `Close()` only queues the
    hide; the `ModalPopup` context is popped later, and opening the map before that puts it
    underneath a live modal context - drawn, accepting no input, context stack unbalanced.
  - The focus fires **synchronously from `BaseWorldMapMappinController.UpdateIcon`**, the moment
    the marker's controller exists. A delay has no correct duration here: `DelaySystem` runs on
    GAME time, which the open map dilates, so a 0.25s callback lands ~9 REAL seconds later.

- **Installed-mod awareness.** Each card marks whether you already have that location mod, and a
  button cycles the list between ALL / INSTALLED / MISSING / UNKNOWN. Backed by NCZoningCore
  0.3.0's detection, which needs CET.
  - MISSING answers "what is in this district that I do not have", which a two-way toggle cannot
    ask.
  - **UNKNOWN is its own view**, excluded from the two definite ones. Listing an undetectable mod
    under INSTALLED puts AMM location mods in a list the player has no reason to believe. It is
    not offered as the RCF default.
  - **Availability is a gate: the filter button is hidden without detection.** Without CET every
    record is Unknown, so a filter would either empty the list or change nothing, and neither
    answer is true. Re-checked on every Refresh, because the scan completes on session ready and
    the guide can be built either side of it.
  - **The filter lives at the top of the district column, not in the search row**, because it
    filters that column too - every district count changes with it. Placed above the nav scroll
    rather than as its first row, or it would scroll away. Districts left empty by a filter hide;
    ALL LOCATIONS never does, and a selection the filter empties falls back to it.
  - The green "N RECENT" count hides while filtering: recency is a fact about the registry, not
    about installs.
  - The install badge is cyan, on the thumbnail's top-left, shown only when installed and only
    under SHOWING: ALL. Nothing is drawn for missing or unknown.
  - RCF gains an "Open Guide Showing" dropdown for which view the guide opens on. Cycling inside
    the guide is session-local and does not write back.
  - **This raises the NCZoningCore floor to 0.3.0, and `@if` cannot soften it.** `ModuleExists`
    tests for a module, not a function, so with an older NCZoningCore the guarded arm still
    compiles and the new calls are UNRESOLVED_FN - which fails the whole compilation and takes
    every redscript mod on that machine down, not just this one.

- **Card images, via RedIMGRetriever (soft dependency).** Without the plugin the guide has no
  images and is otherwise unchanged. Clicking a card's image opens the full-size picture in a
  lightbox that closes on a click anywhere. The registry already carried both URLs
  (`ThumbnailUrl()` / `PictureUrl()`) and 296 of 297 live records populate them, so no API or
  NCZoningCore change was needed.
  - The no-image placeholder is an icon plus a caption. An atlas part that fails to resolve draws
    nothing at all and says nothing about why, so an icon-only placeholder would be
    indistinguishable from a blank card. `quest_file_failed` with "NO SURVEY IMAGE ON FILE".
  - The icon is sized to the atlas part's measured aspect (66x157, from its UV rect against the
    1640x512 texture). An `inkImage` does not preserve aspect - `SetSize` stretches the part to
    whatever it is given.
  - The lightbox scrim is fully opaque and explicitly sized. `inkEAnchor.Fill` at 0.96 opacity
    reads as clearly translucent in-game, with the guide legible through it.
  - **Fit, never fill.** Images are scaled to fit inside their box preserving aspect, so an unusual
    aspect letterboxes. Ink has no clip-children facility at all (no `clipChildren` anywhere in the
    RTTI dump), so an image larger than its box draws straight over the card's text.
  - **The layout is chosen on "is there a URL", not "has it loaded".** Those differ, and the second
    makes every card visibly jump from wide to narrow as fetches land. Only an actual fetch
    *failure* reflows a live card.
  - `PrepareDocImage` is **poll-until-ready, not a callback**: it returns `""` in flight and an
    atlas ResRef once ready, and is idempotent. Drained by a self-re-arming `DelayCallback` chain
    that starts on demand and stops when the queue empties or the popup closes - not an
    `onUpdate`. RedIMGRetriever's API is poll-driven by design; there is no event to subscribe to.
  - **`NCZDG_IdxImageBase()` is 4000 and `OnProxyClick` must test it before teleport.** That
    dispatch is a descending chain of `index >= base`, so a 4000 hitting the `>= 3000` arm first
    teleports the player across the city on a thumbnail click.
  - Two redscript constraints: there is no `continue` statement (the poll loop uses a single-exit
    `drop` flag), and an `InGamePopup` is an `inkCustomController`, not a widget - the lightbox
    parents onto `GetRootCompoundWidget()`.
  - **The lightbox closes on click, not ESC.** ESC belongs to Codeware and closes the whole guide,
    and there is no supported way to intercept it first, so the scrim is one large button. ESC
    while the lightbox is open closes the guide outright - a known limit.

- **Settings: every setting, the keybind included, in the RCF 2.0.0 F8 overlay.** RCF is optional
  in the sense that the mod runs on its defaults without it, but nothing can then be rebound.
  **Mod Settings is not used at all**, and mirroring a setting back to it is forbidden:
  `ModSettings.AcceptChanges()` is global and would apply every other mod's pending changes as a
  side effect.
- Open-guide keybind via Input Loader (default apostrophe), rebindable in the RCF panel and
  debounced against key-repeat. The row key, the `NCZDGKeybind.openGuideKey` field and
  `overridableUI="openGuideKey"` in `nczdg.xml` are one name in three places; RCF pushes the
  captured key through `RCFInput.SetKeyOverride`, and the listener matches only the action name,
  never the key.
- Optional modifier held with the open key: **any** key, not one of Shift/Alt/Ctrl, via RCF's
  `localOnly` `ModifierKeybind` row. Held state is tracked in `NCZDGModifierWatch` on Codeware's
  `n"Input/Key"` `KeyInputEvent`, which is not a UI event and exposes `GetKey()`, `GetAction()`,
  `IsShiftDown()`, `IsControlDown()` and `IsAltDown()`. One behaviour change comes with it: with an
  arbitrary modifier key there is no bounded set of others to test, so a plain `'` binding now
  fires under `Shift+'`.

- **Localisation.** Every player-facing string is a key resolved at draw time; 72 keys in
  `translations/English.reds`, the single source of truth for the mod's text. Uses Codeware's
  `ModLocalizationPackage` / `ModLocalizationProvider` - no TweakXL, no locale JSON and no LocKey
  registration. Adding a language is one file plus one line in `Provider.reds`.
  - **Reads through Codeware's `LocalizationSystem.GetText`, cached on a `ScriptableService`.** The
    global `GetLocalizedText` does **not** resolve these keys - it reads the base game's table and
    returns `""` for every `NCZDG.*` key, which renders the whole mod as its own key names. The
    system is resolved once at `Session/Ready` (by `NCZDGCoreBridge`, which as a `ScriptableSystem`
    has a `GameInstance` to give) and cached, because
    `GameInstance.GetScriptableServiceContainer()` takes no `GameInstance` - so `Brand.reds`,
    `GuideModel.reds` and `Status.reds` keep their free-function signatures.
  - **A missing key renders as the key.** An empty string draws an empty widget, which reads as a
    layout bug.
  - **Sentences are stored whole, with `{n}` / `{area}` / `{name}` placeholders**, rather than
    built by concatenation, which puts word order somewhere a translator cannot reach.
  - **Plurals are one key per form, never a stem plus "S".**
  - **The RCF panel passes keys, not text** - `DVRCF_HubPopup.LocalizeSchema` resolves tab,
    section, label, tooltip and caption itself. It does **not** touch the dropdown options array,
    so the three filter options are the one place that resolves its own strings before handing
    them over.

- Recently-updated surfacing: reads NCZoningCore's server-computed `RecentlyUpdated()` and shows it
  in three places, all in green - a "RECENTLY UPDATED" badge on each card's thumbnail, an
  "N RECENT" count on every district/subdistrict nav row, and an "N RECENTLY UPDATED" line on the
  world-map district info panel. Counts are summed over the records already held; no extra API call.
- Card sort puts recently-updated locations first, A-Z within each group; decays back to plain A-Z
  on its own as the core's recency flags expire (two-key insertion sort in `NCZDG_SortByName`).
- Card action strip reveals on hover via `OnEnter`/`OnLeave` on the card; click-to-select kept as a
  fallback. The strip has an opaque card-coloured backing, because the buttons' `cell_fg` frames
  have translucent interiors and long tag lines read straight through them.
- Card list scrolls back to the top on page turn, district change, and search edits - not on marker
  refreshes, which re-bind while the pointer sits on a card (`SetScrollPosition(0.0)`, the vanilla
  vendor-grid idiom).
- CLEAR button beside the search input, pager-styled, visible only while a query is present; clears
  through Codeware's `SetText("")`, which fires the input's own `OnInput` path.
- Hover feedback on every button: frame brightens to Archival White at full opacity, restored on
  leave. Pager frames switched from style-bound to direct tint to allow it. Hide sites reset the
  hover state by hand, because a button hidden mid-hover never receives its `OnLeave` and would
  reappear white.
- Logging through RedLogger (`RedLog.Append`), a hard dependency, into
  `r6\logs\mods\NCZoningDistrictGuide__<date_time>.log`. `Logging.reds` is not and must never
  become a `Logs.reds` - the latter carries a `native func` declaration, and redscript compiles
  every installed mod into one unit, so two mods each shipping one is a duplicate declaration that
  breaks every redscript mod on the machine. RedLogger's signature ships once inside the plugin.

### Changed

- **Player-facing vocabulary is "waypoint"**, the game's own word - its native prompt is TRACK
  WAYPOINT. "Mappin" stays internal. Config *field* names keep "Marker" because they are RCF
  storage keys, and renaming one silently orphans every saved value.
- **Auto-tracking defaults ON.** The player-tracked slot is not shared with quests: vanilla
  branches `CanQuestTrackMappin → TrackQuestMappin` against `CanPlayerTrackMappin → TrackMappin`,
  and the player branch clears only a custom map waypoint.
- Card badges sit on the thumbnail: RECENTLY UPDATED top-right in green, INSTALLED top-left in
  cyan. Both are chamfered `cell_bg` + `cell_fg` pairs from one `MakeCornerBadge` helper. The
  install indicator replaced a second accent bar.
- The HUD pin's emblem is 88 wide, down from 112, which read as oversized beside vanilla's 64x64
  icons.
- **Three log functions instead of one**, since `RedLog.Append` has no level parameter: `NCZDGLog`
  (`[INFO ]`), `NCZDGWarn` (`[WARN ]`), `NCZDGError` (`[ERROR]`). The level is written at the
  wrapper, so it cannot be typed wrong at a call site. The prefixes are padded to one width,
  because the log is read in-game as a column of plain labels in RCF's hub viewer.
- **Shipped logging cut from 54 call sites to 28.** The test applied to each: does this line answer
  a bug report you cannot reproduce? What went was per-event trace - the map-hover callback, the
  guide's `Refresh`, the banner's step-by-step resolve, the marker watcher's state dump,
  `guide key: FIRED`, and every build trace.
- **One `[CFG]` line at session ready, in place of the per-event "disabled in settings" lines.** It
  reports every setting and both keybinds, and is emitted *before* the core-present check, so it is
  in the log even when the mod is dormant.
- **One `[READY]` line replaces every lifecycle and injection log:**
  `[READY] core=<version> locations=<n> installDetection=on|off`. The map-section injection, the
  fast-travel listener registration, the RCF handshake, every guide open and every district
  crossing are silent. It is emitted once per session, not once per data refresh. What still logs
  per occurrence is what the **player** did - setting a marker, arriving at one, clearing it,
  teleporting.

### Fixed

- **The `[READY]` line reported `locations=0` on a session holding the whole registry.**
  `NCZDG_TotalLocations()` called `ArraySize(GetAllLocations())`, and `ArraySize` applied straight to
  a call that returns an array measures an rvalue temporary rather than the array. Bound to a local
  first. Only the log line read it, so no surface was affected - but the line is what a bug report
  quotes, and it was reporting an empty registry beside working install detection.

- **CTD on every world-map open.** The `UpdateTrackedState` wraps resolved the marker's identity by
  dereferencing the mappin. Vanilla's own `UpdateTrackedState` returns at
  `ArraySize(m_taggedWidgets) == 0` before touching it, and the hook also runs while mappins are
  being destroyed - and `GetMappin()` returns a `wref`, which is **not null** for a destroyed
  mappin, so `IsDefined()` passed it through and `GetDisplayName()` crashed the game. Identity is
  now resolved once in the icon path and cached to `nczdg_isOurs`; the tracked hooks read the Bool
  and make no native call for a pin the mod does not own, and `NCZDG_TintIcon` reads
  `IsPlayerTracked()` off the **controller** rather than through the mappin.
- **Clearing a waypoint left a pin on the HUD and minimap.** `UnregisterMappin` was already
  destroying it, but destroying a mappin that has ever been tracked strands its widget. Now
  deactivate → untrack (guarded, so it never drops a waypoint the player set) → destroy.
- **The card button ignored its own rename.** Two LocKeys drove one label: `btnSetWaypoint` at
  creation and `btnSetMarker` on every `Refresh`. Collapsed to one key.
- **The action strip pushed its buttons off the card** when they were widened - its width was
  hardcoded to `404.0`. Now derived from `NCZDG_CardBtnWidth`.
- **The thumbnail drew over the card's border.** `NCZDG_ImageWidth` subtracted only the left pad.
  It is now seated inside the frame, its top-left corner on the accent bar's right edge, sized
  from `NCZDG_AccentWidth` / `NCZDG_CardBorder`.
- **The tags cap could be overshot by a whole tag.** The length check now tests the prospective
  string rather than what has already accumulated. The tags widget has no wrap position, so an
  overshoot runs off the right edge of the card, which ink will not clip.

### Removed

- The dev instruments, whole files plus their call sites. `NCZDGLog` and `Logging.reds` ship;
  these were instruments, not logging, and they answered questions that are now answered.
  - `InkDebug.reds` - `NCZDG_DumpWidget`, a recursive widget-tree dumper that emits hundreds of
    lines per call. Restore it from git history at `84bd810~` for a debugging session rather than
    keeping it in the shipped tree.
  - `MapWakeProbe.reds` - the `NCZDGMapDiff` scriptable system, the mappin create/destroy/state
    diff across a map session, and the `[INST]` controller-instance census.
  - The `[PRESS]` probe in `MapMarker.reds` - a `TryTrackQuestOrSetWaypoint` wrap that logged the
    selected mappin's trackability. It read `nczdg_instId`, so it could not outlive `MapWakeProbe`.
  - The `NCZDG_DumpWidget` call in `MapPanelInject.reds`.
- `NCZDG_LogPosInBrackets` in `PopupInject.reds` - a parent-chain position walker that existed only
  to log, and was never called. The position it was written to find is the measured (56, 653) now
  hardcoded with its derivation in `FastTravelWatcher.reds`.
- The marker watcher's state trace, the autodrive route probe and the `m_lastWatch` dedup field.
  `Watch()` now does one thing: detect arrival and clear the marker.
- The track-it-yourself instructions from the guide footer (`NCZDG.routingHint`), which
  auto-tracking made redundant.
