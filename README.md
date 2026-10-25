# Farever Mods

Independent HLX mods for Farever. Each mod has its own build, installable ZIP, and version.

Visit [Fareverly](https://fareverly.com) for [mod showcases](https://fareverly.com/mods), [boss leaderboards](https://fareverly.com/leaderboards), [combat-log analysis](https://fareverly.com/analyze), and the [Farever marketplace](https://fareverly.com/marketplace). New to modding? Start with the [Getting Started guide](https://fareverly.com/getting-started).

| Mod | Downloads | Test builds |
| --- | --- | --- |
| [Better Mod Settings](better-mod-settings/) | [Releases](https://github.com/xWink/farever-mods/releases?q=better-mod-settings%2Fv&expanded=true) | [Builds](https://github.com/xWink/farever-mods/actions/workflows/build-better-mod-settings.yml) |
| [Item Utilities](item-utilities/) | [Releases](https://github.com/xWink/farever-mods/releases?q=item-utilities%2Fv&expanded=true) | [Builds](https://github.com/xWink/farever-mods/actions/workflows/build-item-utilities.yml) |
| [More Settings](more-settings/) | [Releases](https://github.com/xWink/farever-mods/releases?q=more-settings%2Fv&expanded=true) | [Builds](https://github.com/xWink/farever-mods/actions/workflows/build-more-settings.yml) |
| [Fix Target Lock](fix-target-lock/) | [Releases](https://github.com/xWink/farever-mods/releases?q=fix-target-lock%2Fv&expanded=true) | [Builds](https://github.com/xWink/farever-mods/actions/workflows/build-fix-target-lock.yml) |
| [DPS Meter](dps-meter/) | [Releases](https://github.com/xWink/farever-mods/releases?q=dps-meter%2Fv&expanded=true) | [Builds](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml) |
| [Minimap](minimap/) | [Releases](https://github.com/xWink/farever-mods/releases?q=minimap%2Fv&expanded=true) | [Builds](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml) |
| [Mod Update Alerts](mod-update-alerts/) | [Releases](https://github.com/xWink/farever-mods/releases?q=mod-update-alerts%2Fv&expanded=true) | [Builds](https://github.com/xWink/farever-mods/actions/workflows/build-mod-update-alerts.yml) |
| [Trade and Marketplace](trade-and-marketplace/) | [Nexus Mods](https://www.nexusmods.com/farever/mods/30) | [Releases](https://github.com/xWink/farever-mods/releases?q=trade-and-marketplace) |

## Installation

1. Install [HLX Core 0.0.8 or newer](https://github.com/hlx-framework/hlx-core/releases).
2. Install [Better Mod Settings](better-mod-settings/) and [Mod Update Alerts](mod-update-alerts/). The other mods require both.
3. Install each mod's complete ZIP with Vortex and deploy, or extract it into the Farever game directory. Restart the game.

Install the entire archive, including any files under `hlx/plugins/`. When updating, preserve your configuration and saved logs. Check each mod's README for any upgrade instructions. No mod here requires ImGui.

## Settings

Open **Game Menu → Mod Settings**. Settings are saved under `hlx/config/<module-name>/`; shared settings use `hlx/config/common/`.

## Building

Use Haxe 4.3.7 and install the HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd item-utilities
haxe test.hxml
haxe compile.hxml
```

Replace `item-utilities` with the desired project. Builds go into its `build/` directory. GitHub Actions runs the project's checks and packages a complete installable ZIP, including native components where needed.

See [RELEASING.md](RELEASING.md) for publishing and [MIGRATION.md](MIGRATION.md) for repository history.
