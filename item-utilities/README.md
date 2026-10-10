# Farever Item Utilities

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-item-utilities.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=item-utilities&expanded=true)

A collection of inventory, bank, character preset, and item-safety quality-of-life tools for Farever.

Lock icons, lock editing, preset controls, and bank/Recycler buttons are native
children of their corresponding game windows. Tooltips and foreground windows
cover only the overlapping portion, while inventory scrolling clips icons and
click targets normally. The controls follow the game's UI position and scale,
and covered portions cannot intercept clicks through foreground native UI.

## Installation

**Required:** HLX Core, [Better Mod Settings](https://www.nexusmods.com/farever/mods/10), and [Mod Update Alerts](https://www.nexusmods.com/farever/mods/17). ImGui is not required. A missing dependency shows a desktop error naming what to install and closes Farever before this mod starts.

Install the **complete archive**, including the `implementation/` subfolder. Missing or mismatched implementation files also stop startup with a reinstall message.

### Easy Installation
1. Download the mod with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/9)!

### Manual Installation
1. Install HLX Core.
2. Install [Mod Update Alerts](https://www.nexusmods.com/farever/mods/17).
3. Download the latest release or successful build artifact.
4. Install [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings)
5. Install the ZIP with Vortex, or extract it directly into the Farever game directory. The archive already contains:
   `hlx/mods/item-utilities/`
6. Launch Farever.

## Features

### Inspect players

Hold Interact on another player and choose **Inspect**, immediately below
**Send message**. The native window shows their equipped weapons, armour, and
accessories, with item icons, rarity colours, and the game's item-detail tooltips.
You can also choose **Inspect** from a player's gear menu in the Social window,
including friends, party members, and nearby players. It appears directly below
**Send message**, or first when that action is unavailable.
The taller **Inspecting: <name>** window follows the character page's equipment
column order, with Main Hand, Off Hand, and Arsenal in a separate weapons section.
The inspected hero's model appears between the equipment columns. **Appearance**
switches to their equipped styles, and **Character** returns to equipment.
Slots using their original gear look are labelled **Equipped appearance**.
Hover an item icon to see its details. Comparison tooltips fit both panels within
the screen, including at smaller resolutions; style tooltips omit combat stats.
These are their actual equipped items, independently of cosmetic appearances.
Infusion bonuses and set highlights use the inspected equipment. Arsenal affixes
use the game's slot multiplier (40%); the comparison panel keeps your own gear's
context. These checks use replicated equipment without private player progress.
The window updates when their equipped gear changes and closes with X or Escape.

Inspect is read-only and uses equipment already available to your client. If a
player cannot be inspected, a local chat error explains that their character or
equipment is unavailable. If they leave while being inspected, the window says so. It does not
request private inventory data or provide equip, drag, or transfer actions.
The option is included whenever Item Utilities is enabled.

### Hold interact to quick-loot

Enable **Hold interact to quick-loot** under **General** in Better Mod Settings,
then hold your interact button while looking at dropped items to pick them up
without repeatedly pressing the button. It uses your configured keyboard or
controller binding and the game's normal item targeting, pickup range, checks,
and pickup requests. Holding sends brief presses up to **20 times per second**
(50 ms apart), with a release frame between them, so it avoids the slower native
hold-repeat delay just like manual tapping. Low frame rates can reduce that rate;
lag does not cause queued presses to fire in a burst. Releasing the button stops
quick-looting.

Repeats start only after the game delivers the original Interact press. This
preserves the native client's buffered presses, so enabling quick-loot does not
block NPC or station interactions. Opening a window that blocks gameplay input
also clears the held-repeat state.

The mod filters the game's selected target only during a held-button pickup;
it does not add a nearby-entity scan or change the server's pickup logic.

This setting is off by default. Holding interact only repeats pickups for
dropped items; NPCs, chests, gathering nodes, and other interactions keep their
normal behavior.

### Bank deposit shortcuts

Adds six deposit buttons beside the bank's Sort button:

- **Deposit all**
- **Deposit crafting materials**
- **Deposit food**
- **Deposit consumables**
- **Deposit demon enchantments**
- **Deposit miscellaneous items**

Deposits skip items that do not fit and continue checking the remaining items
for room in existing bank stacks, even when the bank has no empty slots.
The deposit buttons can be hidden from the mod settings.

### Recycler deposit shortcut

Adds a **Deposit all** button beside the Spark Recycler's Sort button. It moves
every eligible unlocked item into the Recycler, skips locked or rejected items,
and stops when the Recycler is full or no eligible items remain.

### Item locking

Adds an item-locking mode beside the character inventory's Sort button. Enable locking mode and click inventory items to lock or unlock them.

Locked items are marked with a small lock icon and are protected from:

- Selling
- Dropping or discarding
- Depositing into the bank
- Placing into the Spark Recycler

Locks follow items as they move between inventory and equipment. They are persisted separately for each character using Farever's unique character ID, with item identity and location tracking to avoid transferring a lock to the wrong identical item.

Targets the September 30 Live client with HLX Core 0.0.8 or newer. Item identity includes the new infusion and infusion bonus stat.
Existing saved locks and presets remain readable. A legacy save without infusion
details will not guess between different infusion variants; select the intended
item and re-save the preset or re-lock it if its identity is ambiguous.

At login, locks are restored after the character finishes loading. An item with
a unique matching identity can regain its lock even if its inventory or equipment
slot changed. Ambiguous or temporarily missing locks remain saved for later
restoration.

Manually re-locking an item reuses a matching unresolved record when its saved
slot or unique item match identifies it. Separate identical items retain their
own locks. Existing duplicate saved records are not automatically deleted.

Locking visuals can be hidden without disabling or deleting saved locks.
**Reset locks** at the bottom of **Locking** asks for confirmation before removing
all of the current character's locks, including unresolved and duplicate records.
Items become unlocked immediately, and other characters' locks are preserved.

An optional **Sorting ignores locked items (but is slower)** setting keeps
every locked item in its exact inventory slot while sorting the unlocked items
around it.

### Instant mote conversion

Enable **Instant mote conversion** in Better Mod Settings to complete elemental
motes without the use animation's wait. Each **Complete** action requests one
conversion using the game's normal recipe (5 motes into 1 fragment). The game
still checks the ingredients, inventory space, and combat restrictions, and the
result arrives after the server responds. This setting is off by default and
applies only to motes.

### Preset controls

All four categories have five slots, labeled **Preset 1**, **Preset 2**, **Preset 3**,
**Preset 4**, and **Preset 5**. The collapsed dropdown shows the selected slot;
choosing a saved option immediately applies it. Empty options remain selectable.
Selecting the current slot again reapplies it. Preset controls have no tooltips;
the selector, menu labels, and **Set** use the game's native button/dropdown styling.
**Set** saves your current setup to the selected slot. Controls are disabled while
that category is applying a preset. The dropdown closes when you choose an option
or click outside; individual hotkeys can apply presets without opening it.
The native dropdown handles input over its options. Closing the menu restores
normal input; leaving the tab, hiding the controls, or opening another window
also closes its list.

### Mark as Junk

Click the trash-bin button beside the inventory lock button to enter junk mode,
then click an item to mark or unmark it. Marked items show a trash bin in their
top-right corner. Lock and junk editing are mutually exclusive; locked items
cannot be junk, and junk must be unmarked before it can be locked.

Junk choices persist per character and match identical current and future bag
items, including their level, rarity, rolled stats, upgrade level, infusions,
weapon effects, and rune identity. Stack size and temporary item IDs do not
affect matching. Different rolls or upgrades remain distinct, and locked copies
stay protected. Unmarking a matching item removes that rule for future pickups.

Weapons, armour, and accessories in your bag can be marked as junk. Marked bag
items cannot be equipped or moved into the bank, including through deposit
shortcuts. Matching items already worn remain unaffected. At a Guild Merchant, click the **Sell all junk** trash-bin button
to the left of the gold count at the bottom of the trade window to sell the inventory's marked stacks.
Sales use the normal game requests and checks, one acknowledged sale at a time.
Changed, moved, newly locked, or unsellable items are skipped. Closing the
merchant, changing character/session, a rejected sale, or a timeout stops the
batch; an already-sent request may still complete.

### Equipment presets

Adds a **Preset 1–5** dropdown and a **Set** button beside **Appearance** on the Character Profile page. These controls are hidden while Appearance is open.

- Preset 1 is selected by default for a new character.
- Select a preset and press **Set** to save the currently equipped weapons, head, neck, shoulders, chest, back, both rings, hands, waist, legs, feet, and trinket.
- Choosing a saved preset from the dropdown equips its saved items into their original slots, using items from the character inventory or another equipment slot.
- Selecting an empty slot changes no equipment; press **Set** to save into it.
- If one or more saved items are missing, available items are still equipped and missing entries are skipped. Empty slots are left unchanged.
- Presets and the currently selected preset are persisted separately for each character.

Each preset can also be assigned its own keyboard shortcut under **Equipment
Presets** in Better Mod Settings. Existing bindings and saved presets in slots 1–3 are retained. Slots 4 and 5
start empty with unbound hotkeys. Preset hotkeys work without opening the Character Profile page.

Existing weapon presets remain usable. Press **Set** again on each preset to include your current armor and accessories. Equipment changes follow the game's normal restrictions.

Saved item IDs can be reassigned after logging in again. Presets verify the saved
item fingerprint (including upgrades, sockets, and infusions) before preferring
an ID match, so another item cannot replace a saved weapon just by reusing its ID.
Existing presets benefit automatically. Re-save after changing an item's saved
properties; a legacy preset missing infusion details cannot choose between
different infusion variants.

### Talent presets

Adds a matching **Preset 1–5** dropdown and **Set** button near the top of the Talents page,
aligned with **Talent Points available** and centered between the root talent
and the description panel. The controls follow the game's UI scale and position.

- Select a preset slot and press **Set** to save the current talent allocation.
- Choose a saved preset from the dropdown or use its **Talent preset 1–5 hotkey** under **Talent
  Presets** in Better Mod Settings to apply it. Hotkeys also work with the page closed.
- Talent presets and the selected slot are saved separately for each character,
  independently of equipment presets. Selecting an unsaved slot changes no talents.
- The complete saved build is checked before changes begin. Missing talents,
  invalid prerequisites, and insufficient points stop application before any refund.
- Changes use the game's normal server-checked talent requests: refund the old
  tree, then allocate the saved ranks from the root upwards. The mod waits for
  each server reply and replicated rank change before sending the next request.
- An already-active preset makes no requests. A saved empty allocation refunds
  all points. Rejected changes, timeouts, manual changes during application, and
  character/session changes stop the sequence.

### Skill presets

Adds a matching **Preset 1–5** dropdown and **Set** button at the far right of the Skills
page's bottom strip, vertically centered and aligned with the current UI scale.

- Select a preset slot and press **Set** to save the four equipped class skills,
  their slot order, their runes, and the runes on unlocked signature skills such
  as the priest's **Judgment**. Signature skills do not occupy a regular slot.
- Mage presets also save **Sparkmaster** conduit choices, including their order
  and empty slots. Press **Set** once to update older presets, which did not
  record these choices. Older saves leave the current conduits unchanged.
- Choose a saved preset from the dropdown or use its **Skill preset 1–5 hotkey** under **Skill
  Presets** in Better Mod Settings. Hotkeys also work with the window closed.
- Presets and the selected slot are saved separately for each character,
  independently of equipment and talent presets. An unsaved slot changes nothing.
- Empty slots and no-rune selections are saved exactly. A preset with one rune
  restores that rune and removes any extra rune from that skill. Multiple runes
  are supported when the game permits them; runes on other skills are left alone.
  Older presets without signature records keep the current signature runes;
  select the desired runes and press **Set** once to include them.
- The saved skills and runes must be unlocked, and changes cannot be applied in
  combat. All checks happen before applying the first change.
- Uses normal skill-slot, rune, and conduit requests, waiting for each server update.
  Rejections, timeouts, unexpected changes, entering combat, and character or
  session changes stop the sequence.

### Appearance presets

Adds a matching **Preset 1–5** dropdown and **Set** button to the left of **Character** in the
Appearance view, following the button's position and the game's UI scale.

**Reset appearance presets** at the bottom of **Appearance Presets** in Better Mod
Settings shows a warning with **Continue** and **Cancel**. Continue deletes saved
appearance presets and the selected slot for the **current character only**.
Other characters' presets, current appearances, hotkeys, item locks, and the other
preset categories are preserved. A logged-in character is required. Update both
mods to use this button.

- Select a preset slot and press **Set** to save the appearance choices for
  all eight armour slots: head, shoulders, chest, back, hands, waist, legs and feet.
- Choose a saved preset from the dropdown or use its **Appearance preset 1–5 hotkey** under
  **Appearance Presets** in Better Mod Settings. Hotkeys work with the view closed.
- Saves the exact choice for every slot: the equipped item's normal appearance,
  a selected cosmetic, or hidden gear. Restoring a default choice clears that
  slot's cosmetic override and follows the currently equipped item.
- Presets and the selected slot are saved separately for each character,
  independently of the other preset categories. Unset presets change nothing.
- The game checks slot compatibility, class aptitudes and unlocked cosmetics
  before any changes begin. Each change uses the normal appearance RPC, waiting
  for both its successful reply and replicated state before continuing.
- Rejections, timeouts, unexpected manual appearance changes, and character or
  session changes stop the sequence.

If an older appearance preset reports **Invalid saved appearance item**, recreate
the desired look and press **Set** on that preset after updating. A previous save
bug lost cosmetic IDs when writing the config; affected presets cannot be
recovered automatically.

### Settings

The **Locking**, **Equipment Presets**, **Talent Presets**, **Skill Presets**, and
**Appearance Presets** sections each end with a red **Reset** button. Each opens a
warning with **Continue** and **Cancel** and affects only the current character
and that category. Cancel or Escape makes no changes. A logged-in character is
required, even when Item Utilities is disabled.

Preset resets delete the saved presets and reset the selected slot to 1. Current
equipment, allocated talents, equipped skills/runes, appearances, and hotkeys stay
unchanged. Any pending application of that preset category stops; requests already
sent to the game may still finish. Other characters and preset categories are
preserved. Use the latest Better Mod Settings for these confirmation buttons.

Available settings include:

- Enable or disable Item Utilities
- Hold interact to pick up the dropped items you look at
- Show or hide bank and Recycler deposit buttons
- Show or hide item-locking visuals
- Keep locked items in their exact slots while sorting
- Complete motes without the use animation's wait
- Reset the current character's locks after confirmation
- Configure or clear hotkeys for equipment presets 1–5
- Configure or clear hotkeys for talent presets 1–5
- Configure or clear hotkeys for skill presets 1–5
- Configure or clear hotkeys for appearance presets 1–5
- Reset each preset category for the current character after confirmation

Preset hotkeys support one Ctrl, Shift, or Alt modifier with Farever-supported
keys (for example, `Ctrl+1`). Update Better Mod Settings to assign combinations.
Existing single-key bindings carry over. Modified and plain preset shortcuts
are matched separately, so `Ctrl+1` does not also activate a preset bound to `1`.

## Requirements

- [HLX Core](https://github.com/hlx-framework/hlx-core)
- [Better Mod Settings](https://www.nexusmods.com/farever/mods/10) (mandatory)
- [Mod Update Alerts](https://www.nexusmods.com/farever/mods/17) (mandatory)

## Building for development

Install Haxe 4.3.7 and HLX Runtime, then run:

```sh
cd item-utilities
haxe compile.hxml
```

The compiled entry module and its matching implementation are written to:

```text
build/item-utilities/item-utilities.hl
build/item-utilities/implementation/item-utilities.hl
```

Run the quick-loot, lock-restoration, layout, native UI lifecycle, and preset regression tests (Haxe only; no running game required):

```sh
haxe test.hxml
```

To test appearance and skill saves with strings owned by a separate game-like module,
use HashLink 1.16 or newer from the same directory:

```sh
haxe test-appearance-serialization.hxml
hl build/appearance-serialization-host.hl
haxe test-skill-serialization.hxml
hl build/skill-serialization-host.hl
```

These additional tests check cosmetic, hidden, and default appearances, plus skill
and rune selections both immediately and after a JSON round trip. The skill test
also checks rune-only changes without changing skill slots. The Haxe interpreter
cannot reproduce cross-module string identity.
