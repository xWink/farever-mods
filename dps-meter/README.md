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

## Controls

- **F10:** show/hide.
- **F11:** lock/unlock the window. When unlocked, drag the header to move it and
  the lower-right frame grip to resize the whole window. Position and size are saved.
- **Unlock window movement and resizing** in Better Mod Settings also controls locking.
- **Hide when out of combat** in Better Mod Settings enables automatic hiding
  (off by default). **Hiding delay (seconds)** ranges from 0 to 10,
  with a default of 3. After the delay, the whole window fades out over 0.4 seconds.
  The first damaging hit that starts the timer brings it back immediately;
  entering combat alone does not. A zero delay starts the fade immediately.
- The compact header shows the detected boss's name aligned left and the encounter
  timer aligned right, with a background spanning the window's full width.
  Boss names use the game's localized, phase-aware display names. The body
  contains player/skill rows without a mode label or combined damage summary.
- Entering combat arms the meter; the timer starts with the first party attack
  that deals damage, then runs continuously while you remain in combat, including
  pauses in damage. Combat exit freezes the encounter's elapsed time. The finished
  result stays visible until the next attack starts a new fight with fresh totals.
- One-shots count even when the game never sends a combat-entry transition. They
  appear as completed encounters at `0:00`, including the killing blow. A killing
  blow arriving just after combat exit is added to that same enemy's encounter
  without restarting its timer. Auto-hide gives new one-shot results the normal
  hiding delay and fade.
- Only your character's combat state controls the timer; party members still
  contribute damage during your encounter. Damage or healing while you are out
  of combat cannot restart the timer. Opening hits received up to half a second
  before combat entry are retained without running a timer on their own. No
  inactivity timeout splits an active encounter.
  Displayed DPS uses a minimum duration of one second for instant hits; uploaded
  report calculations are unchanged.
- Click a player row to inspect skills; click a skill row to return.
- Player rows show rank/name on the left and `damage (DPS, team damage %)` on
  the right, using the body's full inner width except for a visible scrollbar.
  Long names shorten with an ellipsis to keep the totals readable.
  Bars use the original meter's class colors: warrior red, cleric gold, mage teal,
  and rogue purple; unknown classes use a neutral tan.
- **Upload boss kills to fareverlogs.fr** in Better Mod Settings toggles new
  boss-report exports. Already queued reports can still upload.

The window uses the game's TitleWindow, OptionsContent, text, buttons, and gauges.
It does not open a separate Windows overlay or block gameplay as a modal menu.
Better Mod Settings exposes the toggles and hotkeys. The first launch imports
compatible options from `group-dps.ini` if present; subsequent settings live in
`hlx/mods/dps-meter/config.json`.
The optional `me` override and comma-separated `group` fallback can be edited in
that JSON file. Native window dimensions include its header and controls.

## Collection and uploads

The HLX prefix observes `ent.Unit.rpcReceiveDamage__impl` and always lets the
original game method run, including lethal damage sent after death handling.
Postfixes on `ent.Hero.onEnterCombat` and `ent.Hero.onLeaveCombat` track the local
combat state; the first damage event starts the timer. Party information comes from
the current character's replicated group. It reads `_amount`, `_critical`, `_kill`, `effect`,
`weakSource`, target information, and skill/equipment metadata already visible
to this client. No gameplay RPCs are generated by the meter.

The encounter logic reproduces the inspected Group DPS build's rules:

- Separate damage/healing; one hit per damage result.
- Cast estimates use a gap greater than 350 ms between a player's hits with a skill.
- Boss recognition uses `target.inf.flags & 0x38`. A party member must start the
  encounter. Named players who hit the boss can appear in that boss report.
- Once a participant hits the boss, their subsequent add damage also counts.
  As in the original boss accumulator, healing is excluded from boss totals.
- Eight seconds of inactivity closes a boss attempt without uploading. Matching
  boss phases can resume the saved totals/timer within the original grace periods.
- A kill must target the tracked boss UID; clone/add kills do not export a run.
- Only confirmed boss kills with named players create uploadable JSON.

Reports contain session ID, duration, boss/difficulty/activity metadata, character
names and in-game UIDs, class, damage/DPS/healing counters, weapons observed,
equipped skills, and per-skill statistics. Reports are written through a temporary
file, then renamed into `hlx/mods/dps-meter/logs/run_*.json`. All uploader paths
below are relative to `hlx/mods/dps-meter/`.

The **unchanged supplied uploader.exe** handles the original protocol:

```ini
api_url=https://fareverlogs.fr/api/v1/runs
token=
poll_sec=5
keep_days=7
```

It creates `uploader.ini` if absent. JSON files are POSTed as `application/json`,
with an optional Bearer token. HTTP 2xx moves files to `logs/sent/`; every 4xx,
including 429, moves them to `logs/rejected/`. Other failures remain queued.
Successful files older than `keep_days` are purged on startup; zero keeps them.
It watches the game PID and makes up to three pending passes after game exit.
Inspect `uploader.log` for actual server results.

The small PowerShell launcher discovers the parent game PID and starts the helper
in the background after the first game update. Mod loading creates no worker
thread or child process. The game checks a startup-status file without waiting
for process output or completion; a stuck launcher times out after 30 seconds.
No execution-policy setting is changed. If startup fails, reports remain local.
The HLX mod does not emit trace logs.
If the game PID could not be discovered, reports are saved as `.pending` drafts
and recovered on the next successful launcher startup.

This is a behavioral port from static analysis, not recovered original source.
The transport binary is preserved byte-for-byte.

## Development

Use Haxe 4.3.7:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
haxe compile.hxml
python tools/package.py
```

The independent [DPS Meter workflow](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml)
builds installation artifacts. Release tags use `dps-meter/vX.Y.Z`; download
published versions from [DPS Meter releases](https://github.com/xWink/farever-mods/releases?q=dps-meter%2Fv&expanded=true).
