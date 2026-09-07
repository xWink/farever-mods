# Farever Mods

Independent HLX mods for Farever, maintained together in one repository.

Each project has its own source, build, installable ZIP, and versioned releases.

| Mod | Source | CI builds | Releases |
| --- | --- | --- | --- |
| Better Mod Settings | [better-mod-settings](better-mod-settings/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-better-mod-settings.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=better-mod-settings&expanded=true) |
| Item Utilities | [item-utilities](item-utilities/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-item-utilities.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=item-utilities&expanded=true) |
| Disable Profanity Filter | [disable-profanity-filter](disable-profanity-filter/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-disable-profanity-filter.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=disable-profanity-filter&expanded=true) |
| Mute on Unfocus | [mute-on-unfocus](mute-on-unfocus/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-mute-on-unfocus.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=mute-on-unfocus&expanded=true) |
| Fix Target Lock | [fix-target-lock](fix-target-lock/) | [Build](https://github.com/xWink/farever-mods/actions/workflows/build-fix-target-lock.yml) | [Downloads](https://github.com/xWink/farever-mods/releases?q=fix-target-lock&expanded=true) |

## Installing

Download the ZIP for the mod you want. Install it with Vortex, or extract it into
the Farever game directory. Each archive contains just that mod under
`hlx/mods/`. Installation requirements and Nexus Mods links are in each project's
README. Existing installed mod folders and config filenames are unchanged.

## Building

Use Haxe 4.3.7 and install the same dependencies used by CI:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
haxelib git hl-imgui https://github.com/laymain/farever-mods.git main imgui/hl-imgui/src
```

Change into the project you want to compile:

```sh
cd item-utilities
haxe compile.hxml
```

Each `compile.hxml` is self-contained and writes to that project's `build/`
directory. Mute on Unfocus retains the installed module name `mute-unfocused`.

## Independent CI and releases

Each mod has its own workflow in `.github/workflows/build-<project>.yml`:

- Pushes to `main` and pull requests build only projects whose directory or
  workflow changed. Changing the shared `_build-mod.yml` builds all five.
- Each workflow can also be run manually on `main` to produce an installable build artifact.
- A tag such as `item-utilities/v1.2.2` builds and releases only Item Utilities.
  Versions are independent; there is no repository-wide version.
- Releases contain one Vortex-compatible ZIP named `farever-<project>.zip`.
  Tags ending in a prerelease suffix, such as `-rc.1`, produce prereleases.

See [RELEASING.md](RELEASING.md) for the release procedure and
[MIGRATION.md](MIGRATION.md) for preserved history and earlier releases.
