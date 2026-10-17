# Trade and Marketplace

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-trade-and-marketplace.yml)

A native trade window for nearby party members. This is a testing build; both players need the mod installed.

## Installation

Requires HLX Core 0.0.8+, [Better Mod Settings](../better-mod-settings/), and [Mod Update Alerts](../mod-update-alerts/). Follow the [installation instructions](../README.md#installation), then configure the mod in **Game Menu → Mod Settings**.

Download the **farever-trade-and-marketplace** artifact from a successful build. It installs under `hlx/mods/trade-and-marketplace/`.

If upgrading from the earlier test build, remove `hlx/mods/trade/` so both copies cannot load, then reapply your settings. Both players should use the same build and restart the game.

## Trading

1. Join the same party and stand within 5 world units of each other.
2. Choose **Trade** in the other player's interaction menu or type `/trade PlayerName`. With exactly one other party member, `/trade` also works.
3. The recipient accepts the request. The popup preserves cursor visibility; press Alt if the mouse is hidden.
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
