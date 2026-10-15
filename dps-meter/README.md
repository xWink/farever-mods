# DPS Meter

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-dps-meter.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=dps-meter&expanded=true)

An HLX combat meter with a movable, resizable native Farever window and boss-kill
uploads to [Fareverly](https://fareverly.com/).

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

The mod and its data are contained in `hlx/mods/dps-meter/`. Local fight charts
live in `history/<encounter>/`; submission payloads and retry states live in
`fareverly/`. Diagnostics are written to `uploader.log`. It rotates at 1 MiB and
keeps one previous file (`uploader.log.1`), so diagnostics use at most 2 MiB.
Oversized legacy diagnostics are removed at startup, on the background worker.
Diagnostics use local English explanations instead of copying server response
text. No external uploader application is required.

The included Windows x64 desktop plugin,
`hlx/plugins/dps-meter/dps_meter_desktop.hdll`, supports folder opening, Recycle Bin
deletion, image clipboard access, and Ready Check audio. Install this folder too
when updating manually, and restart Farever so it loads the updated plugin.
Installation preserves saved meter settings and existing logs. Older local export
files are imported into history once for compatibility, without uploading them.

## Highlights

- **Live party DPS:** Damage, DPS, and team contribution with class-colored bars and clickable skill breakdowns using game skill names and each skill's share of that player's damage.
- **Summon tracking:** Minion damage credited to its owner and the skill that summoned it.
- **Native, customizable window:** Move, resize, lock, and scroll the meter, with optional automatic hiding and a smooth fade. The **UI scale (%)** slider enlarges the whole meter from 100% to 200%. A large gold corner grip marks the unlocked state; dragging and resizing respect the selected scale.
- **Controller focus:** The live meter stays out of controller navigation so it does not take focus from the game's menu controls. Its buttons, charts, dragging, and resizing remain mouse-operated; full controller navigation is not implemented.
- **Rift tracking and recaps:** Separate gate and boss phases covering all players present, with both charts in one post-rift recap.
- **Fight history:** Save Boss Dungeons, Classic Dungeons, World Bosses, and **Target Dummies**; choose an attempt by date, character, party size, duration, and your DPS, then reopen its player and skill charts. Other unclassified combat is not saved; existing Other history remains available.
- **Kill notifications:** Optional boss kill totals with the previous fastest kill time. **Show unmastered Codex kills** displays progress through each enemy's final mastery requirement, including the finishing kill. **Show mastered Codex kills** displays subsequent kill totals. The target comes from the game's enemy-specific Codex thresholds, rather than the earlier XP reward milestone. Existing settings are preserved; unmastered notifications default to on and mastered notifications to off.
- **Party ready checks:** A movable party status popup, chat/button responses, a 60-second timeout, and an automatic leader countdown when everyone is ready.
- **Automatic log uploads:** Send eligible completed boss victories to [Fareverly](https://fareverly.com/) in the background, with no external application.
- **Better Mod Settings integration:** Customize display options and hotkeys, with settings and window placement saved between sessions.

## Player identity in logs

Each uploaded report's `players[]` entry includes `account_id` and `character_id`
as strings, or `null` when unavailable. Local history and rift recap phase records
preserve the same fields as `accountId` and `characterId`. Existing logs without
these fields still open; their identities remain unknown.

`account_id` comes from the replicated `st.Player.uid`, which the game initializes
from `HeroData.accountID`. It is available for observed party members. The existing
`uid` remains the spawned hero's network entity ID, used for combat attribution;
it must not be treated as a permanent account or character ID.

`character_id` comes from `GameApp.connectionInfo.heroID`, only for the actual local
hero. In the inspected client, `st.Player` does not serialize `heroData`, and
`st.FriendList.setFriendMeta` explicitly sets the friend's `heroId` to zero.
Remote character IDs therefore remain `null`; names, account IDs, and entity IDs
are never used as substitutes. A party member's own recording can provide that
member's persistent character ID. Consumers must not merge unknown characters
under a shared null ID or infer a character solely from its account/name.

To verify in game, have two party members install the same build and record the
same boss fight. Compare the JSON files in `hlx/mods/dps-meter/logs/` (including
`sent/` or `rejected/`), or the local files under `history/`. Each player should
have the same account ID in both recordings; their own recording should include
their character ID, while the other client's entry currently has a null character
ID. Repeat after reconnecting: the character ID should remain the same even if
`uid` changes. Switching to an alt should retain the account ID and change the
character ID. This check uses the normal saved logs and sends no extra chat messages.

## Detailed combat reports

**Record detailed combat history** is enabled by default under **Combat History**.
Open a saved fight, then choose **Detailed report**. The existing party, damage,
healing, and skill summaries remain available through **Back**. Older histories
still open, but cannot reconstruct events that were never recorded.

The detailed report records client-observed activity involving your character:

- Skill use and endings, direct hits, individual observed DoT ticks, critical and
  lethal results, incoming attacks, successful dodges/blocks, and deaths.
- Dodge and block **use**, even when no attack is avoided or blocked.
- Native skill proc availability, use, disappearance, and server charge increases.
- Sourced healing, including potions and skill healing, with the existing RPC/FX
  reconciliation. Ordinary passive/unattributed HP recovery is excluded from this
  timeline. Healing is output, including overhealing; estimated amounts are
  marked and missing amounts are left blank. No actual/effective-healing
  statistic is introduced.
- Shields applied to or by you, shield amount changes, buffs/debuffs applied,
  refreshed, stacked, extended, consumed, expired, or removed.
- Replicated HP losses, including losses without an attack notification. HP loss
  is a separate observation, never counted again as incoming attack damage.

Rows use game skill icons and names. Filter by event type and search
skills/targets/outcomes. Each page fits complete rows without scrolling. Clicking
a row expands its details into the next two rows' space. The second-last row uses
one row above and one below; the last row uses two above. Other events stay
visible; click the expanded row again to collapse it.
Skill-used rows include their resolved target and completed use duration when
recorded; animation endings are folded into the use rather than shown as extra
actions. Empty values are left blank, and empty columns are hidden. Internal
**HP observed** snapshots are omitted from the event table; actual HP losses and
deaths remain visible. Flask use/healing shows **Hess'tuss Flask** and the flask
icon; **Pilgrim's Stride** identifies only its separate movement-speed buff.
New item-use events capture the consumed item's name and icon, including
**Spark Cube**, while preserving the underlying skill ID. Older generic item-use
events cannot recover an item identity that was not recorded.

Graphs offer **Damage dealt**, **Damage taken**, **Healing given**, **Shields given**,
**Buff uptime**, and **Debuff uptime**. Numeric graphs show per-second rates within
their time buckets, including that unit in the hover readout. Buffs and
debuffs use the game's Debuff tag and have separate event filters. Hidden internal
status trackers remain recorded but are excluded from these two views. Uptime has
its own previous/next pages with skill icons and readable labels. Click a graph
to jump to the corresponding event page. Recording gaps break uptime intervals.
The graph sits above the event filter/search controls. Event paging, filtering,
and searching update only the table; the graph is retained until its metric,
fight, size, or font changes. Buff/debuff names, targets, and time labels use
larger text with stronger contrast.

Other players' effects are included when they involve you, including incoming
heals, shields, and buffs. This is a personal timeline: it does not record other
players' attacks on other targets or their skill-use/proc history. The existing
party summary reports remain available alongside it.

Timestamps are elapsed **client observation time**, displayed to milliseconds,
with sequence numbers to preserve ordering at equal times. A two-second lead-in
appears with negative timestamps to include initiating casts; it is excluded from
rate graphs. Delayed healing retains its first observation time. Each damage row
uses the amount on that native notification. `Hit #` is the game's hit counter,
not a multiplier or a count of damage amounts combined in the row. Incoming
damage and HP losses display as negative amounts. This does not reconstruct a
server simulation, infer a miss from silence, or guess which attack caused a
separate HP update. Charge increases can be recharges, resets, or corrections;
the report labels them simply **Charge increase**. Shield reductions likewise
do not claim confirmed absorption. Unavailable causes are omitted.

Recording appends primitive data to batches of at most 256 events. Disk writes,
JSON serialization, filtering, and graph calculations run on the background
worker; the UI creates only one page of event rows. Timestamping and recording
have a cost, so this is not a promise of zero overhead. There is no per-hit console
logging. Disable detailed recording without disabling the existing summaries.

Detailed data stays local in `history/<encounter>/<fight>.json.timeline`, paired
with the existing summary JSON. It is newline-delimited JSON: a versioned header
with initial state, then one event per line. These files are not included in Fareverly submissions. Deleting a fight recycles both files, with recovery backups if either
operation fails. Temporary `timeline-spool/` chunks are removed after a normal
session shutdown and successful archive saves. A background startup pass removes
abandoned chunks and interrupted chunk writes from previous sessions, then removes
empty stream directories. It preserves current-session streams, unrecognized files,
and saved history/timeline sidecars. This startup cleanup runs independently of
Automatic Log Deletion. Detailed reports follow the existing encounter-saving policy.

## Ready Check

Enabled by default under **DPS Meter > Ready Check > Enabled**. In a party, the
leader types **`rc`** in Local, All, or Group chat to open a ready check. Members
with this feature enabled see every party member's **READY / NOT READY** status;
the leader starts ready. Type **`r`** or **`nr`**, or click **Ready / Not Ready**,
to respond. Party members without the mod can still respond by typing in chat.

Recognized outgoing commands use **Group** chat so Local's distance limit cannot
hide them from distant party members. Incoming Local, All, and Group commands
are accepted; whispers, system messages, and outsiders are ignored. Commands
must be the entire message (case and surrounding whitespace are ignored).

The popup starts in the center of the screen. Drag its header at any time to
move it; its position is saved independently of the meter's lock setting.
It respects your normal cursor toggle: show the mouse to use its buttons or
drag it, and hide the mouse to control the camera while the check stays open.
The leader's **Cancel** button sends **`cancelrc`** and closes everyone's popup.
The top-right timer cancels the check after **60 seconds** if anyone is not ready.
Once everyone is ready, the popup closes immediately and every enabled client
plays the quest-completed sound once. 0.7 seconds after the final ready response,
the leader sends **5, 4, 3, 2, 1, GO** in Group chat, one second apart. The **5**
echo starts the supplied voice recording as one continuous clip; subsequent
numbers do not restart playback. **GO** plays the boom at 80% of its original volume.
**Disable countdown voiceover** mutes just the spoken numbers, while
**Disable countdown sound effects** mutes the ready cue and GO boom. Both options
are off by default and affect only your client. The existing mute preference is
retained for sound effects. The recordings are embedded in the mod and follow
the game's master/UI volume and focus mute. Their
Windows playback uses the default audio output device through the included desktop
plugin (Farever's compiled Heaps sound output is inactive).
This does not open chat,
change what you are typing, or take away movement control.

Leaving/changing parties, changing leader or membership, disabling the feature,
or disconnecting cancels the local check and any pending countdown. No combat
data is changed. A leader without the feature can start a check by typing `rc`,
but needs the feature enabled to send the automatic countdown.

## Healing meter

Click the crossed-axes/cross button next to Fight History to switch the live meter between
**damage/DPS** and **healing output/HPS**. The same toggle appears to the left of
Snapshot when reviewing a fight, including rift recaps. Each window remembers its
view until the game restarts. Press **F8** to swap each window's damage/healing view,
including Fight History and Rift Recap. Rebind **Switch damage/healing hotkey** in
the **General** settings category. The hotkey is ignored while typing or assigning
a keybinding. All meter, Fight History, and Rift Recap windows share the same damage/healing
selection. Clicking any mode button or using the hotkey switches all of them,
including windows opened afterward. Both kinds of data are always collected and saved;
switching views does not reset the encounter or change its damage statistics.

Healing output includes overhealing. Click a healer to view their abilities,
healing share, output, casts, hits, critical rate, and HPS. A **Team/Self** bar
splits each ability's output into healing others (green) and self-healing (yellow),
with the two percentages above it. Unattributed output is not labeled as either;
it stays neutral, or shows **—** if the whole split is unknown.
The history header shows the selected player's HPS, **Healing output**, and
**Healing received**. Received healing includes incoming self-heals and heals from
others, including overheal, plus observed unattributed recovery. Recap headers
sum incoming healing across the recorded phases. The meter does not display or
save actual/effective healing or overheal amounts: exact results and pre-heal HP
are not available for every party member's healing events.

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
and again for its exact notification. The correlation window is **120 ms**; updates
are processed at most ten times per second, so displayed totals can settle later
than 120 ms, especially when a later matching notification extends the wait.

An unmatched combat HP gain appears as **Regen / unattributed**, credited to the
recipient. This is observed recovery, not proof of regeneration, a known caster,
or a total including overheal. Spawn/revive initialization and out-of-combat
recovery are excluded from this bucket. No method here guarantees a complete
server combat log: effects outside client visibility and server-only scripted
heals can still be missing or unattributed.

New history records and uploader reports add a `healing` object per player with
`output`, hit/crit/cast counts, a `distribution` object (`team`, `self`,
`unattributed` output amounts), and a `skills` array containing the same split.
Each fight also stores incoming totals by recipient UID in `healingReceived`
(`healing_received` in uploader reports), including recipients with no output.
Older records without this data show **unavailable** for incoming totals and
**—** for the split; they cannot be reconstructed retroactively.
Evidence counts (`knownCritHits`,
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
The home page shows **Recent Fights** above **Choose a category**: the three newest
saved reports across all categories and characters, independent of folder filters.
These use the same attempt rows and **Delete log** buttons as the encounter folders.
Opening a recent fight gives access to its normal chart and detailed report;
**Back** from its chart returns to the home page. Deleting one refreshes the list
with the next newest report. Short archives show only the reports available.

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
to the Windows Recycle Bin, then returns to the attempt list (or the home page
for a report opened from **Recent Fights**). If recycling is
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

The meter starts unlocked on first launch so you can immediately move and resize
it. Existing saved lock settings are preserved.

**Lock or unlock window hotkey** controls movement of both the DPS Meter and
Fight History. Drag the Fight History title bar when unlocked; its position is
saved separately and kept on screen. **Show or hide meter hotkey** controls the
meter's visibility. All four hotkeys support one Ctrl, Shift, or Alt modifier
with Farever-supported keys. Update Better Mod Settings to assign combinations.
Existing single-key bindings carry over, and modified shortcuts do not also
activate their plain-key counterparts.

Local logs and Fareverly submissions include `gameVersion`, recorded from
`Config.getVersion()`. Reopened
logs retain their original version, and older logs without it remain readable.

New logs save their outcome. Boss attempts require the boss's actual death;
defeating adds alone is not a victory. Ordinary fights require all observed foes
to die. Rift phases use their objective completion, so a boss clone's death does
not count as a victory. Wipes and unfinished encounters left behind are defeats.
Late death messages are included before the log is archived. Older logs without
outcome data show **Outcome unknown**; their skill kill counts do not reliably
identify boss victories. Outcomes also appear in clipboard snapshots.

**Automatic Log Deletion** is enabled by default and deletes local logs older than
**12 calendar months**. Its age slider runs from **1 to 24 months**, in one-month
steps. Disable the option to retain logs indefinitely. Cleanup runs on the background
worker at startup and every 24 hours thereafter. Changing settings never triggers
cleanup or resets that schedule; the next scheduled pass uses the latest settings.
Age is based on
the fight's recorded date, with the day clamped for shorter months. Expired history
JSON, detailed timelines, recovery drafts, and local Fareverly payload/retry files
are permanently deleted. Published reports are unaffected. Explicit **Delete log**
actions still use the Recycle Bin.

The **Upload combat logs to Fareverly** setting controls automatic submissions.
Connect a Fareverly account through Steam in **General** first. Combat statistics become public when a ranked
report is retained. Only newly
recorded, completed boss victories are considered; existing fight history is never
automatically submitted. The individual `fight_*.json` history snapshot preserves
its original ID and full-precision identity strings. Combined rift recaps, gate
phases, practice, defeats, and incomplete or inconsistent recordings remain local.
Dungeon logs require the complete party and recorded difficulty. Rifts preserve
their actual party size and use `-1` when difficulty is inapplicable.

Fareverly's supported encounter IDs and availability are fetched and cached for
the session when a submission is pending. Requests run on the background worker,
using certificate-verified HTTPS, with a 5 MiB body limit and the connected
Fareverly key in its Authorization header. Exact submitted JSON and retry state are stored in
`hlx/mods/dps-meter/fareverly/`. Failed submissions remain local until their
configured retention age expires. Turning off uploads pauses pending work and
stops new submissions from being queued; local history still works.

Event filters include **source and target dropdowns** that combine
with event type and search. Both use recorded actor IDs, with distinct labels for
repeated names. Changing event filters leaves the full-fight graph intact.

Saved logs with only one recorded player open directly to that player's skill
breakdown. Clicking the breakdown returns to the player chart and stays there.
Switching between damage and healing preserves the selected player.

Rift gate counts come from the replicated **CloseGates** objective, appear in the
live gate phase and both recap views, and survive log saving. Older logs with no
recorded count leave it unspecified.

The **Fareverly logo button**, immediately to the right of the snapshot button,
opens Fareverly's analyzer and automatically loads the selected local JSON as a
local report preview, including practice fights and defeats. No account or upload
toggle is needed. Combined recaps are unsupported by Fareverly and disable this
button. It never submits to rankings, retries ranked submissions, looks up a ranked
report, or creates a share link. A spinner and disabled button cover the import,
with a short cooldown to prevent repeated tabs.

The handoff runs off the game thread, binds only `127.0.0.1`, and serves one
selected JSON (up to 5 MiB) through a random one-use token. Only Fareverly's origin
is accepted. It closes after delivery or 90 seconds; no file paths or API keys
are exposed. The browser removes the temporary fragment before importing, and
responses are never cached. Some browsers ask once for local-connection
permission. If denied or expired, allow the connection and click the button again.
Browser activation uses Windows ShellExecute directly, with no terminal process.

### Steam sign-in

The **Fareverly** category follows **General** and contains **Upload combat logs
to Fareverly**, the secret **Fareverly API key** textbox, and **Generate API key**.
Uploading requires an API key. The field is empty by default and its eye starts
closed each time Mod Settings opens.

**Generate API key** handles initial signup and replacement of a lost, expired,
or exposed key using Steam sign-in in your normal browser. The mod never asks
for a Steam password. The temporary dialog shows only the code to match, with
one Cancel sign-in button. Cancelling closes it without another popup. A saved
key refreshes the open BMS field automatically.

Device authorization uses a Windows cryptographically secure 32-byte verifier
and S256 PKCE. Polling runs on a separate worker at least five seconds apart,
respects Retry-After, stops after ten minutes, and bounds transient retries.
Only one flow may run across mods using the shared Fareverly helper. The old key
remains valid until an approved rotation completes. Returned credentials must
match the local Farever account and grant upload/account-read scopes. The API
checks existing account links during token exchange. If the initial action does
not match the server's link state, the mod starts one new approval with the
correct action and opens its new browser code, rather than ending with an
"already linked" error. Approve that new code to finish generating the key.

The API key is the only Fareverly credential setting. Its descriptor uses both
`isSecret: true` and `isCommon: true`; its `fareverlyApiKey` value lives in
`hlx/config/common/config.json` so other Fareverly mods can use it. No account ID,
Steam ID, expiry, or verification fingerprint is saved alongside it. The server
authenticates the key and checks expiry, scope, and the log's uploader account.
The mod reads the current game account when needed for sign-in or verification.

Generate API key uses the existing BMS button action event. Saving a returned key
preserves other common fields and refuses to overwrite a key edited while
sign-in was pending. BMS and DPS Meter use the common config-change notification.
Pasted keys save to the same common file. Clearing the field stops use of that
key; masking affects the display only.

There is no credential migration or fallback: neither the former DPS Meter
API-key setting nor the rejected credential file is read or imported. Generate
a new key for the common setting. Config files are not included in installation
ZIPs.

Ranked uploads run only through the background uploader. Requests use bounded
retries (at most four attempts) for transient failures, respecting Retry-After
and persisted cooldowns. Exhausted attempts retain their local files; settings
have no manual retry control, and opening history never queues an upload. A 401
pauses that key across restarts; a 403 records an account-mismatch diagnostic.
Generate API key replaces an invalid key and resumes pending submissions. No
authentication result deletes a local log.
Server bodies, device codes, PKCE verifiers, keys, and Authorization headers are
never written to diagnostics. Fixtures are used only in offline tests.


The first launch imports surviving reports from `logs/`, `logs/sent/`, and
`logs/rejected/` without submitting them again. Previously deleted reports
cannot be recovered. Older reports retain their original encounter names.
