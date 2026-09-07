# Slash Commands

Local chat commands for Farever, starting with layer switching.

| Command | Action |
| --- | --- |
| `/layer` | Show your current full layer ID in your chat window. |
| `/layer <full layer ID>` | Attempt to reconnect to that layer. |
| `/layer help` | Show usage. |

Command names are case-insensitive. Layer IDs are case-sensitive; copy the full
ID exactly. A number such as `/layer 2` is not a layer ID. Recognized commands
and their feedback stay local, including when the mod is disabled. Other chat
messages and the game's `!say`, `!map`, `!group`, and `!to` commands work normally.

## Installing

Requires [HLX Core](https://github.com/hlx-framework/hlx-core).
[Better Mod Settings](../better-mod-settings/) is optional and provides an
**Enabled** checkbox. The mod defaults to enabled and stores its setting in
`hlx/mods/slash-commands/config.json`.

Get an installable ZIP from [CI builds](https://github.com/xWink/farever-mods/actions/workflows/build-slash-commands.yml)
or [releases](https://github.com/xWink/farever-mods/releases?q=slash-commands&expanded=true).
Install with Vortex or extract into the Farever game directory. The binary belongs
at `hlx/mods/slash-commands/slash-commands.hl`.

## Layer switching status

This is an experimental implementation based on the September 3, 2026 game dump.
It follows the existing Escape Menu's **Go to layer** reconnect sequence while
preserving your character, map configuration, group, and connection data.
Server acceptance on an ordinary account still needs an in-game test.

Use a known, active destination layer in the **same map and region** for the
first test. Have a second client run `/layer` to obtain its ID, then enter that
ID on the first client. After loading, run `/layer` again to confirm where you
arrived. The game handles authentication, retries, and connection errors; an
unavailable or rejected destination can return you to the menu.

The mod does not enumerate layers or guarantee a different layer through matchmaking.
It does not enable the admin menu or alter account permissions.

## Development

Build with Haxe 4.3.7 and `hlx-runtime`, as described in the
[repository build instructions](../README.md#building):

```sh
haxe test.hxml
haxe compile.hxml
```

The tests cover command routing, malformed input, and preservation of connection
data, including the 64-bit character ID. They do not simulate a live game server.

`SlashCommandsMod` intercepts `ui.hud.ChatBox.processMessage`. `LayerCommand`
contains parsing and destination preparation; add further command handlers at
the same interception point. All game methods are resolved by name.

Independent release tags use `slash-commands/vX.Y.Z` (or a prerelease such as
`slash-commands/v0.1.0-rc.1`). See [RELEASING.md](../RELEASING.md).
