# Farever Item Utilities

[Builds](https://github.com/xWink/farever-mods/actions/workflows/build-item-utilities.yml) · [Releases](https://github.com/xWink/farever-mods/releases?q=item-utilities&expanded=true)

A collection of inventory, bank, equipment, and item-safety quality-of-life tools for Farever.

## Installation

### Easy Installation
1. Download the mod with Vortex on [NexusMods](https://www.nexusmods.com/farever/mods/9)!

### Manual Installation
1. Install HLX Core.
2. Install the Farever ImGui plugin.
3. Download the latest release or successful build artifact.
4. Install [Better Mod Settings](https://github.com/xWink/farever-mods/tree/main/better-mod-settings)
5. Install the ZIP with Vortex, or extract it directly into the Farever game directory. The archive already contains:
   `hlx/mods/item-utilities/`
6. Launch Farever.

## Features

### Hold interact to quick-loot

Enable **Hold interact to quick-loot** under **General** in Better Mod Settings,
then hold your interact button while looking at dropped items to pick them up
without repeatedly pressing the button. It uses your configured keyboard or
controller binding and the game's normal item targeting, pickup range, checks,
and repeat delay. Releasing the button stops quick-looting.

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

At login, locks are restored after the character finishes loading. An item with
a unique matching identity can regain its lock even if its inventory or equipment
slot changed. Ambiguous or temporarily missing locks remain saved for later
restoration.

Manually re-locking an item reuses a matching unresolved record when its saved
slot or unique item match identifies it. Separate identical items retain their
own locks. Existing duplicate saved records are not automatically deleted.

Locking visuals can be hidden without disabling or deleting saved locks. The settings menu also includes a separately confirmed **Delete all saved locks** action.

An optional **Sorting ignores locked items (but is slower)** setting keeps
every locked item in its exact inventory slot while sorting the unlocked items
around it.

### Instant mote conversion

Enable **Instant Mote Conversion** in Better Mod Settings to complete elemental
motes without the use animation's wait. Each **Complete** action requests one
conversion using the game's normal recipe (5 motes into 1 fragment). The game
still checks the ingredients, inventory space, and combat restrictions, and the
result arrives after the server responds. This setting is off by default and
applies only to motes.

### Equipment presets

Adds three equipment preset buttons and a **Set** button beside **Appearance** on the Character Profile page. These controls are hidden while Appearance is open.

- Preset 1 is selected by default for a new character.
- Select a preset and press **Set** to save the currently equipped weapons, head, neck, shoulders, chest, back, both rings, hands, waist, legs, feet, and trinket.
- Pressing a configured preset equips its saved items into their original slots, using items from the character inventory or another equipment slot.
- Activating an unset preset does nothing.
- If one or more saved items are missing, available items are still equipped and missing entries are skipped. Empty slots are left unchanged.
- Presets and the currently selected preset are persisted separately for each character.

Each preset can also be assigned its own configurable keyboard shortcut, including Ctrl, Shift, Alt, or Windows-key combinations. Preset hotkeys work without opening the Character Profile page.

Existing weapon presets remain usable. Press **Set** again on each preset to include your current armor and accessories. Equipment changes follow the game's normal restrictions.

### Settings

Available settings include:

- Enable or disable Item Utilities
- Hold interact to pick up the dropped items you look at
- Show or hide bank and Recycler deposit buttons
- Show or hide item-locking visuals
- Keep locked items in their exact slots while sorting
- Complete motes without the use animation's wait
- Delete all saved locks
- Configure or clear hotkeys for equipment presets 1–3
- Change the settings-menu hotkey

## Requirements

- [HLX Core](https://github.com/hlx-framework/hlx-core)
- The Farever ImGui plugin used by HLX mods with overlay interfaces

## Building for development

Install Haxe 4.3.7, HLX Runtime, and `hl-imgui`, then run:

```sh
cd item-utilities
haxe compile.hxml
```

The compiled mod is written to:

```text
build/item-utilities/item-utilities.hl
```

Run the quick-loot and lock-restoration regression tests (Haxe only; no running game required):

```sh
haxe test.hxml
```
