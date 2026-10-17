# Trade + Marketplace

A native trade window for nearby party members. Both players need Trade + Marketplace,
HLX Core 0.0.8+, Better Mod Settings, and Mod Update Alerts installed.
No ImGui dependency. This is an initial testing build, not a published release.

## Using Trade + Marketplace

1. Join the same party and stand near each other (within 5 world units).
2. Choose **Trade** in the other player's interaction menu, or type
   `/trade PlayerName`. With exactly one other party member, `/trade` also works.
3. The other player receives a **Trade request** popup and clicks **Accept request**
   or **Decline**. Accepting opens their Trade window and backpack. Drag the popup
   by its header to move it; its position is saved between requests and restarts,
   and kept on screen if the resolution changes. Simultaneous requests resolve
   to one invitation, which the receiving player accepts. The countdown sits
   in the header's right corner, matching Ready Check.
   The initiator stays in place; after accepting the request, the recipient
   tries to walk onto the initiator's position, as closely as native collision
   allows. This initial approach stops after five seconds if blocked. There is
   no facing, flat-ground or precise-overlap requirement to accept the trade.
   Movement and manual/quick-loot pickup are blocked while the trade window is
   open. The incoming request popup alone does not lock the recipient's controls.
4. Your backpack opens beside Trade automatically. Drag items onto **Your offer**, or right-click them to
   add/remove them. Right-click an offered item, or drag it out of your offer,
   to remove it. You can offer six items/stacks in a single row per offer. Right-click offers a whole
   stack; native split-stack dragging preserves the selected count. You can
   rearrange items between backpack slots normally. During a trade, the inventory
   key/HUD bag button opens the backpack without replacing the trade window.
   Offers use compact icon grids with rarity borders and quantity labels;
   hover an item to see the game's native item tooltip and equipment comparison.
   Partner previews preserve level, upgrades, rarity, infusions, sockets and weapon
   effects. The full tooltip, comparison cards and Equipped labels stay on screen,
   using the same positioning as Item Utilities' Inspect window. Oversized tips
   scale down to fit; backpack tooltips also receive this fitting while Trade is open.
   Hovering offered items uses the native inventory item cursor on both sides.
   Slot borders keep their item rarity colour on hover. Quantity labels have no
   dark background bar. Each side shows its acceptance status.
   Offer slots are gray and cannot accept items until the request is accepted.
   Offered backpack items have a gold border and a **TRADE xN** label showing
   the offered quantity. The mark follows the item when rearranging or sorting,
   and clears when the item is removed from the offer or the trade ends.
5. Review the names, quantities and details on both sides, then **Accept trade**.
   **Unaccept** is yellow and **Cancel** is red, using Ready Check's colours.
   Alt-tabbing/background frame throttling does not disable acceptance; input
   control is refreshed immediately before every drop or pickup.
   Cancel, X and Escape work while reviewing offers. Once both players commit,
   closing is disabled until completion, a timeout or an error.
   Any offer change clears both acceptances. Empty offers are allowed for gifts,
   but at least one player must offer something. Acceptance requires one backpack
   slot per incoming item/stack after your offered items are dropped. Fully offered
   stacks free a slot; partial-stack offers do not. The button is disabled and shows
   the slot shortage until there is enough room. This is rechecked before committing
   and does not depend on incoming items merging into existing stacks.
6. The mod drops and picks up the accepted items through the normal game
   requests. Each client confirms its server replies and inventory contents.
   A green **Trade complete** message appears locally when both confirm receipt.
   If a partner's item lands outside pickup range, your character walks toward
   that exact ground item and picks it up on reaching native interaction range.
   A five-second stall timeout releases controls if the exchange stops making
   progress. Each confirmed new drop/pickup or receipt restarts that timer;
   duplicate messages do not. Walking toward one drop also has a five-second limit.

The header can be dragged. Closing is blocked during the committed exchange.
The inset body reaches the header, with 16 pixels of inner spacing above the
offers. The title has a 28-pixel left inset. There is no divider line beneath
the offer panels. Status text is vertically centered between the offer panels
and the action buttons using its rendered text bounds.
Changing party/area, moving too far apart before exchanging, dying, changing an offered item, or
disabling Trade + Marketplace stops the operation. Cancellation after drops have started can
leave items on the ground; this automates the same cooperative exchange as
manual dropping and does not add server escrow or rollback.
Positioning and input locks improve reliability for cooperating clients; they
cannot enforce honesty against an altered mod or disconnection.
Native drops still scatter within a cone, rather than landing at an exact point.
Both players must install this build and restart the game.

