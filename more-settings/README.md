# More Settings

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-more-settings.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=more-settings%2Fv&expanded=true)

Client settings for **Farever**: combat controls, chat filtering, boss health numbers, optional queue optimizations, a native Barbershop button, and separate ally presentation controls for rifts, dungeons, and the overworld. Previously called **More Audio Settings**.

## Settings

Open **More Settings** in [Better Mod Settings](../better-mod-settings/).

| Category | Controls | Defaults |
| --- | --- | --- |
| General | Disable profanity filter; Show boss health; Performance improvements; Performance diagnostics; Wait for party to enter dungeon; Leave dungeon button; Hide UI hotkey | Profanity option on (imports previous preference); boss health, performance improvements and diagnostics off; waiting for party and leave dungeon button on; Hide UI defaults to F2 |
| Combat | Fancy damage numbers; Disable damage numbers; Keep Crabgantua rockfall warnings visible; Hide allied minion HP bars | Fancy numbers, damage hiding and minion bar hiding off; Crabgantua warnings on |
| Social | Hide friend connection notifications; Enable missing slash commands; Sending message closes chat; Enable friend notes; Rebind social interact hotkey; Social interact hotkey | Connection filtering and social rebind off; social key unassigned; commands, close after sending, and notes on |
| Rift Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |
| Dungeon Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |
| Overworld Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |

**Combat** appears directly below **General** and contains damage-number controls, **Keep Crabgantua rockfall warnings visible**, and **Hide allied minion HP bars**. Quick cast and target-lock camera controls are available in **Fix Target Lock**.

**Keep Crabgantua rockfall warnings visible** renders the original brown swirl after the water with depth testing disabled. The animated warning's colour passes move to the overlay stage, including colour decals drawn before tone mapping. Its native appearance, shape, animation, and timing are preserved. Render state is applied once per warning, with no per-frame material traversal or whole-scene scan. Turning the option off restores original passes; effect removal, pooling, and leaving the game also restore them. The option is on by default.

**Fancy damage numbers** adds a 1 px black outline to damage and healing numbers. Normal physical damage uses an orange gradient and normal magic damage uses a blue gradient. Critical hits always use three colours, with the middle stop halfway down the number:

| Damage type | Top | Middle (crit only) | Bottom |
| --- | --- | --- | --- |
| Physical | `#FFCB6D` | — | `#F04424` |
| Physical crit | `#FFCB6D` | `#F04424` | `#FF0000` |
| Magical | `#BCC2FF` | — | `#5963C4` |
| Magical crit | `#EF8DE8` | `#C08DEF` | `#5963C4` |
| Raw | `#FFFFFF` | — | `#B8B8B8` |
| Raw crit | `#F5E149` | `#FFFFFF` | `#EBEBEB` |
| Heal | `#B8FF92` | — | `#238C45` |
| Critical heal | `#FFD966` | `#B8FF92` | `#238C45` |

The option remains off by default and preserves your existing Fancy damage numbers preference. All palettes are fixed; the former Pink crits, Exclamation mark crits, Three-colour crit gradients, and physical/magical/Raw colour inputs are removed and their saved values no longer affect styling. Critical hits keep native number formatting, with no added exclamation mark. Healing skills can crit in the current game; the healing palette uses the native critical flag. Both healing received by your character (the `+500` incoming-healing feed) and floating heals on other targets use these palettes. Damage/healing values, fonts, visibility rules, and animations keep their native behavior.

**Fancy damage numbers** uses fixed palettes that apply to newly displayed numbers immediately. Raw uses its own palette regardless of the skill's physical or magical classification, retains the black outline, and has no native text shadow.

Gradients span the placed glyph geometry, excluding the formatted text's blank line space and the surrounding border padding. Their endpoints stay aligned with the digits as font size or rendering resolution changes; a three-colour gradient reaches its middle colour halfway between the glyph edges.

**Disable damage numbers**, immediately after Fancy damage numbers, suppresses newly created floating damage and healing text, including incoming damage and healing rows in the effects feed. It takes priority over fancy styling for both. Combat notifications, damage/healing processing and DPS Meter recording continue normally.

