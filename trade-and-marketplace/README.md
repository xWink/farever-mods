# Trade and Marketplace

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-trade-and-marketplace.yml)

An in-game marketplace and native trade window for nearby players. Both players need the mod installed to trade.

## Installation

Requires HLX Core 0.0.8+, [Better Mod Settings](../better-mod-settings/), and [Mod Update Alerts](../mod-update-alerts/). Follow the [installation instructions](../README.md#installation), then configure the mod in **Game Menu → Mod Settings**.

Download from [Nexus Mods](https://www.nexusmods.com/farever/mods/30) or [GitHub Releases](https://github.com/xWink/farever-mods/releases?q=trade-and-marketplace). It installs under `hlx/mods/trade-and-marketplace/`.

If upgrading from the earlier test build, remove `hlx/mods/trade/` so both copies cannot load, then reapply your settings. Both players should use the same build and restart the game.

## Trading

1. Stand within 5 world units of each other. You do not need to be in the same party.
2. Choose **Trade** in the other player's interaction menu or type `/trade PlayerName`. With exactly one other party member, `/trade` also works.
3. The recipient accepts the request. If you are in different parties, both players leave their old party, the requester sends a party invite, and the recipient joins automatically. The popup preserves cursor visibility; press Alt if the mouse is hidden.
4. Drag items into **Your offer**, or right-click backpack items to offer a whole stack. Split-stack dragging preserves the selected quantity. Each offer holds six items/stacks; locked items cannot be offered.
5. Hover items to inspect their details, then choose **Accept trade**. Changing either offer clears both acceptances. Cancel before both players commit.
6. The mod exchanges the items and confirms receipt. **Trade complete** includes the number of received items, counting stack quantities.

A full-inventory indicator appears if the incoming offer will not fit. Capacity checks account for compatible existing stacks and space freed by outgoing items.

Trade and request windows remember their positions. Incoming requests are automatically rejected during combat, NPC dialogue, another trade, or while a menu is open, with **Player is busy.** Enable **Reject all trade requests** in Mod Settings to return **Player is not accepting trade requests.** instead.

## Exchange limitations

Trading automates normal item dropping and pickup; it does not provide server escrow or rollback. Movement and manual pickup are blocked during trading, and cancellation is disabled after commitment. A ten-second stall timeout releases controls if progress stops. Interruptions can leave items on the ground, so trade with someone you trust.

## Development

See [Building](../README.md#building) for source builds and tests.

Source lives in `trade-and-marketplace/`. Actions runs regression tests and compares core protocol behavior with the preserved original binary before packaging. See the [recovery record](recovery/README.md) for provenance. Native exchange behavior also needs two-player in-game testing.

## Marketplace

Press **F7** or type `/market` or `/marketplace`. The hotkey can be rebound in Better Mod Settings and is ignored while typing in a text field.

- Browse listings for your game server, filter items and inspect native tooltips.
- Sign in with Steam to list unlocked, tradable items. Choose **Inventory** or **Bank** on **Sell** to browse a scrollable item grid and select bank tabs. Locked, untradeable and already-listed items cannot be listed. The API key is shared with DPS Meter and other Fareverly mods.
- Set a total price in Silver Trays (500 gold each), or choose **Open to offers**.
- Manage up to 20 active listings per region under **My listings**. Listings expire 3 days after posting. Remove and re-add a listing to change its price.
- **Whisper seller** contacts their account. Meet nearby to complete the trade. Items stay in their original location; withdraw bank items before trading.
- Signed-in players send a heartbeat on login and once per minute. Logging out or disabling the mod stops updates; online status expires within 3 minutes.

Install the entire build, including `hlx/plugins/trade-and-marketplace/trade_marketplace_desktop.hdll`. DPS Meter is not required. The mod uses Fareverly’s live listing API. The website marketplace remains a separate preview until its live-data rollout.
