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
| Recently-updated surfacing | Done | Green badge on cards, "N RECENT" nav count, "N RECENTLY UPDATED" map line, from the core's recency bool |

## Nearby location notice

| Feature | State | Notes |
| --- | --- | --- |
| District-enter banner injection | Planned | Nearby registry count on district change |
| Radius, throttle, max locations | Planned | Configurable |

## Settings

| Feature | State | Notes |
| --- | --- | --- |
| Mod Settings support | Planned | `@runtimeProperty`, pause menu |
| RCF support | Planned | F8 overlay, provider adapter |
| Rebindable guide keybind | Planned | Input Loader |
| Runs on defaults with no framework | Planned | Both frameworks optional |
