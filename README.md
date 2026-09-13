# Farever Mods

Independent HLX mods for Farever, maintained together in one repository.

Each project has its own source, build, installable ZIP, and versioned releases.

| Mod | Source | CI builds | Releases |
| --- | --- | --- | --- |
| Better Mod Settings | [better-mod-settings](better-mod-settings/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-better-mod-settings.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=better-mod-settings&expanded=true) |
| Item Utilities | [item-utilities](item-utilities/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-item-utilities.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=item-utilities&expanded=true) |
| Disable Profanity Filter | [disable-profanity-filter](disable-profanity-filter/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-disable-profanity-filter.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=disable-profanity-filter&expanded=true) |
| More Settings | [more-settings](more-settings/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-more-settings.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=more-settings&expanded=true) |
| Fix Target Lock | [fix-target-lock](fix-target-lock/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-fix-target-lock.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=fix-target-lock&expanded=true) |
| DPS Meter | [dps-meter](dps-meter/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=dps-meter%2Fv&expanded=true) |
| Minimap | [minimap](minimap/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=minimap%2Fv&expanded=true) |

## Installing

Download the ZIP for the mod you want. Install it with Vortex, or extract it into
the Farever game directory. Each archive contains just that mod under
`hlx/mods/`. Installation requirements and Nexus Mods links are in each project's
README. Installed mod folders are unchanged.

All mods require HLX Core. Only Item Utilities also requires the
[Farever ImGui plugin](https://www.nexusmods.com/farever/mods/4), which draws its
deposit buttons, equipment presets, and item-lock controls and icons.
DPS Meter handles log uploads inside the HLX mod and uses native game UI.

## Settings

All configurable mods use HLX's native `@:hlx.config` persistence at
`hlx/config/<module-name>/config.json`. On the first launch after upgrading,
settings are imported from the previous `hlx/mods/<module-name>/config.json`
when no native file exists. Existing native files take priority; the old files
are left intact as backups. This preserves hotkeys, window placement, item locks,
and weapon presets.

Update Better Mod Settings along with the mods. Its `configFormats.json`
descriptors stay beside the `.hl` files and no longer need a `configFile` key.
The settings menu edits the native files and applies changes immediately; it
also recognizes the old `config.json` location for mods that have not migrated.
DPS Meter retains upload settings in `hlx/mods/dps-meter/uploader.ini`.

## Building

Use Haxe 4.3.7 and install the same dependencies used by CI:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
```

Only Item Utilities needs the additional ImGui library:

```sh
haxelib git hl-imgui https://github.com/laymain/farever-mods.git main imgui/hl-imgui/src
```

Change into the project you want to compile:

```sh
cd item-utilities
haxe compile.hxml
```

Each `compile.hxml` writes to that project's `build/` directory. Configurable
mods also compile the migration helper from `shared/src/`.

## Independent CI and releases

Each mod has its own workflow in `.github/workflows/build-<project>.yml`:

- Pushes to `main` and pull requests build only projects whose directory or
  workflow changed. Changes under `shared/` build all mods that use the migration
  helper; changes to `_build-mod.yml` build projects using that workflow.
- Each workflow can also be run manually on `main` to produce an installable build artifact.
- A tag such as `item-utilities/v1.2.2` builds and releases only Item Utilities.
  Versions are independent; there is no repository-wide version.
- Releases contain one Vortex-compatible ZIP named `farever-<project>.zip`.
  Tags ending in a prerelease suffix, such as `-rc.1`, produce prereleases.

See [RELEASING.md](RELEASING.md) for the release procedure and
[MIGRATION.md](MIGRATION.md) for preserved history and earlier releases.
