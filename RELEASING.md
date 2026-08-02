# Releasing

This repo publishes NC Zoning District Guide to **GitHub Releases** and **Nexus Mods** via
[`.github/workflows/release.yml`](.github/workflows/release.yml), driven by
[`release-manifest.json`](release-manifest.json).

NC Zoning District Guide is pure redscript (loose `.reds` files, no `.archive`), so there is no WolvenKit
step: the workflow stages the artifact's `contentDir` into its `installDir` (the in-game path)
and zips that, so `r6/...` lands at the zip root exactly as the game expects.

| Artifact id | What | File on Nexus |
| --- | --- | --- |
| `nczoningdistrictguide` | The mod | main |

## First release is manual (then it automates)

A Nexus **file id does not exist until a file has been uploaded once**, so the very first
upload cannot come from CI. Do this once:

1. **Create the Nexus mod page** for NC Zoning District Guide and set its requirements, description
   (paste [`nexus_description.bbc`](nexus_description.bbc)), and category (Modders Resources).
2. **Build the first zip locally** and upload it by hand through the Nexus site. Build it the
   same way the workflow does, so the layout matches:
   ```pwsh
   # from the repo root; produces NCZoningDistrictGuide_v1.0.0.zip with r6/... at the zip root
   $stage = New-Item -ItemType Directory -Force -Path (Join-Path $env:TEMP "nczc_stage")
   Remove-Item -Recurse -Force $stage\*; New-Item -ItemType Directory -Force -Path "$stage\r6" | Out-Null
   Copy-Item -Recurse "r6\*" "$stage\r6\"
   Compress-Archive -Path "$stage\r6" -DestinationPath "NCZoningDistrictGuide_v1.0.0.zip" -Force
   ```
   (The zip must contain `r6\scripts\NCZoningDistrictGuide\*.reds`, `r6\input\nczdg.xml` and
   `r6\storages\RedscriptConfigFramework\NCZoningDistrictGuide.docs.txt`. The user extracts it into their
   Cyberpunk 2077 root.)
3. **Read the file id and set it as a repository VARIABLE.** On the mod page open the **Files**
   tab > **API Info** (or the Manage Files edit menu) and copy the id — Nexus labels it
   **"Group ID"** there, but it is what the upload action's `file_id` input wants. Set it as the
   repository variable **`NEXUS_FILE_ID_NCZONINGCORE`** (Settings > Secrets and variables >
   Actions > **Variables**), and set `nexus_mod_id` in `release-manifest.json` to the mod page
   number.

   > **It does not go in the repo.** The id does not exist until this first upload, so there is
   > nothing valid to commit.
   >
   > **Do NOT take the id from the public v1 API.** That endpoint has a field also called
   > `file_id`, in a different id space. The wrong value looks plausible and fails only at
   > release time.
   >
   > **A variable, not a secret:** it is an identifier, not a credential, and does nothing
   > without `NEXUSMODS_API_KEY`. As a secret it would render `***` in the logs, which makes a
   > wrong id much harder to diagnose.
4. **Add the API key secret.** Create a Nexus personal API key at
   <https://www.nexusmods.com/settings/api-keys> and add it as the repository secret
   **`NEXUSMODS_API_KEY`** (Settings > Secrets and variables > Actions > **Secrets**).

After that, every future release publishes automatically.

## Before cutting any release: bump the version

The version in the git tag is what CI ships, but the version also appears in the source and
docs and must be kept in sync. Before releasing, set the new version in:

- each `.reds` header (`Mod Version:` line) and `NCZoning.Api` `Version()` / `NCZoningApi`
  `Version()` (only bump `ApiVersion()` on a breaking API change),
- `@changelog.md` and `@features.md`,
- `currentVersion` in `release-manifest.json`.

## Cutting a release

1. Commit the version bump and your changes.
2. Create a GitHub Release whose **tag** is `nczoningdistrictguide-v<version>`:
   ```pwsh
   gh release create nczoningdistrictguide-v1.0.0 --title "NC Zoning District Guide v1.0.0" --notes "..."
   ```
   The release body feeds two Nexus fields, split by a `<!-- nexus-description-end -->` marker on its own line. Everything **before** the marker becomes the **file description** (capped at 255 chars — for example a new requirement, or "delete the old folder first"); everything **after** it is appended to the mod page's **changelog**. With no marker at all, the whole body becomes the changelog and no file description is sent.
3. On publish, the workflow parses the tag, zips `r6` as
   `NCZoningDistrictGuide_v<version>.zip`, attaches it to the GitHub Release, and uploads to Nexus.
4. **On the Nexus mod page:** the workflow sets the **Mod Version** field and appends the
   **changelog** entry itself. Only the mod **description** is still manual.
   The changelog endpoint APPENDS rather than replaces, so publishing the same release twice
   leaves the entry on the page twice and nothing here can remove it. A `workflow_dispatch`
   re-run never posts a changelog.

You can also run it manually from the **Actions** tab (workflow_dispatch) with `artifact` +
`version` inputs (and an optional existing `tag` to attach the zip to).

## Notes

- The Nexus upload uses [`Nexus-Mods/upload-action`](https://github.com/Nexus-Mods/upload-action),
  pinned to `v1.0.0-beta.10` (the Nexus v3 upload API). The `createModFileVersion` endpoint it
  uses replaces the old `createUpdateGroupVersion`, which Nexus **removes on 2026-09-09** — so a
  pin older than beta.8 stops uploading after that date. beta.9 added `update_mod_version`, beta.10
  the changelog endpoint; both are wired up here. The API is still labelled evaluation-only, so bump
  the pin when a stable release appears (watch for further input renames).
- `archive_existing_version: true` archives the previous file when a new version is uploaded.
- `show_requirements_pop_up: true` shows the requirements popup on download (NC Zoning District Guide has
  dependencies). It is on for this artifact.
- The workflow honours an invisible `<!-- skip-nexus -->` marker in a release body (a
  GitHub-only release), though NC Zoning District Guide has no historical releases to backfill.
