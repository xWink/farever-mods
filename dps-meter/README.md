# DPS Meter

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=dps-meter&expanded=true)

An HLX combat meter with a movable, resizable native Farever window and boss-kill
uploads to [Farever Logs](https://fareverlogs.fr/).

Targets the September 30 Live client. Requires HLX Core 0.0.8 or newer.

## Installation

**Required:** HLX Core, [Better Mod Settings](https://www.nexusmods.com/farever/mods/10), and [Mod Update Alerts](https://www.nexusmods.com/farever/mods/17). A missing dependency shows a desktop error naming what to install and closes Farever before this mod starts.

Install the **complete archive**, including the `implementation/` subfolder. Missing or mismatched implementation files also stop startup with a reinstall message.

### Easy Installation

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core) and [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings) with Vortex.
2. Download DPS Meter with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/11).

### Manual Installation

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core).
2. Install [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings) (required) to configure the meter in-game.
3. Download the latest DPS Meter [release](https://github.com/xWink/farever-mods/releases?q=dps-meter&expanded=true) or the `farever-dps-meter` artifact from a successful [build](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml).
4. Extract the complete ZIP directly into the Farever game directory. It contains `hlx/mods/dps-meter/` and `hlx/plugins/dps-meter/`.
5. Launch Farever.

The mod and its data are contained in `hlx/mods/dps-meter/`. Upload settings
(`uploader.ini`), upload history (`uploader.log`), and queued reports (`logs/`)
also live in this folder. Local fight charts live in `history/<encounter>/`. An external
uploader is not required. The included Windows x64 desktop plugin,
`hlx/plugins/dps-meter/dps_meter_desktop.hdll`, supports folder opening, Recycle Bin
deletion, and image clipboard access. Install this folder too when updating manually.

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

- **Live party DPS:** Damage, DPS, and team contribution with class-colored bars and clickable skill breakdowns using game skill names and each skill's share of that player's damage.
- **Summon tracking:** Minion damage credited to its owner and the skill that summoned it.
- **Native, customizable window:** Move, resize, lock, and scroll the meter, with optional automatic hiding and a smooth fade.
- **Controller focus:** The live meter stays out of controller navigation so it does not take focus from the game's menu controls. Its buttons, charts, dragging, and resizing remain mouse-operated; full controller navigation is not implemented.
- **Rift tracking and recaps:** Separate gate and boss phases covering all players present, with both charts in one post-rift recap.
- **Fight history:** Save Boss Dungeons, Classic Dungeons, World Bosses, and **Target Dummies**; choose an attempt by date, character, party size, duration, and your DPS, then reopen its player and skill charts. Other unclassified combat is not saved; existing Other history remains available.
- **Kill notifications:** Optional boss kill totals with the previous fastest kill time. **Show unmastered Codex kills** displays progress through each enemy's final mastery requirement, including the finishing kill. **Show mastered Codex kills** displays subsequent kill totals. The target comes from the game's enemy-specific Codex thresholds, rather than the earlier XP reward milestone. Existing settings are preserved; unmastered notifications default to on and mastered notifications to off.
- **Automatic log uploads:** Send completed boss encounters to [Farever Logs](https://fareverlogs.fr/) in the background, with no external application.
- **Better Mod Settings integration:** Customize display options and hotkeys, with settings and window placement saved between sessions.

## Healing meter

Click the sword/cross button next to Fight History to switch the live meter between
**damage/DPS** and **healing output/HPS**. The same toggle appears to the left of
Snapshot when reviewing a fight, including rift recaps. Each window remembers its
view until the game restarts. Both kinds of data are always collected and saved;
switching views does not reset the encounter or change its damage statistics.

Healing output includes overhealing. Click a healer to view their abilities,
healing share, output, casts, hits, critical rate, and HPS. The history header
shows the selected player's HPS and total healing. The meter does not display or
save actual/effective healing or overheal amounts: the client does not receive
reliable pre-heal HP for each healing event.

Healing includes self-heals and other-player-to-other-player heals observed by this
client. Exact owner-delivered `rpcDisplayHeal` results take priority. When those
notifications are absent, the meter uses `playHitHealFX` for caster/ability identity.
Status healing follows its original instigator; summon healing follows its owner
and summoning ability. The game’s own healing scaling helper estimates missing
output using the skill’s rank, attributes, stacks and tick count. Final server
scripts/modifiers and remote critical rolls are not fully replicated, so these
amounts are estimates.

Healing values are displayed as plain numbers. **Unavailable** means an amount
could not be determined; **—** means the critical rate is unknown. Critical rates
use the known rolls only. Evidence quality remains recorded in log metadata.

The existing HP correlation remains only as a lower bound for output estimates
and to avoid counting a matched heal again as unattributed recovery. It does not
produce an actual-healing statistic. The same heal is not counted once for its FX
and again for its exact notification. Counts settle after a short correlation delay.

An unmatched combat HP gain appears as **Regen / unattributed**, credited to the
recipient. This is observed recovery, not proof of regeneration, a known caster,
or a total including overheal. Spawn/revive initialization and out-of-combat
recovery are excluded from this bucket. No method here guarantees a complete
server combat log: effects outside client visibility and server-only scripted
heals can still be missing or unattributed.

New history records and uploader reports add a `healing` object per player with
`output`, hit/crit/cast counts, and a `skills` array. Evidence counts (`knownCritHits`,
`estimatedHits`, `unknownOutputHits`, `unattributedHits`) preserve the distinction
between exact output, estimates and recovery-only data. Actual-healing, overheal,
and effective-healing coverage fields are no longer written. Damage fields and
history format version are unchanged. Older logs remain readable; obsolete
healing fields are ignored. Pending heals stay attached to the encounter/phase
where observed, including through exit and recap finalization.

See [healing-attribution.md](healing-attribution.md) for the client-code investigation
and the limits of each evidence source.

## Reviewing past fights

Click the **book icon** on the left of the meter's header. Choose a category and an encounter name,
then an attempt. You can also assign **Open or close history hotkey** in the new
**Combat History** settings section; it starts unbound. It toggles the whole history
window, ignores typing in text fields, and uses BMS's central hotkey-assignment protection.
The list defaults to all characters, newest first. Use the controls
above it to sort by time, your DPS, or duration in ascending or descending order,
and filter by your character and **Outcome**: **Any** (default), **Victory**, or **Defeat**.
Older logs with an unknown outcome appear under **Any**. Character names retain their class colour when opening,
hovering, and selecting dropdown options. Clicking outside a dropdown closes it.
The history window keeps the cursor available while it is open, including after
selecting or dismissing a dropdown. Closing history releases its cursor request
through the game's normal window handling.
The selected
sort and filter stay in place when opening a chart, going Back, or deleting a log;
a new history window starts with the defaults. Sorting/filtering covers every log
before pagination, and unavailable DPS stays last in either direction.
Each attempt shows local date and time,
character name, party size, and **Victory** or **Defeat** on the first row, then duration and your DPS on the
second. Only the character name uses its class colour; the other text keeps its
normal colour. New charts retain the largest party roster observed during the fight,
including members who dealt no damage. Older logs without a saved roster show
the recorded player count as a lower bound (for example, **Party: ≥2**). The DPS
uses the same duration and one-second minimum as the live chart. If an older
report did not identify your character, the list shows that your DPS is unavailable.
Names and durations are treated as literal text, including **<1 sec** for instant fights.

Boss kill notifications also show **Best:** the fastest earlier **Victory**
against that boss on the same difficulty, for the same character name and class.
Times include hundredths of a second. The current fight is excluded even if its
log has already been saved. The label stays **Best:** for every kill. If you set
a new record, the popup still shows the old best; the new time becomes eligible
on the next kill. A first recorded victory shows **none**.
Existing logs with confirmed victories count immediately; older logs with unknown
outcomes cannot establish a kill record. Missing character identity or difficulty
shows **unavailable**. Recycling a record's log removes it from future comparisons.
The background worker loads the history index at startup and keeps its compact
summaries in memory, updating them as logs are saved or recycled. Lookups can
briefly show an ellipsis while that worker is busy, but no longer wait for the
current fight to finish or settle its final damage. The result updates the kill
popup without extending its lifetime.

Selecting an attempt replaces the list with that fight's damage chart. Its summary
shows date and time, character name, your DPS, duration, and outcome together in that order,
followed by **Physical: X% · Magical: Y% · Raw: Z%** for that character's total damage. These
percentages also appear in snapshots. New recordings classify each hit using the
game's physical/magic flags and explicit Raw affinity; healing is excluded.
Chaos remains magical. Unclassified damage is logged and stays in the total used
for percentages, but is omitted from the display. Earlier breakdowns that recorded
the Raw affinity under unclassified recover its share when opened. Older logs without
damage-type information keep their existing summary. Click a
player to see their skills and update the header to their name, DPS, and damage-type
percentages. Click a skill row to return to the player chart and the original summary.
Each ability occupies one row with its game icon, display name, total damage,
and share of your damage. A full-width history view also has casts,
average damage per cast, hits, average damage per hit, and critical-hit percentage.
Regular breakdowns end with **DPS**, calculated over the whole fight's duration;
rift recap tables keep their compact columns without DPS.
**Damage (%)** shows only the skill's numeric share of the player's total damage.
The adjacent **Phys/Magic/Raw** column shows the split within that skill's damage:
red for physical, blue for magical, and off-white for Raw. Each bar represents
100% of that skill's damage, regardless of its contribution to the player's total.
Percentages appear above each bar in the order shown in the column heading.
Narrow windows wrap the heading and stack the values vertically so all three
percentages remain readable.
Column headers stay fixed while the skill rows below them scroll. Snapshots
include the headers and the full table.
Logs with missing or incomplete damage-type data show a dash instead of a bar.
The numeric total keeps its separate **Damage** column. Narrow windows abbreviate
headings and keep the core columns readable. Ability rows have no hover tooltip.
**Back** returns to the same page of attempts, then to the encounter names.
**Escape** closes an open sort/filter dropdown first, then the history window,
without also closing a window underneath it.
The encounter and attempt lists have page controls and scroll when space is limited. The history
window stays open independently of the live meter's out-of-combat fade.
The folder row appears only at the bottom of **Choose a category** and shows the
full absolute path to the local archive. Click its **folder icon** to open that
location in Explorer. Encounter lists and charts use the extra vertical space. Section
headings use the same larger bold style as Better Mod Settings titles.

The square **camera/clipboard button** at the top right copies the native window
body, including the encounter details, fonts, class colours,
gauges, and selected player view. Window headers and action buttons are omitted,
along with the space reserved for them. The capture keeps the window's width and
grows vertically when needed to include every row, independently of scroll
position. It renders at twice the resolution in each direction, cropped to the
native body with no added border or surround. The body's rendered colours are
preserved. Scrollable chart clipping uses image-pixel coordinates during capture,
independently of the display's viewport scaling. The window, scroll position, and
display viewport are restored immediately afterward, including on capture failure.
Paste into a chat or image
editor; a short message confirms successful copying.

The **Rift Recap** has the same square camera/clipboard button at the top left of its
header, aligned with the close button. It copies both the gates and boss phases
into one image, with their names, durations, and full charts. Any open player
ability breakdown is preserved for that phase. Both phases include every row
regardless of scroll position. The snapshot uses the real recap window's styling
and side-by-side or stacked arrangement, at twice the resolution in each direction.
The recap shows the recorded rift start date/time, your character's name, and the
boss phase's Victory/Defeat result. Its snapshot includes a **Rift Recap** title
above that summary, styled like regular fight snapshots. The start time comes
from the gates phase when recorded, or the boss phase for a boss-only recording.
Only the body is captured; the window header and its buttons are omitted.
The header briefly confirms copying or displays an error.
The recap summary also shows your physical/magical/Raw shares across the recorded
gates and boss phases combined, weighted by damage dealt.

New local history files include `damageBreakdown` for every player and ability;
uploader JSON reports use `damage_breakdown`. Each has `physical`, `magical`, `raw`, and
`unclassified` buckets containing damage, percentage of that player/ability's total,
hit count, critical-hit count, and damage dealt by critical hits. The `affinities`
array records the same details for each raw game affinity and damage type. A skill
can contribute to multiple damage types. Unknown skill IDs still count
toward the player's split, and summons retain their actual damage type when credited
to their owner. Existing overall damage/DPS values use the same calculation as before.

The red **Delete log** button at the bottom right moves that fight's local chart
to the Windows Recycle Bin, then returns to the attempt list. If recycling is
unavailable, the action reports an error and retains the log. There is no
permanent-delete fallback. Uploader reports, other fights, and configuration are
unaffected. You can restore the chart from the Recycle Bin; restart Farever to
reindex a chart restored outside the game.

**Boss Dungeons** are boss-only instances. **Classic Dungeons** have a dungeon
monster-clearing phase before the boss. The game adds a `KillAllDungeonFoes`
objective when it populates an instance with clearing foes, so the collector
reads both personal and shared replicated objectives, including completed ones.
Without it, a populated `KillBoss` target identifies a boss-only dungeon.
It waits for initialized objectives instead of interpreting missing replication
as an arena. This works for new instances using the same native objective system;
the programming class names `Boss` and `Dungeon` do not determine the distinction.
**World Bosses** contains rift phases. Only actual boss encounters enter the
dungeon categories; ordinary combats and elites remain in **Other**.

Encounters are separated by the game's difficulty labels, such as **King Ratsar -
Normal**, **King Ratsar - Veteran**, and **King Ratsar - Heroic**. Older dungeon logs
whose difficulty cannot be recovered appear under **Unknown difficulty**.
New charts retain their activity ID, category, classification version, and difficulty.
The browser also uses these observed categories to classify older logs from the
same activity or an unambiguously identified boss, including after restarting the
game. Exact, unique game-provided boss names can recover the oldest imports when
their boss ID was omitted. Bosses observed in both dungeon formats need activity
metadata to distinguish them; similarly named monsters are never substring-matched.
Three confirmed legacy
encounters have explicit compatibility mappings: Ratsar and Chakram (internal
ID `Phrixes`) are boss dungeons; Robin Hoof is a classic dungeon. These mappings
also work when the old activity ID is missing. Old inferred labels without
reliable evidence remain in **Other** until their activity or boss is observed,
or a verified compatibility mapping is added. Charts made by the first history release omitted activity metadata;
the browser recovers it from the original export where that export still exists.
No old chart files are rewritten or deleted during reclassification.
Rift phase names can still identify old rift charts. Game-provided names replace
unit IDs where available. Skill labels read the game's `texts.name` directly,
following explicit text references and the game's child-skill reference cache.
Unnamed normal attack steps use **Base Attack**, **Base Attack 2**, and so on.
The recorded skill IDs and damage totals remain unchanged, so old logs gain the
display names without being recorded again. Removed definitions keep a readable
ID fallback.

History records boss attempts, both rift phases, and combats involving target
dummies. Dummy encounters appear as **Target dummy** under **Target Dummies**,
between **World Bosses** and **Other** in the category list. Previously saved dummy
fights also appear there without rewriting their logs. Dummies are identified
from the game's unit metadata rather than their names. Other unclassified combat
is not saved. A qualifying fight still in progress when you leave an area or
exit normally is also preserved. Completed rift phases
keep their separate **Rift - Gates** and **Rift - [boss name]** charts.

Completed rifts also save a combined **Rift Recap** under **World Bosses** in
Fight History and in `history/Rift Recap/`. Selecting a recap displays both phase
charts inside Fight History, with the same appearance and compact player/skill
breakdowns as the automatic popup. The charts fit side by side, or stack on
narrower screens. Snapshot and Delete log work here too; Back returns to the
same history page and filters.
Recaps save even with automatic recap popups or log uploads disabled. Each recap
contains its own gate and boss snapshots, so deleting a separate phase log does
not break it. The log list identifies the boss and shows combined personal DPS
over the sum of the recorded phase durations. Joining at the boss leaves the
gate panel empty rather than inventing earlier damage. Recaps are captured from
newly completed rifts; older, separate phase files are not guessed into pairs.

An ongoing fight continues while a living party member in the same instance is
still in combat, even if you die. Party damage and the encounter timer continue,
and being revived resumes the same chart. The fight ends when everyone leaves
combat or the party wipes. Players in other instances and dead teammates cannot
keep it open; party combat alone does not start a new fight while you are idle.

Chakram's opening health bar appears in the live meter with its own damage and
timer, including normal visibility while fighting. This temporary chart is never
saved or uploaded. New Chakram recordings begin with damage after **Surrendering
to Darkness** (phase 2), starting fresh without the opening bar's damage or time.
The later bridge and demon form stay in that same fight. A reset or wipe ends
the attempt; leaving the area preserves an unfinished chart only after the real
encounter starts. Previously saved logs remain as recorded.

Rift gate encounters begin only after the game's waiting objective completes.
Damage to warm-up mobs during the countdown appears in a temporary live chart,
with normal combat visibility and hiding after combat ends. It is never saved,
uploaded or included in the recap; the gate phase starts with fresh totals.
Remaining gate cleanup after the wave timer expires is still included. In the
recap's ability breakdown, each ability name sits above three columns:
**Damage %**, **Phys/Magic/Raw**, and **Damage**. The full history breakdown keeps
its additional statistics, and table headers stay fixed while the rows scroll.

**Lock or unlock window hotkey** controls movement of both the DPS Meter and
Fight History. Drag the Fight History title bar when unlocked; its position is
saved separately and kept on screen. **Show or hide meter hotkey** controls the
meter's visibility.

New history logs include `gameVersion`; uploaded reports include `game_version`.
Both record the running game's version from `Config.getVersion()`. Reopened
logs retain their original version, and older logs without it remain readable.

New logs save their outcome. Boss attempts require the boss's actual death;
defeating adds alone is not a victory. Ordinary fights require all observed foes
to die. Rift phases use their objective completion, so a boss clone's death does
not count as a victory. Wipes and unfinished encounters left behind are defeats.
Late death messages are included before the log is archived. Older logs without
outcome data show **Outcome unknown**; their skill kill counts do not reliably
identify boss victories. Outcomes also appear in clipboard snapshots.

Fight history and sent reports are kept indefinitely unless you explicitly remove
them. They survive game restarts and character changes. The former uploader `keep_days` option is ignored; no
age-based cleanup runs. Local history works even with log uploads disabled,
and ordinary or abandoned fights are never submitted as completed boss reports.
The first launch imports surviving reports from `logs/`, `logs/sent/`, and
`logs/rejected/` without submitting them again. Previously deleted reports
cannot be recovered. Older reports use their original encounter names and an
estimated start time derived from the recorded export time and duration.

Disk writes, history indexing, and chart reads run on the uploader worker.
Logs are organized by encounter and difficulty, for example
`history/Crabgantua - Heroic/<log>.json` and `history/Rift - Gates/<log>.json`.
Existing flat history logs move into these folders automatically without
rewriting their contents. Windows-invalid folder characters are replaced;
reserved names, trailing dots/spaces, and overly long names are handled too.
If a move fails, the original file remains readable and the next launch retries.
The temporary **Rift - Before gates** chart is still not saved. Uploaded report
phase identifiers and the `logs/` upload queue remain unchanged.
Only compact summaries are kept in its index; the browser requests one page
or one chart at a time. Back up `hlx/mods/dps-meter/history/` to preserve your
local charts when reinstalling the mod or moving to another computer.