## Solo UI preview

Press **F8** while playing to open or close a local trade preview. The binding is
configurable in Better Mod Settings. Your offer appears above the sample partner
offer; add/remove your items normally and click Accept to preview both acceptance
badges. Preview mode never sends trade whispers or drops, picks up, or exchanges
items. It cannot open during a real trade. Empty slots have no plus sign, and the
slot and acceptance badge corners use smoother rounded geometry.

## Implementation

- A bounded, versioned protocol uses private whispers addressed to the other
  trader's player ID. Trade + Marketplace clients hide these messages, including from More
  Settings' self chat bubbles. Nothing is broadcast to party chat, and the
  player's selected chat channel stays unchanged. Both traders must use this
  whisper build; it cannot communicate with the earlier party-chat test build.
  Invitation whispers start with the sender's character name and a readable
  explanation directing recipients without the mod to https://www.nexusmods.com,
  followed by the encoded packet. Modded recipients consume the whole whisper
  and show the request popup instead. Other protocol messages remain compact.
  Incoming packets are intercepted at the native received-message RPC and local
  history entry points, with ChatBox's polled delivery path as a fallback if
  those earlier hooks cannot install. Channel identity is read through native enum metadata
  and game-module reflection, without casting native reflection arrays into the
  mod. Ordinary whispers follow the original game path.
  Game-owned player IDs from the social menu are normalized to local text before
  serialization, so the destination is transmitted as a string, not a native
  String object's fields.
- Both acceptances bind the session, offer revisions, quantities and preview
  data. Sender identity comes from the game's received chat message. Only a
  current party member can invite or participate. Whisper delivery failures stop
  the trade, and commit delivery is confirmed before dropping. Requests expire
  after 45s, offers after 180s without edits/acceptance, and commit/exchange stalls after 5s.
- Previews contain bounded plain values and game database IDs, never serialized
  hxbit object graphs. Hover uses the actual replicated item when available;
  otherwise the same detached item factory used by native base-item tooltips
  supplies the native tooltip/comparison UI. Preview objects never receive the
  offered UID, bind to a network host, enter inventories or issue item actions.
  Tooltip metadata is included in acceptance hashes.
- Original item identities are checked before dropping. Item fingerprints cover
  kind, class, flags, level, upgrades, rarity, infusion/bonus, slots/enchantments,
  and weapon effects. Ground-object IDs are announced and independently checked
  before pickup; pre-existing/ambiguous ground items are not guessed at.
- Initiator drops are confirmed first, then partner drops. This distinguishes
  identical items even when the server clones them during a drop. Both then
  collect the exact announced objects. Each drop request is issued once;
  successful RPC callbacks alone do not count as inventory receipt.
- Idle sessions do not scan inventories. Party checks run at 5 Hz during a trade;
  chat packets are capped at four per second and previews have fixed size limits.
- Movement uses the native local hero's point-movement method. No positions,
  collision rules or remote player objects are changed directly. The initial
  approach is best effort; collection targets only validated partner drops.
  The five-unit proximity gate applies before the exchange, not while walking
  to scattered loot. The controller hook runs after native input processing,
  before physics. Controls restore on cancellation, completion, timeout,
  disable, player replacement, disposal or error.
- User cancellation is rejected during preparation and exchange. Escape, the
  close button, Cancel and native window-closing paths use the same phase guard.
  Internal errors and timeout cancellation can still release the lock.
- Normal communication diagnostics and transport file writes are removed.
  Unexpected runtime errors still appear in the normal game/HLX log.
- A pickup bypass is scoped to the exact partner drop only during its native
  validation/request calls, and is cleared even if a native call throws.

## Building and verification

From this directory, with Haxe 4.3.7 and HLX runtime installed:

```sh
haxe test.hxml
haxe compile.hxml
```

The GitHub Actions workflow runs protocol and simulated exchange tests, compares
core behavior against the preserved original binary, then builds an installable
artifact. See [the recovery record](recovery/README.md) for provenance, test
coverage and remaining validation. Reconstructed UI and game integration still
need an in-game two-player test before a public release.
