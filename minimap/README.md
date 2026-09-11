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

- A square minimap in the upper-right corner, using Farever's own map artwork.
- Follows your position and shows your character's facing direction.
- Fixed map orientation, with adjustable zoom and size.
- Sits behind menus and tooltips without intercepting clicks.

This first version covers the Siagarta overworld. It hides in other instances; dungeon maps and mob/resource markers are not included yet.

## Settings

Open **Mod Settings → Minimap** to enable or disable the map, change **Zoom %** (50–300), or adjust **Size** (160–400). Higher zoom shows a smaller area in more detail.

Settings use HLX's native persistence at `hlx/config/minimap/config.json`. Better Mod Settings is optional; the mod works with its defaults without it. ImGui is not required.

## Building

Use Haxe 4.3.7 and the HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd minimap
haxe compile.hxml
```

Output: `build/minimap/minimap.hl`. The independent workflow packages this project and publishes releases for `minimap/v*` tags.
