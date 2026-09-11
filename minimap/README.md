# Farever Minimap

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=minimap%2Fv&expanded=true)

A compact overworld minimap with a centered player arrow.

## Installation

### Easy Installation

1. Install [HLX Core](https://www.nexusmods.com/site/mods/2118?tab=files).
2. Download the ZIP from the latest successful [Minimap build](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml) and install it using Vortex's **Install From File**.
3. Install [Better Mod Settings](../better-mod-settings/) for in-game controls, then fully restart Farever.

### Manual Installation

1. Install [HLX Core](https://www.nexusmods.com/site/mods/2118?tab=files) in your Farever game folder.
2. Download the latest successful [build artifact](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml).
3. Extract the ZIP into the game folder. It contains `hlx/mods/minimap/minimap.hl` and `configFormats.json`.
4. Install [Better Mod Settings](../better-mod-settings/) for in-game controls, then fully restart Farever.

## Highlights

- A square or circular minimap using Farever's own map artwork.
- Follows your position and shows your character's facing direction.
- Fixed orientation, character-following rotation, or camera-following rotation.
- Adjustable zoom and size, with smooth marker edges.
- Upper-left or upper-right placement.
- Directional player arrows and markers for enemies, resources, NPCs, obelisks, and respawn points.
- Distinct icons for banks, Demon Huntresses, and crafting, upgrade, and recycling stations.
- Enemy filters for completed and incomplete Codex entries.
- Sits behind menus and tooltips without intercepting clicks.

The minimap covers the Siagarta overworld and hides in other instances. Live player, enemy, and gatherable markers are limited to entities currently sent to your client. Harvested plants and ore disappear until they respawn.

## Settings

Open **Mod Settings → Minimap** to change **Zoom %** (10–300), **Size** (160–400 in steps of 10), shape, rotation, placement, and marker visibility. Higher zoom shows a smaller area in more detail.

**Rotate minimap** keeps your arrow facing up as the terrain rotates around you. Enable **Follow camera** as well to put your camera's viewing direction at the top instead; your arrow then shows your character's facing direction relative to the camera. **Circular minimap** changes the shape, and **Show in left corner** switches to the upper-left. These options default off.

All marker types default on. The enemy section independently controls enemies with **incomplete Codex entries**, **completed Codex entries**, and **no Codex entry**. Completed means you have reached the kill count that awards the Codex XP reward; later ranks do not change this filter. Dead enemies and player-owned summons are excluded.

| Marker | Appearance |
| --- | --- |
| Other players | Light-blue arrow showing facing direction |
| Plants | Green circle |
| Ore | Orange diamond |
| Enemies | Red circle; larger for bosses |
| Respawn points | White cross |
| Obelisks | Purple diamond |
| NPCs | Yellow square |
| Guild merchants / banks | Gold chest |
| Demon Huntresses | Purple horned face |
| Spark Recycler | Mint recycling arrows |
| Weapon Upgrade | Light-blue sword and upward arrow |
| Crafting Station | Orange hammer and workbench |

**Show NPCs** also controls the bank, Demon Huntress, and station icons. Obelisks draw above other players so crowds cannot obscure them.

Settings use HLX's native persistence at `hlx/config/minimap/config.json`. Better Mod Settings is optional; the mod works with its defaults without it. ImGui is not required.

## Building

Use Haxe 4.3.7 and the HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd minimap
haxe compile.hxml
```

Output: `build/minimap/minimap.hl`. The independent workflow packages this project and publishes releases for `minimap/v*` tags.
