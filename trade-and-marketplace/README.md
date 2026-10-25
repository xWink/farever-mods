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

Browse the same live buy and sell orders on the [Farever marketplace at Fareverly](https://fareverly.com/marketplace), with no website sign-in required. Create listings and arrange trades through the mod. View [screenshots and features](https://fareverly.com/mods/trade-and-marketplace).

Press **F7** to open or close the marketplace, or type `/market` or `/marketplace` to open it. The hotkey can be rebound in Better Mod Settings. Closing and reopening preserves your scroll position and selection.

- Browse listings for your game server, filter items and inspect native tooltips. Scroll down to load more listings automatically. **My listings** also uses a continuous scrollable list.
- Choose **Login to Fareverly** in the mod's settings and sign in with Steam to list unlocked, tradable items. **Verify Fareverly connection** checks your saved connection. Choose **Inventory** or **Bank** on **Sell** to browse a scrollable item grid and select bank tabs. Locked, untradeable and already-listed items cannot be listed. Fareverly access is shared with DPS Meter and other Fareverly mods.
- **Buy** shows the game’s item catalog with search and category, subcategory, rarity, and class filters. Select an item to post a buy order with quantity, price, and applicable level, weapon rarity, infusion bonus, and prismatic options. Choose **Any** to leave the level unspecified. Buying does not require owning the requested item. An existing buy order with identical requirements disables the button with **Buy order already exists**; edit that order in **My listings** instead.
- Browse defaults to both order types; filter by Any, Buy, or Sell. Listings show **B>** or **S>** before the item name, and My listings manages both types. Each account can have up to 20 active sell orders and 20 active buy orders per region, shared across characters. Duplicate-item limits apply separately to each order type across regions.
- Listing quantities combine identical tradable items across your inventory and unlocked bank tabs, whichever view you select from.
- Set a total price in Silver Trays (500 gold each), or choose **Open to offers**.
- Manage up to 40 active orders per region (20 sell and 20 buy) under **My listings**. Listings expire 3 days after posting. Edit a listing to change its quantity or price.
- **Whisper seller** contacts their account. Meet nearby to complete the trade. Items stay in their original location; withdraw bank items before trading.
- Signed-in players send a heartbeat on login and once per minute. Logging out or disabling the mod stops updates; online status expires within 3 minutes.

Install the entire build, including `hlx/plugins/trade-and-marketplace/trade_marketplace_desktop.hdll`. DPS Meter is not required. The mod uses Fareverly’s live listing API. The website displays the same live listings for browsing.