**Hide allied minion HP bars**, the last Combat option, hides the overhead health/shield bars of allied summoned units. Your own summons retain their native health bars. Enemy health bars, player/party bars and boss panels remain native. Changing the setting restores the most recent native visibility; ownership and hostility changes are checked on the parent widget so a hidden bar can become visible again.

**Barbershop** is a native button on your character’s appearance page, above the glove appearance slot and to the right of the model’s head, with matching 15-unit top and right insets. The top inset matches the native Character button’s bottom inset. It needs no ImGui dependency. Click it to edit your body type, skin and eye colors, eyebrows, facial shapes, hair, facial hair, and hair color. The window includes a rotatable character preview with equipment hidden, Body/Face/Hair tabs, and the same player-available choices as character creation. **Save** applies the appearance through the game's normal replicated character property and save path. **Cancel**, the close button, or Escape discards the private preview. Leaving the world or changing characters also discards it.

**Social**, directly below **Combat**, contains the following options. Slash commands, closing chat after sending, and friend notes are enabled by default; hiding connection notifications is off. Existing saved preferences are preserved:

- **Rebind social interact hotkey** and **Social interact hotkey** separate opening another player's interaction menu from the regular Interact button. Enable the checkbox, assign a key, and hold it while looking at a player. Rebinding is off by default and the key is initially unassigned. The on-screen player hint and hold progress follow the selected key; dead allies retain the regular revive hint. Loot, NPCs, reviving, gamepad controls, combat restrictions, and typing/input blocking retain native behavior. Disabling the checkbox restores the original player-interaction control without changing the game's saved bindings.
- **Hide friend connection notifications** hides friends' connected/disconnected system messages while their online status continues updating.
- **Enable missing slash commands** adds `/invite <player>`, `/leave`, and `/w <player> [message]`. A bare `/w <player>` opens the whisper channel; including a message sends it. Names match exactly, ignoring case, from the current area, party, friends, or recent chat. Quote names containing spaces. Unknown or ambiguous names produce a chat error; failed whispers never fall through into public chat. Invites and leaving use the game's normal permission checks.
- **Sending message closes chat** closes the textbox after Enter submits a message, returning control of the character. Selecting a whisper recipient without a message keeps the textbox open.
- **Enable friend notes** adds **Add note** after **Send message** in a friend's gear menu (**Edit note** when a note exists). Notes are limited to **30 characters**, displayed after a hyphen beside the name in smaller text, and saved by your account and the friend's account in `hlx/config/more-settings/friend-notes.json`. They follow character changes. Press Enter or click Save to save without opening chat. Save an empty note to remove it; Cancel leaves it unchanged. Names and notes use the available header space, reserving room only for controls that overlap that row. Text is shortened only when it does not fit. Notes do not add hover tooltips or row highlighting. Party labels such as **(Leader)** remain before the note without overlapping it. Disabling the setting hides notes without deleting them. Notes are local and are never sent to other players.

The profanity option applies to displayed player text and keeps HTML escaping. Character-name validation is unchanged.

**Show boss health** adds the boss's current HP before its percentage in the top-of-screen boss bar: `123,456 (100%)`. It uses the actual Health attribute, rounded down to a whole number like the game's numeric health display, and updates throughout the fight. The native percentage and shield information are preserved. Toggle it at any time under **General**; disabling it restores the native label. If the native resource-display option already shows numeric HP, that label stays unchanged.

**Performance improvements** is an optional checkbox under **General**, off by default. It can be changed while playing. It addresses specific findings from the static performance review:

