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
