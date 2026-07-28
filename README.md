# NC Zoning District Guide

A Cyberpunk 2077 mod that tells you which location mods are around you, using the game's
own UI. It reads the [NC Zoning](https://nczoning.net) registry through
[NCZoningCore](https://github.com/spuddeh/nc-zoning-core) and surfaces it where you are
already looking: the world map, the district banner, and a guide you open with a keybind.

It is also the reference consumer for NCZoningCore: a worked example of the soft dependency
pattern, the district resolver, and the public API.

## Features

- **District guide.** Press a key to open a guide listing the registry's location mods in
  the district you are standing in, with author, category, and description.
- **World map panel.** The map's district info panel gains an NC Zoning section showing the
  location mods in the district you are inspecting.
- **Nearby notice.** When you enter a district, the game's own district banner tells you how
  many registry locations are nearby.

Every feature can be turned off on its own.

## Requirements

- RED4ext, redscript, Codeware
- [NCZoningCore](https://github.com/spuddeh/nc-zoning-core)
- [RedLogger](https://www.nexusmods.com/cyberpunk2077/mods/31920) (the mod's log file)
- Input Loader (for the guide keybind)

Strongly recommended:

- [Redscript Configuration Framework](https://www.nexusmods.com/cyberpunk2077/mods/30726)
  (RCF) 2.0.0 or newer, by DigitalVixen — every setting lives in its in-world overlay,
  including the guide keybind and its modifier

Optional:

- [RedIMGRetriever](https://www.nexusmods.com/cyberpunk2077/mods/31941) by DigitalVixen — shows
  each location's screenshot on its card, and the full-size image when you click it. Without it
  the guide simply has no images; nothing else changes.

Without RCF the mod still runs, but on its defaults only: the guide opens with the
apostrophe key, there is no modifier, and **nothing can be rebound.** RCF also pulls in
RED4ext for its bundled keybind plugin.

**Mod Settings is no longer used.** Up to 0.1.0 the keybind lived there, because RCF could
not capture one. RCF 2.0.0 can, so the keybind moved and the dependency was dropped — every
setting is now in one menu. If you installed Mod Settings only for this mod, you no longer
need it.

## Install

Loose files: unpack `r6\` into your Cyberpunk 2077 game directory.

Do not bundle NCZoningCore, RCF, or any other redscript dependency into this mod. Redscript
compiles everything together, so a second copy of a class is a duplicate-class error that
breaks every redscript mod. Install each one once, as its own mod.

## The NC Zoning project

- Explore the map: <https://nczoning.net>
- Join the community: [Locations Hub Discord](https://discord.gg/sc4yEx2fNf)

## Credits

- [Kaoziun](https://www.nexusmods.com/profile/Kaoziun) for the original NC Zoning vision and
  community leadership.
- [Akiway](https://www.nexusmods.com/profile/Akiway) for improvements to the NC Zoning map
  UI and UX.
- [psiberx](https://www.nexusmods.com/profile/psiberx/mods) for Codeware.
- DigitalVixen for the Redscript Configuration Framework and RedLogger.
- The location-mod authors the registry maps, and the Locations Hub community.

## License

Licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). You may use, modify, and
share this mod and its source for any noncommercial purpose, as long as you credit the
original creator. Commercial use, including paid mods or selling, is not permitted.

## Disclaimer

This mod was developed with the assistance of an LLM. All in-game testing and code
validation was performed by a human. No rogue AIs were permitted through the Blackwall.
