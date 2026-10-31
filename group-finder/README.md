# Group Finder — local prototype

Open **Group Finder** with **F9**, `/groups`, `/groupfinder`, or its button in Better Mod Settings. The hotkey is configurable, including modifiers. F8 remains available to DPS Meter's mode toggle.

Browse **Dungeons**, **World Events**, and **Other** using the category sidebar. Listings show the title, party members, classes, levels, leader, and available places. The window can be moved and scales to fit the screen; listings and requests use native scrolling with a visible scrollbar.

Create, edit, and close listings locally. Only a solo player or the current party leader can list. Titles are limited to 30 Unicode code points, treated as plain text, and rendered through the game's profanity filter. Your real party is sampled twice per second, including when the window is closed. A full party, changed party, lost leadership, or logout closes the listing. Closing the window keeps the listing; leaving space in a previously full party does not repost it.

Sample groups are enabled by default; turn off **Show sample listings** in settings to test an empty browser. Creating your own listing enables **Requests → Add sample request** to preview accept/decline. Requesting a sample group previews pending/cancelled/expired requests. Requests expire after 60 seconds; repeat requests have a 10-second cooldown. Accepted sample requests reserve a place for 60 seconds to exercise simultaneous-request handling.

This build uses an asynchronous in-memory `MockGroupService` behind `GroupService`. No HTTP calls, heartbeats, login, whispers, or real party invitations occur. Listings last only for the current game session. The local preview label and sample-group labels distinguish test data from real groups. The mock models a 120-second listing lease renewed by party snapshots; these timings and the interface are prototype choices, not a finalized Fareverly API contract.

The production integration is deferred: shared Fareverly authentication, Group Finder-specific presence, server-enforced account/party uniqueness and region scope, remote updates, and whisper request/response routing with native invitations. Cross-zone and cross-instance delivery still needs verification.

Install the complete build archive using Vortex, or extract it into the Farever game folder. Requires HLX Core 0.0.8+, Better Mod Settings, and Mod Update Alerts. Trade and Marketplace is not required.

Build with Haxe 4.3.7 and `hlx-runtime` installed:

```sh
cd group-finder
haxe test.hxml
haxe compile.hxml
```
