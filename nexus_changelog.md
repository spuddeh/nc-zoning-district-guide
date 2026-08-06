# NC Zoning Board - District Guide - Release Changelog

Public, user-facing changelog. Plain language, only what matters to the people playing with this
mod. The full technical detail lives in `@changelog.md`.

### [Unreleased - v1.1.0]

- New: A mod card for the Redscript Configuration Framework 2.1.0. The guide now appears in RCF's
  new picker with its header image, category and a short description.
- New: Translation slots for all 19 game languages. A translation is a single file, and anyone can
  release one as its own mod without waiting for an update here.
- Changed: Log lines now carry a level, so RCF 2.1.0's log viewer shows errors in red and warnings
  in amber. If you attach a log to a bug report, the important lines now stand out.
- Changed: RedLogger 1.3.0 or newer is now required. RCF 2.1.0 calls RedLogger functions older
  builds do not have, and the two together stop every redscript mod on your machine from loading.

### v1.0.0

- New: Initial public release. The NC Zoning Board map in game, on four surfaces built out of
  the game's own UI: a district-entry notice, a fast-travel arrival panel, a world map district
  breakdown, and a keybind-opened guide.
- New: The guide lists every mapped location by district, with photographs, search by name,
  author or tag, a SHOW ON MAP button that places a waypoint and starts routing, and a teleport.
- New: With Cyber Engine Tweaks installed, the guide marks which location mods you already have
  and can filter to installed, missing, or undetectable.
- New: Recently updated locations are flagged in green and sorted to the front.
- New: Every setting lives in the Redscript Configuration Framework overlay (F8), including the
  rebindable open key and its optional modifier.

---

## Release body

Paste into the GitHub release body. The workflow splits on `<!-- nexus-description-end -->`: what is
above it becomes the Nexus **file description**, what is below becomes the **changelog entry**.

**Nexus stores a changelog as one bullet PER LINE.** The lines below are therefore unwrapped, and
carry no `-`, no markdown and no version heading: a wrapped line arrives as two bullets, a leading
dash arrives inside the bullet, and the version is sent in its own field.

```text
Adds a mod card for the Redscript Configuration Framework 2.1.0 and translation slots for 19 languages. RedLogger 1.3.0 or newer is now required.

<!-- nexus-description-end -->

New: A mod card for the Redscript Configuration Framework 2.1.0, so the guide appears in its new picker with a header image, category and description.
New: Translation slots for all 19 game languages. A translation is a single file, and anyone can release one as its own mod without waiting for an update here.
Changed: Log lines now carry a level, so RCF 2.1.0's log viewer shows errors in red and warnings in amber. If you attach a log to a bug report, the important lines now stand out.
Changed: RedLogger 1.3.0 or newer is now required. RCF 2.1.0 calls RedLogger functions older builds do not have, and the two together stop every redscript mod on your machine from loading.
```

> File description: 145 / 255 characters.

---

## Stickied Comment BBCode

```text
[color=#00f0ff][size=5][b]- Changes -[/b][/size][/color]

[b][size=3]Version 1.1.0[/size][/b]
[list][*]New: A mod card for the Redscript Configuration Framework 2.1.0.
[*]New: Translation slots for all 19 game languages, releasable as separate mods.
[*]Changed: Log lines now carry a level, colour-coded in RCF 2.1.0's log viewer.
[*]Changed: RedLogger 1.3.0 or newer is now required.
[/list]
[b][size=3]Version 1.0.0[/size][/b]
[spoiler][list][*]Initial public release.
[/list][/spoiler]
```

> Character count: 488 / 5000
