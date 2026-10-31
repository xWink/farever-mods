# Group Finder

Open with **F9**, `/lfg`, `/groupfinder`, or the button in Better Mod Settings. The hotkey is configurable. Browse Dungeons, World Events, and Other, with native scrolling and scrollbars. Listings display party members, class banners, levels, yellow leader stars, and Fareverly supporter badges.

Connect through **Login to Fareverly** in Group Finder settings. **Verify Fareverly connection** checks the connection without showing the key. Credentials are shared with DPS Meter and Trade and Marketplace; an existing valid login works here too. Group Finder works independently of both mods.

## Listings

Listings are stored on Fareverly and restricted to your connected region. Only solo players and party leaders can post, with one listing per account and party. Titles have a 50-character Unicode limit and are rendered as plain text through the viewer's profanity filter. Badges come from Fareverly, never from posted party data.

Party state is sampled twice a second, even with the window closed. Changes are coalesced to at most one roster update per second. A full party, lost leadership, changed party/region, logout, or disabling the mod closes the listing. Closing the window keeps it. A later free slot never automatically reposts it. Native ignored leaders are hidden; sidebar counts are Fareverly's totals before local ignores. Cursor pagination loads further pages while scrolling, including pages hidden entirely by ignores. Browsing refreshes roughly every ten seconds while visible, backing off after failures.

## Join requests

Requesting fetches the latest listing before sending one private protocol message. Requests, responses, and cancellation use native game whispers; there is no HTTP request inbox. Native invitations use the game's account-ID invitation method, which supports players on other zones/instances in the same region. The requester still accepts the normal game invitation.

Requests expire after five minutes. Duplicate pending requests are suppressed, with a ten-second repeat cooldown, but distinct requests/invitations have no artificial cap or slot reservation. Joining/changing parties cancels outgoing requests even with the window closed. Closing a listing resets its inbox and notifies pending requesters. Incoming requests use timestamped native chat alerts containing the name, class, and level. Declines and unavailable groups also notify the requester. Request/Cancel buttons stay in place; only errors appear in the window footer.

## Presence and reliability

Group Finder and Marketplace independently send the same `POST /api/v1/marketplace/heartbeat` body containing only the connected server. Both honor the account-wide 60-second limit and `Retry-After`; either accepted heartbeat maintains the shared 180-second presence. Heartbeats run while logged in, regardless of listings or window visibility. There is no elected owner, mod dependency, separate Group Finder heartbeat, or per-listing renewal. A rate-limit response is not treated as proof of presence on the current region: listing creation is still validated by Fareverly.

HTTP/TLS and authentication run on a worker thread, with bounded responses and timeouts. Creates use UUID idempotency keys; retries retain the same payload/key after uncertain responses. Edits/party updates use revision checks and reconcile conflicts. Stale callbacks cannot update a new client session; a late/abandoned create is resolved and closed using its original credential. Cleanup retries are bounded below the API's seven-day idempotency retention. Sudden process termination relies on shared presence expiry.

Install the **complete ZIP**, including `hlx/plugins/group-finder/group_finder_desktop.hdll`, using Vortex or extract into the game folder. Requires HLX Core 0.0.8+, Better Mod Settings, and Mod Update Alerts. No sample listings or simulated requests are enabled in production.

## Build and verification

Haxe 4.3.7 and `hlx-runtime` are required. Run `haxe test.hxml`, then `haxe compile.hxml`. Build the Windows login plugin with `bash native/build.sh` (MinGW x64). CI packages the mod and desktop plugin together. Tests use injected in-memory APIs; they do not post listings or send messages to live players. Cross-client delivery and actual account login still need an in-game check.
