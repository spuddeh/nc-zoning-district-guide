# optional-files

Translations that ship **separately from the mod**, one Nexus optional file each.

Each folder here is already the shape of an installable mod. Zip its contents starting at `r6/` and
upload it; nothing else needs building.

```text
German/r6/scripts/NCZoningDistrictGuide/translations/German.reds
```

## Why they are not in the mod

The mod ships a slot for every language, empty, falling through to English. A translation replaces one
slot file, and the mod manager hides the mod's copy - so a translation can be released, updated or
withdrawn without a release here, by anyone.

A player downloads only the language they play in, so two of these never meet. Even if they did, each
one replaces a different file.

Keeping the translated files *out* of the mod is what makes that true. A translation bundled in the
mod can only be updated by releasing the mod.

Instructions for a translator: [docs/TRANSLATING.md](../docs/TRANSLATING.md)

## What is here

| Language | Translator |
| --- | --- |
| German | D/Code |
| Russian | Parasitko |
