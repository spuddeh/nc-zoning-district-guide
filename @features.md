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
| World map info panel section | Done | Injected into the map's district panel (count + category breakdown) |
| Recently-updated surfacing | Done | Green badge on cards (meta row), "N RECENT" nav count, "N RECENTLY UPDATED" map line, from the core's recency bool |
| Recent-first card sort | Done | Recently-updated first, then A-Z; decays with the core's flag |
| Hover-revealed card actions | Done | SET MARKER / TELEPORT on card hover, opaque backing; click kept as fallback |
| Search clear button | Done | Pager-styled CLEAR beside the input, shown only with a query |
| Button hover feedback | Done | Frame brightens to Archival White on all buttons; hide sites reset it |
| Scroll reset on context change | Done | Card list returns to top on page turn, area change, search edit |

## Nearby location notice

| Feature | State | Notes |
| --- | --- | --- |
| District-enter banner injection | Planned | Nearby registry count on district change |
| Radius, throttle, max locations | Planned | Configurable |

## Settings

| Feature | State | Notes |
| --- | --- | --- |
| RCF support | Done | F8 overlay via `RCFAdapter.reds`; **every** setting lives here |
| Mod Settings support | Removed | Held only the keybind, because RCF 1.3.0 could not capture one. RCF 2.0.0 can, so it moved and the dependency was dropped |
| Rebindable guide keybind | Done | RCF `Keybind` row → `DVRCFInput` plugin → `overridableUI` in `r6/input/nczdg.xml`; debounced |
| Modifier key | Done | RCF `ModifierKeybind` (`localOnly`); **any** key, not just Shift/Alt/Ctrl. Held state from Codeware `n"Input/Key"` in `ModifierWatch.reds` |
| Runs on defaults with no framework | Done | RCF is `ModuleExists` guarded; without it nothing is rebindable |
| Shipped logging | Done | RedLogger hard dep; `NCZDGLog` ships to `r6\logs\mods\`. `InkDebug.reds` still stripped at release |
