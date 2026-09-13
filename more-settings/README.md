# More Settings

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-more-settings.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=more-settings%2Fv&expanded=true)

Client settings for **Farever**: chat filtering, temporary audio levels, and separate ally presentation controls for rifts, dungeons, and the overworld. Previously called **More Audio Settings**.

## Settings

Open **More Settings** in [Better Mod Settings](../better-mod-settings/).

| Category | Controls | Defaults |
| --- | --- | --- |
| General | Disable profanity filter | On; imports the standalone mod's saved preference when available |
| Unfocused Volume | Adjust unfocused volume; Unfocused volume % | On; 0% |
| Fast Travel Volume | Adjust fast travel volume; Fast travel volume % | Off; 0% |
| Rift Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |
| Dungeon Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |
| Overworld Effects | Hide ally attacks; Hide ally buffs; Hide allies | All off |

The profanity option applies to displayed player text and keeps HTML escaping. Character-name validation is unchanged.

Audio limits affect Farever's master volume while its window is unfocused or your character is flying between obelisks. When both conditions apply, the quieter limit wins. Temporary limits never raise a quieter master setting. The original volume returns once all active conditions end, including after changing the master volume in the game's options.

**Hide ally attacks** hides the visuals and sounds of friendly players' damaging or harmful abilities with no beneficial component. **Hide ally buffs** covers healing, shields, beneficial statuses, and utility abilities. Mixed damage/support abilities belong to the buffs category so attack hiding preserves useful support effects. Classification follows native skill data and referenced subskills/statuses.

**Hide allies** hides friendly player models and equipment independently of their abilities. Names and other UI remain visible. Your own model, abilities, summons' effects, and buffs you cast on other players remain visible. Enemy and duel/PvP opponent effects remain visible. Other players' buffs applied to you follow the caster's filter.

Rifts take precedence over dungeons; dungeon instances (including boss instances) use Dungeon Effects; World maps use Overworld Effects. Unknown locations are left visible. Visibility options are client presentation changes: skills, damage, healing, targeting, animation callbacks, and network state continue normally.

## Installation and upgrade

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core) and [Better Mod Settings](../better-mod-settings/).
2. Close Farever. Remove the old **binary and settings descriptor** from `hlx/mods/more-audio-settings/` (or `hlx/mods/mute-unfocused/`). Keep old configuration files for migration.
3. If the standalone Disable Profanity Filter mod is installed, remove its binary and settings descriptor as well so this setting has one owner. Keep its configuration file.
4. Install `farever-more-settings.zip` with Vortex, or extract it into the Farever game directory. The archive contains `hlx/mods/more-settings/more-settings.hl` and its `configFormats.json`.
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

Output: `build/more-settings/more-settings.hl`.

Regression tests exercise the production volume controller, region/ability policy, classifier, and presentation tracker with a simulated native adapter. CI requires those tests before packaging. Native API and bytecode inspection supplements these tests; actual rendering/audio still require in-game multiplayer testing after game updates.

The mod avoids repeating FMOD writes on unchanged frames. Model membership and adoption of existing effects refresh at most five times per second. Native member lookup and skill classification are cached; disabled filters avoid entity scans. Rendering hooks never skip skill execution or character animation updates.
