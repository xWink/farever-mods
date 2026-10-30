# DPS Meter

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=dps-meter%2Fv&expanded=true)

A native party damage/healing meter with fight history, detailed reports, and Fareverly uploads.

## Features

- Party and individual damage, healing, shields, and skill breakdowns. The damage/healing toggle applies across windows.
- Movable, lockable windows, optional hiding outside combat, and UI scaling from **50% to 150%** (100% by default).
- Saved encounter history with infinite scrolling, including Rift Gate runs and recaps. Open history with the book button; returning from a fight restores your place in the list.
- Detailed reports with graphs, a continuously scrolling event list, and event filters including source and target. Click the graph to jump to that time, or expand an event for its details.
- Party Ready Check with a countdown and optional audio. The leader can type `rc`; players respond with `r` or `nr`, or use the popup buttons. Use `cancelrc` to cancel.

Reports reflect events observed by your client, so totals can differ between players. Older logs may not contain every detail available in new reports.

## Fareverly

Compare your clears on the [Farever leaderboards](https://fareverly.com/leaderboards), explore saved fights in the [combat-log analyzer](https://fareverly.com/analyze), and follow the [Getting Started guide](https://fareverly.com/getting-started) to connect your game.

Choose **Login to Fareverly** in the mod's settings and sign in with Steam to enable uploads to [fareverly.com](https://fareverly.com). Use **Verify Fareverly connection** to check your saved connection. Eligible boss victories upload in the background.

Ranked uploads require an observed encounter start and uninterrupted recording. Joining or reconnecting during a fight keeps that recording local, including its later phases. A confirmed reset permits a fresh attempt. Older queued logs without start evidence also stay local; their history and analyzer access remain available.

**Open in Fareverly** opens a compatible saved fight in the analyzer; it does not submit it to ranked uploads. Combined recaps and other unsupported reports cannot use this button.

## Saved logs

Fight history is stored in `hlx/mods/dps-meter/history/`, with upload records under `hlx/mods/dps-meter/fareverly/`. Keep these folders when updating.

Logs include each player's last observed primary, secondary/offhand, and arsenal weapons in `equippedWeapons`, with item IDs, rarity, required level, and upgrade level. Empty slots are `null`; an unavailable loadout is `null`. This metadata is not shown in the meter or reports.

Automatic pruning is **enabled by default** and deletes logs older than one year. Change the retention period or disable pruning in Mod Settings. Pruning local files does not remove published logs from Fareverly.

## Installation

Requires HLX Core 0.0.8+, [Better Mod Settings](../better-mod-settings/), and [Mod Update Alerts](../mod-update-alerts/). Follow the [installation instructions](../README.md#installation), then configure the mod in **Game Menu → Mod Settings**.

Also available on [Nexus Mods](https://www.nexusmods.com/farever/mods/11).

Install the **complete ZIP**, including `hlx/plugins/dps-meter/`. The bundled desktop plugin is required; no separate uploader application is needed.

See [Building](../README.md#building) for source builds and tests.
