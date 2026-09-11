# Farever Minimap

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=minimap%2F&expanded=true)

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
- Follows your position an arrow showing your character's facing direction.
- Fixed orientation, character-following rotation, or camera-following rotation.
- Adjustable zoom, size, and transparency.
- Marker scale slider resizes icons and all arrows together.
- Upper-left or upper-right corner placement.
- Directional player arrows and markers for enemies, resources, NPCs, obelisks, and respawn points.
- Distinct icons for Guild Merchants, Demon Huntresses, and crafting, upgrade, and recycling stations.
- Unopened treasure chest, undiscovered secret orb, and activity markers.
- Enemy filters for completed and incomplete Codex entries.
- Companion markers with an option to hide variants already in your collection.
- Yellow edge arrows guide you toward uncollected sparkling companions.
- Yellow rings highlight sparkling enemies and bosses.
- Individual plant and ore type filters.
- Hover over markers to see their names below the map
- Hover the mouse over the map and scroll to zoom.
- Up/down arrows show markers more than 15 metres above or below you.

The minimap covers the overworld and hides in other instances. Live player, enemy, gatherable, and chest markers are limited to entities currently sent to your client. Harvested plants and ore disappear until they respawn. Opened or inactive chests are hidden; secret orbs disappear once recorded as discovered by the game.

| Marker | Appearance |
| --- | --- |
| Your character | Flat ivory arrow |
| Other players | Larger light-blue arrow showing facing direction |
| Plants | Green leaf |
| Ore | Gray stone |
| Enemies | Red circle; larger for bosses; thick yellow ring for sparkling variants |
| Companions | Green pawprint; thick yellow ring for sparkling variants |
| Activities | Purple square with a white four-point star |
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

Settings use HLX's native persistence at `hlx/config/minimap/config.json`. Better Mod Settings is optional; the mod works with its defaults without it.

## Building

Use Haxe 4.3.7 and the HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd minimap
haxe compile.hxml
```

Output: `build/minimap/minimap.hl`. The independent workflow packages this project and publishes releases for `minimap/v*` tags.