- Large main-thread worker queues use an index while executing jobs and compact the remaining array once per servicing pass, avoiding a full array shift for every job. Small queues keep the native path. Job order, newly submitted jobs, loading/gameplay budgets, and threaded-work tracking are preserved. Jobs still run to completion on their original thread; one expensive job can still cause a hitch.
- The incoming-effects feed removes its oldest damage/healing rows when needed to make room within a 32-row target. Pending display times are brought forward so a sustained burst cannot keep extending the same delayed numeric tail. Combat transitions, game-beat messages, and other text notifications are retained, even when that requires exceeding the target. This affects the HUD's recent numeric feed only; damage, healing, floating combat numbers, and DPS Meter logs continue normally.
- Terrain normal/height textures reuse their last native composition while the camera neighborhood, chunks, buffer bindings, source textures, and destination resources remain unchanged. This avoids repeated clears/copies and temporary rendering-object creation on reusable passes. Native chunk lookups and renderer bindings still run; pixel refreshes, arriving/departing chunks, resource recreation, context loss, and camera neighborhood changes force the original rebuild. Source textures retain the native recent-use lifetime. Cache references are bounded and released on terrain disposal or when the option is disabled.
- During gameplay, optional DX12 pipeline-cache replay is spread across quiet frames instead of building all saved variants for a newly compiled shader at once. It prepares at most one saved variant per update after two seconds outside combat without a slow frame, and postpones work when native graphics locks are busy. Background and loading-screen warm-up remain native. Required draw pipelines and first-use shader compilation still run normally; individual compilation stalls remain possible.
- Initial equipment, hair, and face loading for other players is split into component jobs on the existing main-thread worker queue. Its frame budget can be checked between components. The base model and animation reload remain native; readiness callbacks wait for the components. Local-player models, monsters, NPCs, existing-model rebuilds and appearance-editor previews keep native behavior. Stale work is cancelled when a model is replaced, removed or its game session ends.
- Fence-safe DX12 resource-release queues are transferred to a dedicated cleanup worker after native command resets and descriptor retirement finish, including single-resource queues. Pending references are capped at 65,536 to accommodate observed gameplay cleanup bursts, with a DXGI memory-budget guard (at least 512 MiB and 10% free). Pressure, loading, disabling the option, world exit or driver replacement/reset waits for accepted work to finish; pressure also leaves the current queue with native cleanup. Descriptors, command resets and GPU waits remain native. Slow resource destruction no longer directly occupies the game thread on the offloaded path, but pressure fallback and shared graphics-driver waits can still stall gameplay.

Disabling the option restores native handling for new work and discards optional pipeline preparation. Accepted character builds finish so their models cannot be stranded; already removed HUD rows are not recreated. Automated tests validate scheduling, reuse and lifecycle behavior, not in-game frame-time gains. Individual model/prefab loads, terrain jobs, entity initialization and other GPU pass costs still need profiling or engine changes. The option does not reduce graphics quality or skip world/network updates.

Pipeline preparation uses the game's existing PSO cache and native pipeline builder; this mod does not add or replace disk persistence or move graphics/scene mutation to another thread. [Shader Persistent Cache](https://github.com/laymain/farever-mods/tree/main/shader-persistent-cache) is a separate persistence mod. Compatibility and frame times with that mod installed still require in-game testing.

**Performance diagnostics** is a separate, opt-in General setting for investigating freezes. It works with **Performance improvements** on or off, and each record includes that choice. Enable it, reproduce a freeze, then remain out of combat with the game focused for a few seconds. Look for `[More Settings] Freeze metrics v5` in the mod log. Allow up to about 35 seconds to drain a full buffer before closing the game or disabling diagnostics.

It records gameplay frames or gaps of at least 500 ms using a preallocated buffer of the latest 32 records. No per-hit/per-draw logging, stack capture, memory dump or diagnostic disk output runs during combat. Loading, unfocused windows and the initial two seconds of gameplay are excluded. Output waits for two seconds of quiet gameplay outside combat and is limited to one record per second. The buffer is discarded when diagnostics are disabled or the process exits; world changes retain captured records until the next quiet gameplay period.

Records include frame-body time, the gap since the previous frame, game-update/render/presentation times, worker jobs, character loading, staged character components, shader-source loading/compilation, pipeline-cache replay, graphics resource cleanup and DX12 frame waits. Version 2 additionally times frame submission (`flush-frame`), pipeline-cache saving (`pso-save`), next-frame preparation/resource cleanup (`begin-frame`), DLSS frame-generation state checks/mode changes, and driver resets. The native cache save includes locking, sorting, serialization and disk I/O when dirty and saving is allowed. A long `present` with a short `frame-wait` does not exclude a stall in these other steps or the platform Present call.

