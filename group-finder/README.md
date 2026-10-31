# Group Finder — local prototype

Open **Group Finder** with **F9**, `/lfg`, `/groupfinder`, or its button in Better Mod Settings. The hotkey is configurable, including modifiers. F8 remains available to DPS Meter's mode toggle.

Browse **Dungeons**, **World Events**, and **Other** using the category sidebar. Compact listings show larger brown headings matching Marketplace item names, party members, native coloured class banners, levels, leader, and available places. Fareverly badges are centered beside member names, before the party leader star, with the same artwork and hover labels as Marketplace. About one in five sample members and requests has a badge; real account badges will come from the future Fareverly integration. **Requests** and **Create listing / My listing** sit at the bottom of the sidebar. Requests is available only while you have an open listing, and its inbox resets when the listing closes. The window can be moved and scales to fit the screen; listings and requests use native scrolling with a visible scrollbar.

Create, edit, and close listings locally. Only a solo player or the current party leader can list. Titles are limited to 50 Unicode code points, treated as plain text, and rendered through the game's profanity filter. Your real party is sampled twice per second, including when the window is closed. A full party, changed party, lost leadership, or logout closes the listing. An open listing disables requesting to join other groups until you close your listing. Closing the window keeps the listing; leaving space in a previously full party does not repost it.

Sample groups are enabled by default; turn off **Show sample listings** in settings to test an empty browser. Creating your own listing enables **Requests → Add sample request** to preview accept/decline. Every sample click creates a unique requester. New incoming requests produce a native, timestamped system message with normal chat wrapping and spacing with the requester's name, class, and level, even when Group Finder is closed. There is no cap on distinct requesters or outstanding invitations; native party capacity will be enforced by the game when real invites are integrated. Duplicate pending requests from the same player are suppressed. Requesting a sample group previews pending/cancelled/expired requests directly on the listing. Requests expire after 60 seconds; repeat requests from the same player have a 10-second cooldown.

This build uses an asynchronous in-memory `MockGroupService` behind `GroupService`. No HTTP calls, heartbeats, login, whispers, or real party invitations occur. Listings last only for the current game session. All sample groups and join requests are local test data. The mock models a 120-second listing lease renewed by party snapshots; these timings and the interface are prototype choices, not a finalized Fareverly API contract.

The production integration is deferred: shared Fareverly authentication, Group Finder-specific presence, server-enforced account/party uniqueness and region scope, remote updates, and whisper request/response routing with native invitations. Cross-zone and cross-instance delivery still needs verification.

Install the complete build archive using Vortex, or extract it into the Farever game folder. Requires HLX Core 0.0.8+, Better Mod Settings, and Mod Update Alerts. Trade and Marketplace is not required.

Build with Haxe 4.3.7 and `hlx-runtime` installed:

```sh
cd group-finder
haxe test.hxml
haxe compile.hxml
```
