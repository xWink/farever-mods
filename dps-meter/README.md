# DPS Meter

An HLX combat meter with a movable, resizable native Farever window and boss-kill
uploads to [Farever Logs](https://fareverlogs.fr/).

## Installation

Install [HLX Core](https://github.com/hlx-framework/hlx-core), then extract this
mod's build archive into the Farever game directory (or install with Vortex).
All mod files, including `dps-meter.hl` and the original `uploader.exe`, are
contained in `hlx/mods/dps-meter/`. The uploader's `uploader.ini`, `uploader.log`,
and `logs/` queue also live in this mod folder. ImGui is not required.

Use DPS Meter in place of the original Group DPS `dinput8.dll` collector to avoid
running two collectors that export the same encounters. Keep DLLs belonging to
unrelated mods. Installation does not replace `uploader.ini`, `group-dps.ini`, or
saved meter settings.

### Upgrading from the game-folder uploader

Close Farever and let the old uploader finish before upgrading. To preserve its
settings and queued reports, move the old `uploader.ini`, `uploader.log`, and
uploader-owned `logs/` contents from the game directory into
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
- **Automatic log uploads:** Send completed boss encounters to [Farever Logs](https://fareverlogs.fr/).
- **Better Mod Settings integration:** Customize display options and hotkeys, with settings and window placement saved between sessions.
