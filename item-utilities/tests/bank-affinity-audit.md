# Bank affinities and Inspect positioning

Audited `hlboot(20261007-191837).dat`, HashLink bytecode 6.

- `BankWindow.setTabInfo` (f26530) opens `BaseUI.displayTextInputDialog`
  (f3148) only when the clicked key equals `currentTab`. A scoped prefix/postfix
  captures that returned dialog; ordinary text dialogs and tab switches do not
  create the companion. The panel is an absolute child of that same dialog, so
  it shares its input/modal ancestry and disappears when the dialog is removed.
  `BaseWindow.__constructor__` (f4149) calls `autoDisplay` before returning;
  the companion suppresses that call during its own construction, then clears
  window flags and its independent binding layer before attachment. Otherwise
  `BaseUI.displayWindow` closes the bank before later flag changes can help.
  Failed panel initialization removes partially built UI and restores the
  rename dialog's overflow. Checkbox opacity writes the native `alpha` field;
  `h2d.Object` has no `set_alpha` member.
- `BankWindow.getInventory` (f26527) resolves `hero.loadout.banks[bankId]`.
  `initTabs` (f26529) uses the account's bank-tab index. Rename (f9960) validates
  that index against `loadout.owner.player.accountProgress.bankTabs`.
  Preferences therefore use persistent player/account UID plus tab index,
  independent of the editable tab name and replicated object UIDs.
- Inventory-slot right-click closures f30678/f30679 call
  `Loadout.checkRequestTransfer` / `requestTransfer`. Both hooks resolve the
  same affinity destination and re-enter the native method only when it changes.
  The second entry is idempotent. Native transfer validation, transactions,
  callbacks and partial-stack behavior remain responsible for moving the item.
- Utility buttons retain their existing serialized `Inventory.requestTransfer`
  queue; destination-slot, stack-capacity and free-slot lookups all use the
  affinity inventory. Full or unavailable affinity tabs cannot fall back to the
  selected tab. No bank selection, inventory content or server state is written
  directly. Existing locked/junk item guards remain in place.
- Disjoint affinity categories use native `Item.isType` inheritance: food is
  separate from consumables; demon enchantments from other augments; crafting
  and upgrade components share Components. Remaining kinds use Miscellaneous.
- Inspect header dragging uses native `Interactive.startDrag`, root-local mouse
  coordinates, viewport clamping and config persistence on release/disposal,
  following the existing Ready Check drag path. Its close button and model
  interaction area are outside the drag surface.

Regression tests cover config round trips/conflicts, account changes, inherited
item types, unavailable/full destination routing, non-bank actions, and rename
dialog scoping under both the interpreter and HashLink. Native game rendering,
mouse behavior and actual server transfers still need in-game verification.
