# Equipment preset arsenal selections

Verified against the supplied 2026-10-21 `hlboot.dat`:

- `ArsenalEdition.confirmSelection` invokes
  `HeroSpecialization.setArsenalSkills(item.kind, selectedSkills)`.
- `getArsenalSkills(weaponId)` reads `specialization.arsenals[weaponId].skills`
  without creating a record. Missing selections return an empty native array.
- `ArsenalEdition.init` and the server setter both use
  `Weapon.isValidArsenalSkill`. This includes weapon active skills and passives;
  unrelated skills and the weapon's secondary action are excluded.
- The setter enforces `Hero.getNbArsenalSkillSlots()`, updates the replicated
  selection, and refreshes matching equipped items. Its public wrapper is an
  owned-object RPC with no acknowledgement callback. Never call `__impl` or
  modify replicated arrays on the client.

Presets capture choices for equipped weapon kinds, deduplicated by kind, and
preserve explicit empty selections and order. Old presets without `arsenals`
leave selections alone until re-saved. Loading the equipment-preset records
preserves the new field; it remains part of the existing per-character reset.

Equipment transfer replies precede arsenal restoration. Only successfully
equipped or already-matching weapons qualify. No equipment snapshot is assumed
fresh in a transfer callback: replication can arrive later. Arsenal requests
run serially, checking replicated selections every 50 ms while active, with a
five-second timeout. Character/session changes, disabling the mod, closing the
character UI, or resetting equipment presets cancel pending work.

`ArsenalPresetTest` covers save/reload, migration, order, empty choices, invalid
IDs, native slot limits, delayed replication, timeout, manual changes, and
cancellation. The separate HashLink host/plugin test exercises production
request construction with host-owned strings and arrays, confirming that the
native selection is copied rather than mutated and the resulting array can be
passed back into a typed host function.
