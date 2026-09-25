# More Settings

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-more-settings.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=more-settings%2Fv&expanded=true)

Client settings for **Farever**: chat filtering, boss health numbers, optional queue optimizations, temporary audio levels, and separate ally presentation controls for rifts, dungeons, and the overworld. Previously called **More Audio Settings**.

## Settings

Open **More Settings** in [Better Mod Settings](../better-mod-settings/).

| Category | Controls | Defaults |
| --- | --- | --- |
| General | Disable profanity filter; Show boss health; Performance Optimization; Hide UI hotkey | Profanity option on (imports previous preference); boss health and performance optimization off; Hide UI defaults to F2 |
| Unfocused Volume | Adjust unfocused volume; Unfocused volume % | On; 0% |
| Fast Travel Music | Adjust fast travel music volume; Fast travel music volume % | Off; 0% |
| Rift Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |
| Dungeon Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |
| Overworld Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |

The profanity option applies to displayed player text and keeps HTML escaping. Character-name validation is unchanged.

**Show boss health** adds the boss's current HP before its percentage in the top-of-screen boss bar: `123,456 (100%)`. It uses the actual Health attribute, rounded down to a whole number like the game's numeric health display, and updates throughout the fight. The native percentage and shield information are preserved. Toggle it at any time under **General**; disabling it restores the native label. If the new/PTR client's resource-display option already shows numeric HP, that label stays unchanged.

**Performance Optimization** is an optional checkbox under **General**, off by default. It can be changed while playing. This first implementation addresses two specific findings from the static performance review:

- Large main-thread worker queues use an index while executing jobs and compact the remaining array once per servicing pass, avoiding a full array shift for every job. Small queues keep the native path. Job order, newly submitted jobs, loading/gameplay budgets, and threaded-work tracking are preserved. Jobs still run to completion on their original thread; one expensive job can still cause a hitch.
- The incoming-effects feed removes its oldest damage/healing rows when needed to make room within a 32-row target. Pending display times are brought forward so a sustained burst cannot keep extending the same delayed numeric tail. Combat transitions, game-beat messages, and other text notifications are retained, even when that requires exceeding the target. This affects the HUD's recent numeric feed only; damage, healing, floating combat numbers, and DPS Meter logs continue normally.

Disabling the option restores native handling for subsequent work and feed entries; already removed HUD rows are not recreated. These routines were checked in both the live and PTR clients. No FPS improvement has been measured in-game. This setting does not claim to fix every risk in the report: terrain job subdivision/composition caching, shader/pipeline prewarming, entity initialization recovery, widget pooling, map construction, and GPU pass costs need further profiling or engine changes. It does not reduce graphics quality or skip world/network updates.

The same build supports the live and new/PTR clients (use HLX Core 0.0.8 or newer
on PTR). Hit/heal effect attribution accepts both client skill-field layouts.
When **Adjust unfocused volume** is enabled, its level takes precedence over the
new client's native unfocused mute without changing that saved game preference.
Disabling the adjustment restores native audio behavior.

**Hide UI hotkey** rebinds the game's existing UI visibility shortcut. Choose a key under **General**; the default is **F2**. The selected key replaces the original keyboard binding and retains the game's normal hide/show behavior and input restrictions. Typing in chat or another text field does not hide the UI. Update Better Mod Settings too: its key-capture guard prevents assigning a shortcut from hiding the settings window. Bindings use one key; Escape cancels capture.

The unfocused setting temporarily limits Farever's master volume and restores it on focus, including any master-volume change made in the game's options. It never raises a quieter master setting.

The fast-travel slider adjusts **only your obelisk travel music event** (`Hero_FlyToObelisk`). It leaves other music, ambience, sound effects, and all shared volume controls unchanged. 0% mutes that track; 100% keeps its normal level under your existing music/master settings. Slider changes apply during a trip, and disabling the option restores the track's original gain. Unfocused volume works independently, so it can still quiet the whole game when you alt-tab during travel. Existing fast-travel preferences are preserved.

**Hide ally attacks** hides the visuals and sounds of friendly players' damaging or harmful abilities with no beneficial component. **Hide ally buffs** covers healing, shields, beneficial statuses, and utility abilities. Mixed damage/support abilities belong to the buffs category so attack hiding preserves useful support effects. Classification follows native skill data and referenced subskills/statuses.

**Hide allies** hides friendly player models and equipment independently of their abilities. Names and other UI remain visible. Your own model, abilities, summons' effects, and buffs you cast on other players remain visible. Enemy and duel/PvP opponent effects remain visible. Other players' buffs applied to you follow the caster's filter.

Rifts take precedence over dungeons; dungeon instances (including boss instances) use Dungeon Effects; World maps use Overworld Effects. Unknown locations are left visible. Visibility options are client presentation changes: skills, damage, healing, targeting, animation callbacks, and network state continue normally.

## Installation and upgrade

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core) and [Better Mod Settings](../better-mod-settings/).
2. Close Farever. Remove the old **binary and settings descriptor** from `hlx/mods/more-audio-settings/` (or `hlx/mods/mute-unfocused/`). Keep old configuration files for migration.
3. If the standalone Disable Profanity Filter mod is installed, remove its binary and settings descriptor as well so this setting has one owner. Keep its configuration file.
4. Install `farever-more-settings.zip` with Vortex, or extract it into the Farever game directory. Extract the **whole archive**: it contains `hlx/mods/more-settings/more-settings.hl`, its `configFormats.json`, and `hlx/plugins/more-settings/more_settings_audio.hdll` for individual music-event volume control.
5. Relaunch Farever.

Settings live at `hlx/config/more-settings/config.json`. On first launch, the mod imports the previous native or mod-local configuration from `more-audio-settings`, then `mute-unfocused` if needed. Existing More Settings configuration takes priority. Old files remain intact as backups. The former `enabled` setting migrates to `adjustUnfocusedVolume`.

The GitHub Actions artifact is **farever-more-settings**. Release ZIPs are **farever-more-settings.zip**; release tags use **more-settings/vX.Y.Z**.

## Build and verification

Requires Haxe 4.3.7 and HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd more-settings
haxe test.hxml
haxe compile.hxml
```

Output: `build/more-settings/more-settings.hl`. For a complete install, also build the Windows x64 audio plugin with MinGW (`gcc-mingw-w64-x86-64` on Ubuntu):

```sh
bash native/build.sh
cc -std=c11 -Wall -Wextra -Werror tests/event_volume_test.c -o build/event-volume-test
build/event-volume-test
```

The plugin output is `build/native/more_settings_audio.hdll`; install it in `hlx/plugins/more-settings/`. It resolves the public FMOD event-volume API from the game's loaded `fmodstudio.dll`; no game or FMOD binaries are bundled. If the plugin is missing or unavailable, an audio error is logged and the mod never falls back to changing a global volume for travel.

Regression tests exercise the production UI binding adapter, boss health formatting and update callbacks, volume controller, region/ability policy, classifier, presentation tracker, worker queue ordering/budgets/error recovery, and effects-feed overload behavior with a simulated native adapter. CI requires those tests plus native bridge tests before compiling and packaging both binaries. Native API and bytecode inspection supplements these tests; actual rendering/audio and performance still require in-game multiplayer testing after game updates.

The mod avoids repeating FMOD writes on unchanged frames. Model membership and adoption of existing effects refresh at most five times per second. Native member lookup and skill classification are cached; disabled filters avoid entity scans. Rendering hooks never skip skill execution or character animation updates.