Version 3 splits `begin-frame` into initial command reset (`frame-setup`), buffer allocator reset (`buffer-reset`), copy-command reset and queued resource/descriptor recycling (`frame-recycle`), query readback (`frame-queries`), and the remaining render-target/descriptor/DLSS setup (`frame-tail`). `buffer-trims` counts reset calls that requested forced buffer trimming; it is not a resource count or memory measurement. These checkpoints leave native rendering and cleanup behavior unchanged. Missing, unexpected or recursive checkpoint sequences mark the record `incomplete=true`.

Timings are inclusive wall time: nested values must not be added together. `outside-phases` excludes the union of update/render/presentation, while `gap` covers time between the measured loops. Neither identifies a cause on its own. Scope totals cover all calls within the frame, so a function called from both rendering and presentation must not be subtracted from presentation alone. GC, operating-system scheduling and driver waits can inflate the enclosing measurement; graphics resource cleanup is not HashLink GC, and presentation timing is not GPU execution timing.

Version 4 includes cleanup outcomes in the same slow-frame record: whether the optimization was active or unavailable, how many references were observed/staged/submitted, the largest observed worker backlog, the latest existing DXGI memory sample, and whether memory pressure, unknown memory information, the queue cap or an error prevented offloading. Separate scopes time the cleanup callback, memory query, worker join and batch publication. `recycle-native` measures the remainder of the existing recycling section after the callback returns; it includes native copy-command resets, any remaining resource releases and descriptor retirement. It does not identify an individual native call or prove driver contention. Outcomes aggregate across calls in the captured frame, and absent samples are marked unknown rather than reusing earlier frames. Memory samples use the existing safety query; no extra DXGI queries or per-resource hooks are added.

Version 5 also separates engine begin/end, 3D scenes, 2D/UI scenes, renderer processing, PBR setup/finish, lighting, DLSS rendering and reserved-memory maintenance. `pipeline-create` times actual graphics-pipeline construction (including its native driver call), separately from shader-source compilation and optional cached-pipeline replay. Background pipeline construction is excluded; this does not measure GPU execution or time waiting for a pipeline lock before entering the construction method.

`render-stages` lists the four largest accumulated intervals between the game's existing renderer markers, including `sync`, `emit`, terrain, characters and water. They describe work until the next marker, not necessarily one isolated draw pass. Nested scenes pause the parent interval. `observed=0` means no completed stages were recorded; `dropped` reports bounded-storage/nesting overflow. Unmarked renderer implementations remain visible under the enclosing scene/renderer timers.

`render-alloc` samples existing HashLink counters at the start/end of each outer engine render. It reports allocated KiB, allocation count, and the latest managed heap size in MiB. These counters include other threads and diagnostic dispatch allocations; they are not live-object size, VRAM, or GC duration/count. No GC flags, collection timing or thresholds are changed. Absent samples are `unknown`. This adds no memory dump, per-allocation hook, per-draw hook, or diagnostic output during combat.

The timing buffer reuses numeric arrays and records during collection; the HLX hook dispatcher and native context lookups still have overhead. Automated tests cover timing, nesting, bounded storage, deferred/rate-limited reporting, loading/focus gating, exception recovery and background-thread exclusion. Actual overhead and freeze attribution must be checked in game. `graphics-cleanup` times the native `cleanTextures` method; earlier diagnostic builds tried the unhookable `garbage` callback field, producing startup lookup warnings and missing that measurement.

**Wait for party to enter dungeon** appears after Performance diagnostics under
**General** and is enabled by default, including for existing installations.
When you own a dungeon or rift entry lobby, Start stays disabled and reads
**Waiting for party members** until every party member has joined that same
entry menu and is ready. Solo entry, teammates' Ready buttons, countdown
cancellation, and the game's difficulty/access checks retain their normal behavior.
Toggling the option takes effect while the menu is open. This protects starts
made by the player running the mod; it does not control another player's client.

