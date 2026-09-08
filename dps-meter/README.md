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
  The window can be shortened to a minimum height of 110 pixels.
- **Unlock window movement and resizing** in Better Mod Settings also controls locking.
- **Hide when out of combat** in Better Mod Settings enables automatic hiding
  (off by default). **Hiding delay (seconds)** ranges from 0 to 10,
  with a default of 3. After the delay, the whole window fades out over 0.4 seconds.
  The first damaging hit that starts the timer brings it back immediately;
  entering combat alone does not. A zero delay starts the fade immediately.
  On game or instance load, the window stays hidden until an encounter has damage
  to show, including a one-shot result.
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
- Player and skill lists scroll with the mouse wheel or native scrollbar when
  they exceed the body height. Rows stay clipped inside the body; the header stays fixed.
- Player rows show rank/name on the left and `damage (DPS, team damage %)` on
  the right, using the body's full inner width except for a visible scrollbar.
  Long names shorten with an ellipsis to keep the totals readable.
  Bars use the original meter's class colors: warrior red, cleric gold, mage teal,
  and rogue purple; unknown classes use a neutral tan.
- **Upload combat logs to fareverlogs.fr** in Better Mod Settings toggles new
  boss and gate-phase report exports. Already queued reports can still upload.

## Kill notifications

Three settings control text popups centered in the upper part of the screen:

- **Show boss kills** (on by default): `Boss name: 7 kills`.
- **Show incomplete Codex kills** (on by default): `Monster name: 17 / 30 kills`.
  The kill that earns the Codex XP reward still displays `30 / 30`.
- **Show completed Codex kills** (off by default): `Monster name: 43 kills`,
  continuing the full total after that reward is earned.

Bosses use the boss setting; the two Codex settings apply to other Codex enemies.
Completion means the game's XP reward threshold, not the final Codex rank.
Counts come from the current character's saved, server-synchronized progress,
including kills credited through the game's party/rift rules and kills made
before installing the mod. Loading a character or instance does not replay old
counts. Toggling a setting also does not replay previous kills.

The popups use native SmallNotify text with no background and the game's
notification duration/fade timing. Up to three enemy counts appear together;
repeated kills of the same enemy update its existing line. They work independently
of the meter window's visibility and upload setting. The mod replaces the native
recurring Codex count notification while enabled and retains the native reward
and milestone notifications.

## Rifts

In rifts, the meter treats every player present in the instance as a party member.
Their damage and healing count from the notifications visible to your client,
including players who join after the rift starts.

- **Rift: Gates:** starts on the first damaging hit against a monster and keeps
  one timer and set of totals across every wave, even when your character leaves
  combat. Countdown expiry does not end it: cleanup of the remaining gates stays
  in this phase until the real boss spawns. A hit on the real boss also confirms
  the transition if it arrives before the next roster update.
- **Rift: Boss:** starts with the first hit on the real boss identified by the
  rift's KillBoss objective. All present players' subsequent damage, including
  damage to adds and clones, belongs to this phase. Leaving combat or gaps in
  damage do not split it. The server-reported KillBoss objective ends it; killing
  a clone neither ends the encounter nor replaces the real boss's identity.

A full rift observed from the first wave through the boss produces two JSON
reports when uploads are enabled. Reports carry `phase: "Rift: Gates"` or
`phase: "Rift: Boss"`. The monster report has `is_boss: false`; the boss report
keeps the real boss's identity and `is_boss: true`. Late killing blows are retained
before each report is queued once. Joining late only records damage your client
observes, and leaving early does not export an unfinished phase.

The header shows **Rift: Gates** during waves and the game's boss name during the
boss phase. Auto-hide keeps an active phase visible through combat breaks and
uses the usual delay and fade after the phase ends. Game and instance loading
still leave the window hidden until there is damage to show.

After the boss dies, **Rift Recap** opens with **Rift: Gates** and **Rift: Boss**
charts in one native window. The recap uses frozen totals from that same rift,
including late killing blows, and shows each phase's duration. Each chart uses
the meter's class colors, damage/DPS/team-share numbers, independent scrolling,
and clickable skill breakdowns. The charts sit side by side, or stack on a
narrow screen. One **X** closes the entire recap. It also works with uploads
disabled and does not follow the live meter's show/hide or out-of-combat fading.
A phase with no recorded damage shows **No damage recorded**.

Both reports use the existing uploader and endpoint. Acceptance and display of
non-boss rift reports by fareverlogs.fr have not been verified; its server may
need support for that report type. These rift rules do not change dungeon or
open-world tracking.

The window uses the game's TitleWindow, OptionsContent, text, buttons, and gauges.
It does not open a separate Windows overlay or block gameplay as a modal menu.
Better Mod Settings exposes the toggles and hotkeys. The first launch imports
compatible options from `group-dps.ini` if present; subsequent settings live in
`hlx/mods/dps-meter/config.json`.
The optional `me` override marks a matching character name as `is_me` in reports;
the game still determines which hero's combat state the meter follows. The
comma-separated `group` names are a fallback outside rifts when the game's party
roster has been unavailable for more than five seconds. Both can normally stay
empty. The legacy `debug` value is saved for compatibility but has no effect.
Native window dimensions include its header and controls.

## Collection and uploads

The HLX prefix observes `ent.Unit.rpcReceiveDamage__impl` and always lets the
original game method run, including lethal damage sent after death handling.
Postfixes on `ent.Hero.onEnterCombat` and `ent.Hero.onLeaveCombat` track the local
combat state; the first damage event starts the timer. Party information comes from
the current character's replicated group. It reads `_amount`, `_critical`, `_kill`, `effect`,
`weakSource`, target information, and skill/equipment metadata already visible
to this client. No gameplay RPCs are generated by the meter.

Outside rifts, the report logic reproduces the inspected Group DPS build's rules:

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

The launcher creates `uploader.ini` without a comment header if it is absent.
On startup it also removes the original five-line French header from existing
files, preserving settings and other comments. JSON files are POSTed as `application/json`,
with an optional Bearer token. HTTP 2xx moves files to `logs/sent/`; every 4xx,
including 429, moves them to `logs/rejected/`. Other failures remain queued.
Successful files older than `keep_days` are purged on startup; zero keeps them.
It watches the game PID and makes up to three pending passes after game exit.
Inspect `uploader.log` for actual server results.

The small PowerShell launcher starts hidden, without flashing a terminal window.
It discovers the parent game PID and starts the helper
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
