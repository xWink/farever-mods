# Farever Disable Profanity Filter

An HLX mod for Farever that lets you disable the client-side profanity filter used for chat messages and speech bubbles.

Character-name validation is intentionally unchanged.

## Installation

### Easy Installation

1. Download the mod with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/7)

### Manual Installation

1. Install [HLX Core](https://github.com/hlx-framework/hlx-core).
2. Install the Farever ImGui plugin required by HLX mods with settings menus.
3. Install [Better Mod Settings](https://github.com/xWink/farever-better-mod-settings)
4. Download the latest build artifact. Install the ZIP with Vortex, or extract it directly into the Farever game directory; the archive already contains `hlx/mods/disable-profanity-filter/`.
5. Start Farever.

## Building (developers)

Install Haxe 4.3.7, HLX Runtime, and `hl-imgui`, then run:

```sh
haxe compile.hxml
```

The compiled mod is written to `build/disable-profanity-filter/disable-profanity-filter.hl`.

