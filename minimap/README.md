# Minimap

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=minimap%2Fv&expanded=true)

Adds a configurable minimap and enhances the main overworld map with detailed markers and filters.

## Features

- Markers for resources, enemies, companions, activities, players, NPCs, chests, and secret orbs, with hover details and distance.
- Quest NPCs use the game's native markers for available quests, quests in progress, and quests ready to turn in.
- Filter buttons: left-click to toggle a category; right-click for subfilters where available. The minimap's top-left gear shows or hides its filter buttons.
- **Use same filters for both maps** is enabled by default. Turn it off for independent filters; turning it back on copies the main map's filters to the minimap.
- Ordinary players are hidden by default; party members and friends are shown. Completed enemy mastery, collected companions, and completed activities are hidden by default.
- Activities include subfilters for dungeons, rifts, and soulstones. NPCs include subfilters for obelisks, respawns, faction merchants, and stations. Your own marker stays visible.
- The main map shows the next rift countdown beneath its marker, highlights the Heroic Bonus Dungeon with a green plus, and supports additional zoom, marker scaling, and optional character movement/auto-run while open.
- Click the Heroic Bonus Dungeon card to center the main map on its entrance, even when dungeon markers are filtered out.
- The main map keeps native right-click pin placement and the player’s camera-direction cone.
- Obelisk fast travel shows only unlocked destinations, with clickable yellow rings, your marker and camera-direction cone. Height arrows and the vertical-distance filter are disabled in this view.
- Both maps hide markers in regions whose obelisk has not been activated; the minimap also retains the game’s fog of war.
- The minimap supports circular or square shapes, mouse-wheel zoom, size, position, transparency, and marker scaling. Rotation and camera-following rotation are enabled by default.
- On square minimaps, the gear sits inside the top-left corner. Filters emerge to its left, continue down the side, and wrap below the map when needed.
- Optional rift alerts, sparkling-companion alerts, a rift timer or clock, and a vertical-distance filter that applies to both maps.

Live markers depend on information received by your client. Dungeon maps retain the game's native view.

## Installation

Requires HLX Core 0.0.8+, [Better Mod Settings](../better-mod-settings/), and [Mod Update Alerts](../mod-update-alerts/). Follow the [installation instructions](../README.md#installation), then configure the mod in **Game Menu → Mod Settings**.

Also available on [Nexus Mods](https://www.nexusmods.com/farever/mods/15).

The Main map and Minimap categories each have an independent Enabled setting, both on by default. Disabling Main map restores the native map; disabling Minimap hides the HUD minimap. Change marker filters on either map; use Mod Settings for layout, alerts, and other preferences.

See [Building](../README.md#building) for source builds and tests.
