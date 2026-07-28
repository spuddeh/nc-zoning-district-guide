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
- **The guide is a three-across gallery.** Cards carry a full-width image on top with the text
  beneath, replacing a two-column card with a small left thumbnail. Popup 1600 -> 1760 so two
  full rows fit, plus a deliberate sliver of the third - the sliver is what says there is more
  below. Every card is the same height and reserves the same image box; a location with no image
  shows a placeholder rather than collapsing, because in a grid a short card beside two tall ones
  reads as broken.
  - **A banner was rejected at two columns and became affordable at three.** At 902 wide a 16:9
    image is 507 tall and the card reaches ~750. At 593 wide the same image is ~334. Ink cannot
    crop, so image height follows width and nothing else - the column count is the whole trick.
  - Card height is DERIVED (image + text + button band), never typed, so the three cannot drift
    apart when any one of them moves.
  - The action strip has its own **reserved band** beneath the tags. Two earlier placements were
    rejected in play: over the image, which laid a control panel across the photograph; and
    sharing the tags' line with the tags hidden on hover, which punished every card for a problem
    only long-titled ones had - and the tags appear nowhere else in the mod, so hiding them lost
    the information rather than deferring it.
  - Each button carries its **own** chamfered fill. One rectangle spanning both buttons and the
    gap between them read as a slab pasted onto the card, glaring over a bright image. The fill
    cannot simply be dropped: `cell_fg` has a translucent interior, so with none the card's text
    reads through the buttons.
  - The card background is an `inkImage` on `cell_bg`, not an `inkRectangle`. A rectangle is
    square, so the navy drew straight through the frame's chamfered corner - wrong since the card
    was first written, and only obvious once the images gave the eye a reason to look there.
  - **Every text cap is measured in-game, not derived.** Width arithmetic predicted ~39
    description characters per line; the real figure is ~49. And a cap cannot be derived from one
    measured line either - three lines held 133-141 characters across seven overflowing cards,
    because a proportional font gives a different count per line and per string. Title 74,
    description 128, tags 50.
  - Top strip is one row, 150 -> 96. The dead space under the search box was a stacking problem,
    not a strip problem: the count sat above the pager, so the strip had to clear the taller
    right-hand column and the gap appeared on the left.
  - PREV/NEXT grey out and leave the input path when there is nowhere to page to, and the page
    number is bounded on the click as well - a filter change that shrinks the result set could
    otherwise leave it pointing past the end.
- Installed-mod awareness. Each card marks whether you already have that location mod, and a
  button cycles the list between ALL / INSTALLED / MISSING / UNKNOWN. Backed by NCZoningCore
  0.3.0's detection, which needs CET.
  - **MISSING is the point, not an extra.** The guide is partly a discovery tool, and "what is
    in this district that I don't have" is the question that sends someone to Nexus. A two-way
    toggle cannot ask it.
  - **UNKNOWN IS ITS OWN VIEW**, and that corrected an earlier call. It first appeared under BOTH
    installed and missing, reasoning that an undetectable mod might be either - true, and
    unusable: AMM location mods showed up in a list headed INSTALLED that the player had no
    reason to believe. A state that cannot be determined is its own answer. Not offered as the
    RCF default, since opening on a list of undetectable mods is not a preference anyone holds.
  - **Availability is a gate: the filter button is HIDDEN without detection**, not shown doing
    nothing. Without CET every record is Unknown, so a filter would either empty the list or
    change nothing, and both are lies about the data. Re-checked on every Refresh, because the
    scan completes on session ready and the guide can be built either side of it.
  - **The filter lives at the top of the district column, not in the search row** - it filters
    that column too, since every district count changes with it. Placed above the nav scroll
    rather than as its first row, or it would scroll away. Districts left empty by a filter hide;
    ALL LOCATIONS never does, because it is the way back, and a selection the filter empties
    falls back to it.
  - The green "N RECENT" count hides while filtering: recency is a fact about the registry, not
    about installs, so beside a filtered total it would read as "3 recent of the 3 installed".
  - State shows as a second bar beside the category accent, and **hidden means "no
    information"** - only a known state draws one. It went there rather than on the meta row
    because that row is already tight (the meta string is capped at 40 chars precisely so it
    cannot reach the RECENTLY UPDATED badge), and a bar costs no layout space.
  - RCF gains an "Open Guide Showing" dropdown for which view the guide OPENS on. Cycling
    inside the guide is session-local and deliberately does not write back, or the preference
    silently degrades into "the last thing you clicked".
  - **This raises the NCZoningCore floor to 0.3.0, and `@if` cannot soften it.** `ModuleExists`
    tests for a MODULE, not a function, so with an older NCZoningCore the guarded arm still
    compiles and the new calls are UNRESOLVED_FN - which fails the whole compilation and takes
    every redscript mod on that machine down, not just this one.