**Leave dungeon button** is enabled by default under **General**. It keeps the
existing Leave button visible while you are in a dungeon and out of combat,
including when the dungeon has an exit portal. The button hides during combat.
Disabling the option restores the game's normal visibility rules on the next HUD
update. Its normal leave action is unchanged; rifts and overworld UI are unaffected.

Targets the September 30 Live client with HLX Core 0.0.8 or newer.
Fast-travel music and unfocused-volume controls now belong to the game’s native settings. More Settings no longer changes those volumes or ships an audio plugin.

**Hide UI hotkey** rebinds the game's existing UI visibility shortcut. Choose a key under **General**; the default is **F2**. The selected key replaces the original keyboard binding and retains the game's normal hide/show behavior and input restrictions. Typing in chat or another text field does not hide the UI. Update Better Mod Settings too: its key-capture guard prevents assigning a shortcut from hiding the settings window. Bindings use one key; Escape cancels capture.

**Hide ally attacks** hides the visuals and sounds of friendly players' damaging or harmful abilities with no beneficial component. **Hide ally buffs** covers healing, shields, beneficial statuses, and utility abilities. Mixed damage/support abilities belong to the buffs category so attack hiding preserves useful support effects. Classification follows native skill data and referenced subskills/statuses.

**Hide allies** hides friendly player models and equipment independently of their abilities. Names and other UI remain visible. Your own model, abilities, summons' effects, and buffs you cast on other players remain visible. Enemy and duel/PvP opponent effects remain visible. Other players' buffs applied to you follow the caster's filter.

Rifts take precedence over dungeons; dungeon instances (including boss instances) use Dungeon Effects; World maps use Overworld Effects. Unknown locations are left visible. Visibility options are client presentation changes: skills, damage, healing, targeting, animation callbacks, and network state continue normally.

## Installation and upgrade

**Required:** HLX Core, [Better Mod Settings](https://www.nexusmods.com/farever/mods/10), and [Mod Update Alerts](https://www.nexusmods.com/farever/mods/17). A missing dependency shows a desktop error naming what to install and closes Farever before this mod starts.

Install the **complete archive**, including the `implementation/` subfolder. Missing or mismatched implementation files also stop startup with a reinstall message.

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core) and [Better Mod Settings](../better-mod-settings/).
2. Close Farever. Remove the old **binary and settings descriptor** from `hlx/mods/more-audio-settings/` (or `hlx/mods/mute-unfocused/`). Keep old configuration files for migration.
3. If the standalone Disable Profanity Filter mod is installed, remove its binary and settings descriptor as well so this setting has one owner. Keep its configuration file.
4. Install `farever-more-settings.zip` with Vortex, or extract it into the Farever game directory. Extract the **whole archive**: it contains `hlx/mods/more-settings/more-settings.hl`, its `configFormats.json`, and the `implementation/` subfolder. No separate More Settings audio plugin is needed.
5. Relaunch Farever.

Settings live at `hlx/config/more-settings/config.json`. On first launch, the mod imports the previous native or mod-local configuration from `more-audio-settings`, then `mute-unfocused` if needed. Existing More Settings configuration takes priority. Old files remain intact as backups. Legacy audio fields are no longer used; other saved preferences are preserved.

The GitHub Actions artifact is **farever-more-settings**. Release ZIPs are **farever-more-settings.zip**; release tags use **more-settings/vX.Y.Z**.

## Build and verification

Requires Haxe 4.3.7 and HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd more-settings
haxe test.hxml
haxe compile.hxml
```

Output: `build/more-settings/more-settings.hl` and `build/more-settings/implementation/more-settings.hl`. Package both binaries and `configFormats.json` under `hlx/mods/more-settings/`.

Regression tests exercise UI controls, minion bar visibility/restoration, Barbershop ownership and layout, boss health formatting, region/ability policies, appearance isolation, damage styling, worker ordering/budgets, pipeline lifecycle and terrain reuse with simulated native adapters. CI runs interpreter and HashLink checks before compiling and packaging. Actual rendering and frame-time gains still require in-game multiplayer testing.

Model membership and adoption of existing effects refresh at most five times per second. Native member lookup and skill classification are cached; disabled filters avoid entity scans. Rendering hooks never skip skill execution or character animation updates.
