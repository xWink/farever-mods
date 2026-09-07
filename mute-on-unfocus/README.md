# Farever Mute When Unfocused

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-mute-on-unfocus.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=mute-on-unfocus&expanded=true)

This mod is maintained in [`xWink/farever-mods`](https://github.com/xWink/farever-mods/tree/main/mute-on-unfocus).

A small unofficial [HLX](https://github.com/hlx-framework/hlx-core) mod for **Farever** that lowers or mutes the game's own audio when the Farever window loses focus and restores the previous volume when you return to the game.

It only changes Farever's internal FMOD master VCA (`vca:/MASTER`). It does **not** change the Windows volume mixer or mute other applications.

## Easy Installation

### 1. Download the mod with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/6)

## Manual Installation

### 1. Install HLX Core

Install HLX Core from Nexus Mods:

https://www.nexusmods.com/site/mods/2118?tab=files&file_id=8998

Extract it into your Farever game directory. A typical Steam install path is:

```text
C:\Program Files (x86)\Steam\steamapps\common\Farever\
```

After HLX is installed, the Farever directory should contain `libhl64.dll` and an `hlx` folder.

### 2. Install the Farever ImGui plugin

The settings menu requires the Farever ImGui plugin:

https://www.nexusmods.com/farever/mods/4

Install it according to the plugin's instructions. The important native plugin file should end up here:

```text
Farever\hlx\plugins\imgui64.hdll
```

The plugin may also include its supporting `imgui\fonts` folder under `hlx\plugins`.

Do not place `imgui64.hdll` loose beside `Farever.exe`.

### 3. Install Better Mod Settings

Follow the installation instructions to download [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings).

### 4. Install this mod

Download the latest build artifact ZIP. Install it with Vortex, or extract the ZIP directly into the Farever game directory. The archive already contains the complete game-relative path:

```text
hlx\mods\mute-unfocused\mute-unfocused.hl
```

The final layout should look roughly like:

```text
Farever\
├── libhl64.dll
└── hlx\
    ├── plugins\
    │   ├── imgui64.hdll
    │   └── imgui\
    │       └── fonts\
    └── mods\
        └── mute-unfocused\
            └── mute-unfocused.hl
```

Fully close and relaunch Farever after installing or replacing the mod.

## How it works

The mod hooks `GameApp.update` through HLX and watches Farever's `hxd.Window.isFocused` state.

When focus changes:

- **Focused → unfocused:** read the current Farever master VCA volume and apply the configured background volume.
- **Unfocused → focused:** restore the saved master VCA volume.

Because this is done through Farever's FMOD API, other Windows applications are unaffected.

## Building from source

Prerequisites:

- Haxe 4.3.x (tested with Haxe 4.3.7)
- HLX runtime (`hlx-runtime`)
- Farever `hl-imgui`

Install the Haxe dependencies:

```text
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
haxelib git hl-imgui https://github.com/laymain/farever-mods.git main imgui/hl-imgui/src
```

Then run from the `mute-on-unfocus` subproject directory:

```text
cd mute-on-unfocus
haxe compile.hxml
```

The output is:

```text
build/mute-unfocused/mute-unfocused.hl
```

The repository includes a minimal `h3d.impl.DX12Driver` compile-time wrapper so this mod can build without distributing Farever's proprietary generated game library.

## Compatibility

This mod is tied to Farever's internal API and the current HLX/ImGui integration. Game or framework updates can break the hook or native UI integration and may require a rebuild.

If Farever stops launching after an update, remove:

```text
Farever\hlx\mods\mute-unfocused\
```

and relaunch the game.

## Disclaimer

This is an unofficial community mod and is not affiliated with or endorsed by Farever's developers, HLX, Steam, Valve, or the Farever ImGui plugin author. Use third-party mods at your own risk, especially in online games.