- Location images on the guide cards, via RedIMGRetriever (**soft** dependency — without the
  plugin the guide has no images and is otherwise unchanged). Clicking a card's image opens the
  full-size picture in a lightbox that closes on a click anywhere. The registry already carried
  both URLs (`ThumbnailUrl()` / `PictureUrl()`) and 296 of 297 live records populate them, so no
  API or NCZoningCore change was needed.
  - The no-image placeholder is an **icon plus a caption**, and the caption is the load-bearing
    half: an atlas part that fails to resolve draws nothing at all, silently, so an icon-only
    placeholder would be indistinguishable from a blank card. `quest_file_failed` with "NO
    SURVEY IMAGE ON FILE" beneath it.
  - The icon is sized to the atlas part's **measured** aspect (66x157, from its UV rect against
    the 1640x512 texture). An `inkImage` does not preserve aspect - `SetSize` stretches the part
    to whatever it is given - so the first version drew it square and squashed it 1.45x.
  - The lightbox scrim is fully opaque and explicitly sized. Relying on `inkEAnchor.Fill` at 0.96
    opacity read as clearly translucent in-game, with the guide legible straight through it.
  - **Fit, never fill.** Images are scaled to fit inside their box preserving aspect, so an
    unusual aspect letterboxes. This is not a style choice: ink has **no clip-children facility
    at all** (no `clipChildren` anywhere in the RTTI dump), so an image larger than its box
    would draw straight over the card's text. A full-width cropped "banner" layout was designed
    and abandoned for exactly this reason — at 902 wide a 16:9 image is 507 tall, which would
    have made the card ~750 and cut the visible grid to about two rows.
  - **Two card layouts, switched in one place** (`SetCardLayout`): with a thumbnail the text
    column narrows and the description cap drops 140 -> 95; without one the card reclaims the
    full width. The meta row is resized explicitly, because it is a fixed-size canvas and does
    not inherit the stack's narrowing — leave it and the right-anchored RECENTLY UPDATED badge
    drifts off the card.
  - **The layout is chosen on "is there a URL", not "has it loaded".** Those differ, and the
    second would make every card visibly jump from wide to narrow as fetches landed. Only an
    actual fetch *failure* reflows a live card, which is rare.
  - `PrepareDocImage` is **poll-until-ready, not a callback**: it returns `""` in flight and an
    atlas ResRef once ready, and is idempotent. Drained by a self-re-arming `DelayCallback`
    chain that starts on demand and stops when the queue empties or the popup closes — not an
    `onUpdate`.
  - **`NCZDG_IdxImageBase()` is 4000 and `OnProxyClick` MUST test it before teleport.** That
    dispatch is a descending chain of `index >= base`, so a 4000 hitting the `>= 3000` arm first
    would have teleported the player across the city on a thumbnail click.
  - Two redscript constraints hit on the way: **there is no `continue` statement** (the poll
    loop uses a single-exit `drop` flag), and an `InGamePopup` is an `inkCustomController`, not
    a widget — the lightbox parents onto `GetRootCompoundWidget()`.
  - **The lightbox closes on click, not ESC.** ESC belongs to Codeware and closes the whole
    guide; there is no supported way to intercept it first, so the scrim is one large button.
    ESC while the lightbox is open therefore closes the guide outright — known, not an oversight.
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
