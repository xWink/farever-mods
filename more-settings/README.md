# More Settings

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-more-settings.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=more-settings%2Fv&expanded=true)

Additional camera, combat, social, and visual settings for Farever.

## Features

- **General:** field-of-view slider, hide-UI hotkey, leave-dungeon and leave-rift buttons, and optional performance improvements and diagnostics.
- **Combat:** damage-number styles, scale, and opacity; independent None/Low/Medium/High/Max limits for damage numbers, bees, and Bomblets; hold-to-repeat after a one-second hold, exclusively for weapon, class, and signature skills; enemy-distance nameplates, skill icons/proc alerts, outlined buff stacks, boss health, Crabgantua warnings, and allied minion health-bar visibility.
- **Social:** message timestamps, profanity-filter control, friend notes and notifications, self chat bubbles, chat behavior, and social-interact bindings.
- **Effects:** separate controls for your own and allied attacks/buffs in rifts, dungeons, and the overworld, plus ally visibility controls.
- **Character tools:** character deletion locks and a native appearance editor with Save/Cancel.

Visual limits work with **Performance improvements** on or off. **Max** preserves the game's default visuals without a mod-imposed cap. Damage numbers default to **Medium**; bees and Bomblets default to **Max**. Saved numeric sliders migrate to the nearest preset.

| Visual limit | None | Low | Medium | High | Max |
| --- | --- | --- | --- | --- | --- |
| Damage numbers | 0 | 10 | 25 | 50 | Game default |
| Bees | 0 | 2 | 10 | 30 | Game default |
| Bomblets | 0 | 5 | 25 | 50 | Game default |

Quick casting and target-lock camera controls are provided by [Fix Target Lock](../fix-target-lock/).

## Installation and upgrade

Requires HLX Core 0.0.8+, [Better Mod Settings](../better-mod-settings/), and [Mod Update Alerts](../mod-update-alerts/). Follow the [installation instructions](../README.md#installation), then configure the mod in **Game Menu → Mod Settings**.

When upgrading from **More Audio Settings**, **Mute on Unfocus**, or the standalone **Disable Profanity Filter**, remove or disable the old mod binaries so both copies do not run. Keep their configuration files for migration. Audio controls previously offered by More Audio Settings are now available in the game itself.

See [Building](../README.md#building) for source builds and tests.
