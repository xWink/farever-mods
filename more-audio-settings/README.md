# More Audio Settings

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-more-audio-settings.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=more-audio-settings&expanded=true)

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

### 2. Install Better Mod Settings

Follow the installation instructions to download [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings).

### 3. Install this mod

Download the latest build artifact ZIP. Install it with Vortex, or extract the ZIP directly into the Farever game directory. The archive already contains the complete game-relative path:

```text
hlx\mods\more-audio-settings\more-audio-settings.hl
```

Fully close and relaunch Farever after installing or replacing the mod.

### Upgrading from the previous name

Remove `mute-unfocused.hl` and `configFormats.json` from the old
`hlx/mods/mute-unfocused/` folder so only More Audio Settings loads and appears
in the settings menu. Keep any old `config.json` until the first launch.

Settings now live at `hlx/config/more-audio-settings/config.json`. The first
launch imports `hlx/config/mute-unfocused/config.json`, or the older mod-local
`hlx/mods/mute-unfocused/config.json` if necessary. Existing More Audio Settings
configurations take priority, and the old settings files remain as backups.

The build artifact is `farever-more-audio-settings`; the release archive is
`farever-more-audio-settings.zip`. Release tags use `more-audio-settings/vX.Y.Z`.

## How it works

**Adjust unfocused volume** controls only the background-volume feature. Its
configuration key is `adjustUnfocusedVolume`; existing `enabled` values migrate
automatically, including when the feature was turned off.

The mod hooks `GameApp.update` through HLX and watches Farever's `hxd.Window.isFocused` state.

When focus changes:

- **Focused → unfocused:** read the current Farever master VCA volume and apply the configured background volume.
- **Unfocused → focused:** restore the saved master VCA volume.

Because this is done through Farever's FMOD API, other Windows applications are unaffected.

## Building from source

Prerequisites:

- Haxe 4.3.x (tested with Haxe 4.3.7)
- HLX runtime (`hlx-runtime`)

Install the Haxe dependencies:

```text
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
```

Then run from the `more-audio-settings` subproject directory:

```text
cd more-audio-settings
haxe compile.hxml
```

The output is:

```text
build/more-audio-settings/more-audio-settings.hl
```

## Compatibility

This mod is tied to Farever's internal API and HLX. Game or framework updates can break the hook and may require a rebuild.

If Farever stops launching after an update, remove:

```text
Farever\hlx\mods\more-audio-settings\
```

and relaunch the game.

## Disclaimer

This is an unofficial community mod and is not affiliated with or endorsed by Farever's developers, HLX, Steam, or Valve. Use third-party mods at your own risk, especially in online games.
