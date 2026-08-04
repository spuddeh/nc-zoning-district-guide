# Feature List

Feature state for NC Zoning District Guide. Legend: Done, In Progress, Planned.

## Core consumption

| Feature | State | Notes |
| --- | --- | --- |
| Soft dependency on NCZoningCore | Done | `ModuleExists` guards + `ApiVersion()` gate |
| Data lifecycle events | Done | DataReady / DataRefreshed / DataError |
| Layer 2 district resolver | Done | `PreventionSystem.GetCurrentDistrict()` + `ParentDistrict()` walk |
| District change hook | Done | Wraps `PlayerPuppet.OnDistrictChanged`, deduped |

## District guide

| Feature | State | Notes |
| --- | --- | --- |
| Standalone keybind guide | Done | Codeware InGamePopup; nav tree + pooled cards, search, paging |
| Opens on current district or ALL | Done | `openOnCurrentArea` toggle, default ON (current district); off-map always opens on ALL |
| Nav scrolls to selection at open | Done | Selected district/subdistrict centred in the column; computed pre-layout from row constants |
| World map info panel section | Done | Injected into the map's district panel (count + category breakdown) |
| Recently-updated surfacing | Done | Green badge on the card thumbnail's top-right, "N RECENT" nav count, "N RECENTLY UPDATED" map line, from the core's recency bool |
| Waypoint: show, route, clear | Done, verified in-game | SHOW ON MAP places the waypoint, **opens the world map from script**, centres on the pin and fills the player-tracked slot — the route draws with no player action. `openMapOnMarker` / `autoTrackMarker`, both default ON. Clearing deactivates → untracks → destroys, so nothing is left on map, minimap or HUD |
| Recent-first card sort | Done | Recently-updated first, then A-Z; decays with the core's flag |
| Hover-revealed card actions | Done | SHOW ON MAP / TELEPORT on card hover, opaque backing; click kept as fallback. Widths derive from `NCZDG_CardBtnWidth` so the strip cannot desync |
| Search clear button | Done | Pager-styled CLEAR beside the input, shown only with a query |
| Button hover feedback | Done | Frame brightens to Archival White on all buttons; hide sites reset it |
| Scroll reset on context change | Done | Card list returns to top on page turn, area change, search edit |
| No-data state in the guide window | Done, verified in-game | Registry unloaded → centred red headline + the core's reason sentence; nav, search, filter and cards are not built |

## Nearby location notice

| Feature | State | Notes |
| --- | --- | --- |
| District-enter banner panel | Done, verified in-game | Count + nearest location under the game's own district banner |
| Fast-travel arrival panel | Done, verified in-game | Standalone panel on the notifications layer; removed when a fullscreen menu opens |
| Nearest-location near-tie rotation | Done | Locations within 25 m of the closest draw at random per panel |

## Settings

| Feature | State | Notes |
| --- | --- | --- |
| RCF support | Done | F8 overlay via `RCFAdapter.reds`; **every** setting lives here |
| Mod Settings support | Removed | RCF 2.0.0 captures keybinds, so RCF owns every setting |
| Rebindable guide keybind | Done | RCF `Keybind` row → `DVRCFInput` plugin → `overridableUI` in `r6/input/nczdg.xml`; debounced |
| Modifier key | Done | RCF `ModifierKeybind` (`localOnly`); **any** key, not just Shift/Alt/Ctrl. Held state from Codeware `n"Input/Key"` in `ModifierWatch.reds` |
| Runs on defaults with no framework | Done | RCF is `ModuleExists` guarded; without it nothing is rebindable |
| Localisation | Done, English shipped | Codeware `ModLocalizationPackage`; 75 keys in `translations/English.reds`, cross-checked both ways. No TweakXL, no locale JSON. Read via **Codeware's `LocalizationSystem.GetText`** — the global `GetLocalizedText` does NOT resolve these keys and renders the whole mod as its own key names. Another language = one file + one line in `Provider.reds` |
| Shipped logging | Done | RedLogger hard dep; `NCZDGLog`/`Warn`/`Error` ship to `r6\logs\mods\`, level in the line text. 28 call sites, plus one `[CFG]` settings line per session. The dev instruments (`InkDebug.reds`, `MapWakeProbe.reds`) are deleted, not stripped-per-release |
| Three-across gallery cards | Done, verified in-game | Image on top, uniform height, chamfered `cell_bg`. Two full rows plus a sliver of the third |
| Installed-mod filter | Done, verified in-game | ALL / INSTALLED / MISSING / **UNKNOWN**; needs CET + NCZoningCore 0.3.0. Button **hidden** without detection. Filters the district column and its counts too |
| Install badge on cards | Done, verified in-game | Cyan INSTALLED badge on the thumbnail's top-left. Shown **only when installed and only under SHOWING: ALL**; nothing is drawn for missing or unknown |
| Card images | Done, verified in-game | RedIMGRetriever **soft** dep; full-width banner, fit-not-fill. Placeholder (icon + "NO SURVEY IMAGE ON FILE") when a record has no URL |
| Full-size lightbox | Done, verified in-game | Click a card image; closes on click anywhere. ESC closes the whole guide instead — Codeware owns ESC |
| Pager disables at the ends | Done, verified in-game | PREV/NEXT grey out and leave the input path; page index bounded on the click too |
