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
- Follows your position with a flat-color arrow showing your character's facing direction.
- Fixed orientation, character-following rotation, or camera-following rotation.
- Adjustable zoom and size, with smooth marker edges.
- Upper-left or upper-right placement.
- Directional player arrows and markers for enemies, resources, NPCs, obelisks, and respawn points.
- Distinct icons for Guild Merchants, Demon Huntresses, and crafting, upgrade, and recycling stations.
- Treasure chest, undiscovered secret orb, and activity markers.
- Enemy filters for completed and incomplete Codex entries.
- Yellow rings highlight sparkling enemies and bosses.
- Individual plant and ore filters.
- Hover over markers to see their names below the map; scroll over the map to zoom.
- Sits behind menus and tooltips without intercepting clicks.

The minimap covers the Siagarta overworld and hides in other instances. Live player, enemy, gatherable, and chest markers are limited to entities currently sent to your client. Harvested plants and ore disappear until they respawn. Opened or inactive chests are hidden; secret orbs disappear once recorded as discovered by the game.

## Settings

Open **Mod Settings → Minimap** to change **Zoom %** (10–300), **Size** (160–400 in steps of 10), shape, rotation, placement, and marker visibility. Higher zoom shows a smaller area in more detail.

Scroll up over the minimap to zoom in and down to zoom out, in 10% steps. The zoom is saved to the same setting. Hovering over a marker displays its name centered below the minimap, including when the map rotates or uses a circular shape.

**Rotate minimap** keeps your arrow facing up as the terrain rotates around you. Enable **Follow camera** as well to put your camera's viewing direction at the top instead; your arrow then shows your character's facing direction relative to the camera. **Circular minimap** changes the shape, and **Show in left corner** switches to the upper-left. These options default off.

All marker types default on. The **Enemies** section has **Show enemies**, **Hide completed Codex enemies**, and **Hide enemies without Codex entries**. Both Hide options default off. Incomplete Codex enemies remain visible whenever **Show enemies** is enabled. Completed means you have reached the kill count that awards the Codex XP reward; later ranks do not change this filter. Dead enemies and player-owned summons are excluded.

The **Ore** and **Plants** sections contain **Show ore** and **Show plants**, followed by individual **Hide…** options. Ore filters cover Copper, Iron, Tin, and Tungstene; plant filters cover Madrigold, Lavendula, Ancient Thyme, and Zealotus. Each filter covers both small and large nodes. All Hide options default off.

| Marker | Appearance |
| --- | --- |
| Your character | Flat ivory arrow |
| Other players | Larger light-blue arrow showing facing direction |
| Plants | Green leaf |
| Ore | Gray stone |
| Enemies | Red circle; larger for bosses; thick yellow ring for sparkling variants |
| Activities | Teal flag |
| Respawn points | White cross |
| Obelisks | Purple diamond |
| NPCs | Yellow square |
| Guild Merchants | Yellow $ |
| Demon Huntresses | Purple horned face |
| Spark Recycler | Mint recycling arrows |
| Weapon Upgrade | Light-blue sword and upward arrow |
| Crafting Station | Orange hammer and workbench |
| Chests | Orange rectangular treasure chest |
| Undiscovered secret orbs | Light-blue circle |

**Show NPCs** also controls the Guild Merchant, Demon Huntress, and station icons. NPC markers draw in front of all other map elements. Obelisks draw above other players so crowds cannot obscure them. **Show chests**, **Show secret orbs**, and **Show activities** are separate options in the **Markers** section. Activity markers use the game's world-map locations, including overworld entrances for instanced activities.

Settings use HLX's native persistence at `hlx/config/minimap/config.json`. Better Mod Settings is optional; the mod works with its defaults without it. ImGui is not required.

## Building

Use Haxe 4.3.7 and the HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd minimap
haxe compile.hxml
```

Output: `build/minimap/minimap.hl`. The independent workflow packages this project and publishes releases for `minimap/v*` tags.
