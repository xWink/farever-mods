# Slash Commands

Local chat commands for Farever, starting with layer switching.

| Command | Action |
| --- | --- |
| `/layer` | Show your current full layer ID in your chat window. |
| `/layer <full layer ID>` | Attempt to reconnect to that layer. |
| `/layer help` | Show usage. |
| `/layers` | Query the current realm's server API and display explicit server IDs if returned. |

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

The mod does not guarantee a different layer through matchmaking.
It does not enable the admin menu or alter account permissions.

## Finding other layers

`/layers` sends the existing authenticated `realm/query` request through
`mpman.Realms.loadRealmDetails`, using your current realm ID. It leaves your
connection in place and makes no lobby or matchmaking requests.

**A complete list of all existing layers is not confirmed to be available.**
The response schema in this game build contains realm metadata and a `layout`,
with no documented active-layer directory. The command displays explicit
`serverID` fields found in returned layout/server records, removes duplicate IDs,
and marks your current layer. These results do not establish completeness or
whether each destination is still running. Realm IDs, logical server types,
and map names are never presented as layer IDs.

If the server returns only configuration, the command reports that no layer IDs
were supplied. An empty result does **not** mean no other layers exist. Rejected
queries and timeouts also get local feedback. The HLX log records only a brief
summary of response field names to help investigate the live response format.

The query is scoped to the current realm, rather than every region. Requests to
the live service still need in-game verification.

## Development

Build with Haxe 4.3.7 and `hlx-runtime`, as described in the
[repository build instructions](../README.md#building):

```sh
haxe test.hxml
haxe compile.hxml
```

The tests cover command routing, malformed input, preservation of connection
data (including the 64-bit character ID), and distinguishing explicit server
IDs from realm configuration. They do not simulate a live game server.

`SlashCommandsMod` intercepts `ui.hud.ChatBox.processMessage`. `LayerCommand`
contains parsing and destination preparation; add further command handlers at
the same interception point. All game methods are resolved by name.

Independent release tags use `slash-commands/vX.Y.Z` (or a prerelease such as
`slash-commands/v0.1.0-rc.1`). See [RELEASING.md](../RELEASING.md).
