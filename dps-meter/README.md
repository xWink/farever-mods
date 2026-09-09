# DPS Meter

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=dps-meter&expanded=true)

An HLX combat meter with a movable, resizable native Farever window and boss-kill
uploads to [Farever Logs](https://fareverlogs.fr/).

## Installation

### Easy Installation

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core) and [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings) with Vortex.
2. Download DPS Meter with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/11).
3. Enable and deploy the mods, then launch Farever.

### Manual Installation

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core).
2. Install [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings) to configure the meter in-game.
3. Download the latest DPS Meter [release](https://github.com/xWink/farever-mods/releases?q=dps-meter&expanded=true) or the `farever-dps-meter` artifact from a successful [build](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml).
4. Extract the ZIP directly into the Farever game directory. The archive already contains `hlx/mods/dps-meter/`.
5. Launch Farever.

All mod files are contained in `hlx/mods/dps-meter/`. Upload settings
(`uploader.ini`), upload history (`uploader.log`), and queued reports (`logs/`)
also live in this folder. ImGui and an external uploader are not required.

Use DPS Meter in place of the original Group DPS `dinput8.dll` collector to avoid
running two collectors that export the same encounters. Keep DLLs belonging to
unrelated mods. Installation does not replace `uploader.ini`, `group-dps.ini`, or
saved meter settings.

### Upgrading from the external uploader

Close Farever and let the old uploader finish before upgrading. Existing
`uploader.ini` settings and queued logs in the mod folder are reused automatically.
You can remove the old `uploader.exe`, `start-uploader.ps1`, and
`UPLOADER-NOTICE.md` from `hlx/mods/dps-meter/`. Uploads now run while Farever is
open; unsent reports resume on the next launch.

If your uploader files are still in the game directory, move their
`uploader.ini`, `uploader.log`, and uploader-owned `logs/` contents into
`hlx/mods/dps-meter/`, preserving the `logs/` subdirectories. Do not overwrite
existing files or copy reports into both queues. Existing files in the game
directory are not migrated automatically. The old game-folder `uploader.exe`
can be removed if no other mod uses it.

## Highlights

- **Live party DPS:** Damage, DPS, and team contribution with class-colored bars and clickable skill breakdowns.
- **Summon tracking:** Minion damage credited to its owner and the skill that summoned it.
- **Native, customizable window:** Move, resize, lock, and scroll the meter, with optional automatic hiding and a smooth fade.
- **Rift tracking and recaps:** Separate gate and boss phases covering all players present, with both charts in one post-rift recap.
- **Kill notifications:** Optional boss kill totals and Codex progress popups, including counts for completed entries.
- **Automatic log uploads:** Send completed boss encounters to [Farever Logs](https://fareverlogs.fr/) in the background, with no external application.
- **Better Mod Settings integration:** Customize display options and hotkeys, with settings and window placement saved between sessions.
