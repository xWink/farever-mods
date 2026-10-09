# Farever Minimap

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=minimap%2F&expanded=true)

A compact overworld minimap with a centered player arrow.

Targets the September 30 Live client. Requires HLX Core 0.0.8 or newer.

## Installation

**Required:** HLX Core, [Better Mod Settings](https://www.nexusmods.com/farever/mods/10), and [Mod Update Alerts](https://www.nexusmods.com/farever/mods/17). A missing dependency shows a desktop error naming what to install and closes Farever before this mod starts.

Install the **complete archive**, including the `implementation/` subfolder. Missing or mismatched implementation files also stop startup with a reinstall message.

### Easy Installation

1. Download the mod with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/15).

### Manual Installation

1. Install [HLX Core](https://www.nexusmods.com/site/mods/2118?tab=files) in your Farever game folder.
2. Download the latest successful [build artifact](https://github.com/xWink/farever-mods/actions/workflows/build-minimap.yml).
3. Extract the ZIP into the game folder. It contains `hlx/mods/minimap/minimap.hl`, `implementation/minimap.hl`, and `configFormats.json`.
4. Install [Better Mod Settings](../better-mod-settings/) (required) for in-game controls, then fully restart Farever.

## Highlights

- A square or circular minimap using Farever's own map artwork.
- Follows your position an arrow showing your character's facing direction.
- Fixed orientation, character-following rotation, or camera-following rotation.
- An outlined N and compass needle track north along the minimap edge.
- A server-synchronized Rift countdown above the map, with inactive, next, active, and open portal markers.
- Red-purple Rift alerts during the final 15 minutes and while the portal is open, including an arrow when the destination is off-screen.
- Adjustable zoom, size, and transparency.
- Marker scale slider resizes icons and all arrows together.
- Left or right corner placement (right by default) with X/Y offsets from 0–100% in 1% steps.
- Directional player arrows and markers for enemies, resources, NPCs, obelisks, and respawn points.
- Party members are larger gold arrows. An option hides everyone outside your party.
- Gold edge arrows point toward party members who are off the map, in the same style as Rift alerts.
- Distinct icons for Guild Merchants, Glory Merchants, Demon Huntresses, and crafting, upgrade, recycling, and infusion stations.
- Soulstone summoning circles with rune-ring and crystal markers.
- Unopened treasure chest, uncollected secret orb, and activity markers.
- Hide completed activities while keeping ascensions and dungeons visible, with separate options to hide either.
- Independent enemy filters for Codex XP completion, full mastery, and target dummies.
- Companion markers with an option to hide variants already in your collection.
- Yellow-ringed edge arrows guide you toward uncollected sparkling companions when their markers are out of view.
- Yellow rings highlight elite enemies and sparkling enemies and bosses.
- Individual plant and ore type filters.
- Hover over markers or guidance arrows to see their name, horizontal distance, and relative height below the map.
- Optional vertical-distance filter hides map markers above or below a chosen threshold while keeping guidance arrows available.
- Category buttons along the right side of the map use the same marker icons. On a circular map they follow the curve of the edge. The map sits further left so the buttons stay on screen. Left-click turns that category on or off. Right-click a button for that category's options. **Show category buttons** in General is on by default.
- Hover the mouse over the map and scroll to zoom.
- Up/down arrows show markers more than 15 metres above or below you.

The minimap covers the overworld and hides in other instances. Live player, enemy, gatherable, and chest markers are limited to entities currently sent to your client. Harvested plants and ore disappear until they respawn. Opened or inactive chests are hidden; secret orbs remain marked after discovery and disappear only once collected by the current character.

| Marker | Appearance |
| --- | --- |
| Your character | Flat ivory arrow |
| Other players | Light-blue arrow showing facing direction |
| Party members | The same light-blue arrow with a purple outline following its shape |
| Friends | The same light-blue arrow with a yellow outline following its shape |
| Off-screen party members | Gold edge arrow pointing toward them |
| Plants | Green leaf |
| Ore | Gray stone |
| Enemies | Red circle; larger for bosses; thick yellow ring for elites and sparkling variants |
| Target dummies | Tan practice dummy on a wooden cross, with a red bullseye |
| Companions | Green pawprint; thick yellow ring for sparkling variants |
| Activities | Purple square with a white four-point star |
| Ascensions | Gold device with a bright cyan core |
| Dungeons | Stone doorway with a purple and cyan portal |
| Inactive Rift | Grey closed fissure with branching cracks |
| Next Rift | Purple-magenta closed fissure at the next location while the timer is above 15:00 |
| Active Rift | Round magenta-purple energy ball at the next location when the timer is 15:00 or less |
| Open Rift Portal | Larger jagged pink tear with a dark interior |
| Unlocked respawn points | Stone basin filled with bright cyan-blue water; hover label **Respawn Point** |
| Undiscovered respawn points | The same basin with an empty stone floor; hover label **Respawn Point (Undiscovered)** |
| Obelisks | Broad grey stone idol with a split crown and gold inlays |
| Soulstone summoning circles | Purple rune ring surrounding a pink faceted soulstone |
| NPCs | Yellow circle |
| Guild Merchants | Yellow $ |
| Glory Merchants | Tilted copper-gold Glory Token with an embossed rune |
| Demon Huntresses | Purple horned face |
| Spark Recycler | Three curved, folded teal arrows forming the classic recycling loop, with a dark outline and transparent centre |
| Weapon Upgrade | Grey stone forge with gold studs and a bright multicoloured flame |
| Crafting Station | Boat-shaped wooden workbench with cyan bottles, a scroll, and a hanging rune sign |
| Infusion Crucible | Stone basin with turquoise liquid, a copper rim, and a floating pink orb |
| Soul Well | Dark stone basin with hooked horns, a magenta spiral, and a floating pink crystal |
| Abandoned chests | Brown wooden chest with dull metal bands and a brass lock |
| Vault chests | Red chest with gold bands, a keyhole, and a diamond crest |
| Recipe chests | Burgundy pouch with cream parchment scrolls; hover label **Recipe Chest** |
| Uncollected secret orbs | Gold orb with an ivory centre and broken purple rings |

**Show NPCs** also controls the Guild Merchant, Glory Merchant, Demon Huntress, and station icons. NPC markers draw in front of all other map elements. All player markers, including your character arrow, draw behind other marker types so crowds cannot obscure them. Party markers draw above other players and still behind the map. **Show chests** and **Show secret orbs** are separate options in the **Markers** section.

**Hide players outside your party** is off by default, directly under **Show other players**. When it is on, only heroes in your group are drawn. Solo play, or a missing group, hides every other player. **Show other players** still hides every on-map hero when it is off, including party members.

**Party direction arrows** is on by default. Each living party member the client has a position for gets one gold guidance arrow on the minimap edge while they are outside the view. The arrow uses the Rift alert shape, points toward that member, and disappears once their marker is on the map, including when **Show other players** is off. Several members produce several arrows. Hover shows that member's name, distance, and height. There is no arrow when the client has no coordinates for them, or when they are removed or dead.

On the map, party member arrows have a purple outline and friends outside the party use the same yellow as sparkling markers. Both outlines follow the arrow's edges and rear notch. Party membership takes priority over friendship. Friends are matched by account ID using the native friend list and refresh with the live markers. **Show other players** controls ordinary and friend markers; party markers follow **Hide players outside your party** and still hide when **Show other players** is off.

Respawn point markers use a broad oval stone platform and a tall shouldered monument with a gold-rimmed purple inset, matching the world model. Their water and hover label follow the current character's unlock progress and update after activation. **Show respawn points** controls both states; marker scaling, hover distances, and vertical filtering apply to both. Obelisks keep their separate icon.

All three chest markers use flat, front-facing geometry without glow. Vault and recipe chests follow the game's native definition ancestry, independent of translated names; other chests use the wooden chest icon. **Show chests** controls all three, with the same opened/hidden checks, distance details, marker scaling, and vertical filtering. Recipe chest hover names always read **Recipe Chest**. Elite enemies use the same thick yellow ring as sparkling enemies. **Always show elite enemies** keeps those elites on the map when **Show enemies** is off, including beyond the nearby radius. A unit counts when it has the native Elite flag without also being a boss or miniboss, or when its unit id (then its English name) is a known world elite. Sparkling companion alerts still require the Spark flag.

Glory Merchants are identified by the dedicated merchant unit (`TODO_MOG_Merchant`), with service-title and Glory-price checks as fallbacks; Infusion Crucibles use the new client's native station type. Both appear automatically wherever those services exist, with the same hover distances, height indicators, and vertical filtering as other NPC markers. A live NPC's resolved definition can replace a generic map definition. Their definitions and icon geometry are cached.

Soul Wells use the game's `Soulwell` definition ancestry to distinguish them from Spark Recyclers, which share their station type. Their flat marker matches the horned stone basin and magenta vortex; **Show NPCs** controls them alongside other stations. Rumi (`DemonHunterRumi`) uses the same burgundy hood and swept purple horns marker as Mira and Zoey, independent of translated names. The Infusion Crucible marker shows its stone pedestal, copper dish and rings, and floating multicolored orb. Static NPC markers respect release status, disabled/hidden definitions, and world-event availability; loaded NPCs supply their current position and visibility. These markers keep the same hover, height, and scaling behavior.

Hover details are always enabled. The marker name stays on the first line, with a smaller, dimmer second line such as **↔ 42 m · ↑ 18 m**. The double horizontal arrow marks horizontal distance; the up/down arrow shows height above or below your character. Measurements round to whole metres and refresh five times per second. A height that rounds to zero reads **↕ 0 m**; unknown elevation is omitted. All arrows are drawn geometry, so no font glyph support or language fallback is needed. Arrows and numbers fit the available width together, independently of the name. Rift, party, and sparkling companion guidance arrows show measurements to their destination, not to the edge of the minimap.

**Hide vertically distant markers** is off by default at the bottom of **Markers**. The **Vertically distant threshold** slider below it ranges from **15 to 100 metres**, in one-metre steps, defaulting to **15**. When enabled, it hides map markers more than that distance above or below you; markers exactly at the threshold remain visible. It applies across all marker categories, including resources, enemies, players, landmarks, and activities. Unknown elevations stay visible. **Rift and sparkling companion guidance arrows remain available**, including when their destination's map marker is hidden by this filter. Party direction arrows stay available for members who are off the map.

Secret orb tooltips always read **Secret Orb**. Sparkling companion alerts disappear whenever any part of the companion marker is visible, and reappear when it leaves the map. This follows zoom and rotation for both map shapes. Alerts still work when normal companion markers are disabled. Their alert arrows are solid yellow triangles, distinct from player arrows. Both sparkling companion markers and their alert arrows have yellow rings with transparent centres, letting the map show through around the pawprint or triangle. Their alert rings have no height arrows; ordinary markers retain their height indicators.

**Show north indicator** is on by default in **General**. The north indicator stays at the top of a fixed map and follows north around the edge of a rotating map. It scales with the other markers. Compass and alert geometry is cached; movement updates only their transforms and visibility. Turning it off also frees its edge space for sparkling companion alerts.

**Show clock/timer** follows the north setting in **General**, with dropdown options **None**, **Rift timer**, and **Clock**. **Rift timer** is the default; upgrading preserves the previous checkbox preference, with an unchecked **Show Rift timer** becoming **None**. **Clock** displays the computer's local time in 24-hour `HH:MM` format. Install the accompanying Better Mod Settings update for dropdown support.

Both visible modes use the game's explicit bold 16-pixel font with a dark shadow, and sit above the minimap with a slightly larger gap than the hover caption. The font stays consistent regardless of which HUD elements finish loading first. The `mm:ss` Rift countdown uses the native Rift event timer when available, otherwise the game's Rift frequency and synchronized server clock. A local top-of-the-hour fallback is used only if native timing is unavailable; fallback time never supplies a guessed portal location. The countdown advances to the next Rift when the current one opens.

Rift locations follow the replicated event's selected portal. Before the event is announced, the upcoming marker uses the same candidate order, event-time seed, and isolated native random generator as the game's own Rift selection. Open portals use the live event state and disappear when the portal closes. If consecutive Rifts choose the same location, the open icon takes precedence over the upcoming icon. All four Rift marker states draw in front of enemies and bosses. Rift markers follow **Show activities**, but completion filters never hide them.

Other known Rift locations appear as grey closed fissures with branching cracks, with the hover label **Inactive Rift**. Each location has just one marker: the selected location uses **Next Rift** above 15:00, **Active Rift** at 15:00 or less, and **Rift Portal** while open. Other locations use **Inactive Rift**. An open portal takes precedence if the next event selects the same location. **Hide inactive Rift locations**, in **Activities**, defaults to off and hides only the inactive markers. Static locations are cached and never generate Rift alert arrows.

With **Rift alerts** enabled (the default), both the clock and countdown turn red-purple when **15:00** or less remains before the Rift, and stay that colour for as long as the portal is open. Disabling alerts restores the normal text colour. A matching solid red-purple triangle without a ring or height indicator points to the Active Rift, then continues pointing to that portal until it closes, even though the countdown already shows the next Rift. The arrow disappears whenever its target marker enters view, including partial visibility. This follows zoom, rotation, and both minimap shapes. Alerts work independently of the selected clock/timer mode, including **None**, and can still guide you when activity markers are disabled. Definitions, selected locations, and icon geometry are cached; native event state is sampled five times per second and text changes only when its displayed value or colour changes. These features only read game state and do not send server commands.

**Show soulstone summoning circles** is on by default in **Markers**. These landmarks use the world's element definitions and identify interactions that consume an item of type **Soulstone**. They remain visible without a soulstone in your inventory and are independent of activity-completion filters. Locations and elevation come from the native world prefab; definitions and icon geometry are cached.

**Show in left corner** defaults to off, placing new installations on the right. Existing saved corner preferences are preserved.

**X offset %** and **Y offset %** are in **General**, both defaulting to **0%**. X moves right from the left corner, or left from the right corner; Y always moves down. **50%** centers the minimap on that axis. **100%** reaches the opposite screen edge with the same 24 UI-pixel margin as the starting edge, including the map's border. Position updates with minimap size, window size, and UI scale. Both map shapes and their hover/zoom controls move together.

The **Activities** section includes **Show activities**, **Hide completed activities** (on by default), **Hide ascensions**, **Hide dungeons**, and **Hide inactive Rift locations** (all three off by default). Completed ascensions and dungeons remain visible unless hidden with their own option. **Show activities** controls all activity markers, including Rifts. Ordinary activities follow **Hide completed activities**; Rifts follow their current event state instead. Markers use the game's world-map locations, including overworld entrances for instanced activities.

**Hide mastered Codex enemies** filters at each enemy's final Codex mastery threshold. **Hide partially completed Codex enemies** filters at the Codex XP-reward milestone. Both options are in **Enemies** and default to off; existing saved preferences are preserved. To keep enemies visible until full mastery, turn **Hide mastered Codex enemies** on and **Hide partially completed Codex enemies** off. If both are enabled, the earlier completion milestone hides the marker. Both filters read the game's thresholds for normal, large, elite, and boss enemies and compare them with the current character's kill count.

**Hide target dummies** is off by default in **Enemies**. Dummies have their own marker and use the game's native Dummy group, independent of their names or Codex progress. **Show enemies** controls them too. The former **Hide enemies without Codex entries** option has been removed; its old saved value no longer hides anything. Other enemies without Codex entries stay visible.

Settings use HLX's native persistence at `hlx/config/minimap/config.json`. Better Mod Settings and Mod Update Alerts are mandatory dependencies.

## Map loading

Map textures use the game's asynchronous image-loading path when their format and backend support it, with the native synchronous fallback otherwise. The minimap keeps at most two requests outstanding, prioritizes visible tiles, and prepares up to four adjacent tiles within its existing cache allowance. It finalizes at most one tile and attaches at most one bitmap per update. Tiles are displayed only after the full texture is ready, avoiding stretched loading placeholders. Shared native textures are never disposed by the minimap, and outstanding native loads cannot attach to a disposed map. This behavior is automatic; it does not require More Settings or its performance option. Unsupported image formats and individual GPU uploads may still do synchronous work.

## Building

Use Haxe 4.3.7 and the HLX runtime:

```sh
haxelib git hlx-runtime https://github.com/hlx-framework/hlx-core.git main hlx-runtime/src
cd minimap
haxe compile.hxml
```

Run the marker classification, party roster, activity visibility, hover measurements, vertical filtering, Rift schedule/state, Codex milestone, percentage-position, clipping, and compass regression tests with `haxe test.hxml` (no game or HLX runtime required).

Output: `build/minimap/minimap.hl`. The independent workflow packages this project and publishes releases for `minimap/v*` tags.
