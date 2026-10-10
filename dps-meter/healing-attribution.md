# Healing attribution investigation

Checked against the supplied live `hlboot(20261007-191837).dat` on 2026-10-10.
The observations below come from the current client bytecode, not assumptions
based on another meter's UI. The implementation is independent of Farever Book.

| Evidence | What it establishes | Limitation |
| --- | --- | --- |
| `ent.Unit.rpcDisplayHeal__impl` / `DamageResult` | Caster, skill, recipient, calculated output, critical flag | `rpcDisplayHeal` checks `State.networkAllow` with mode 2, ultimately restricting delivery to the receiver unit's owning player. The receiver can be the caster: the healed unit is `DamageResult.target`. |
| `ent.Unit.playHitHealFX` / `HitData` | Visible healing event, target, skill and instigator | Client `amount` and critical state are not authoritative final results. FX can be absent outside client visibility. |
| `ScriptHitData.get_source/get_instigator` | Status's original `instigator`, otherwise skill owner; resolves proxies | The status owner is often the recipient and must not be credited as its caster. |
| `Status.instigator`, `Status.instigatorSkill` | Original caster/skill links are replicated | Links may be absent while replication is incomplete. Keep the observed status ability when present. |
| `summonOwner`, `summonSourceSkill`, virtual `getSourceSkill/getSourceObject` | Healing minion's owning player and originating ability | Native virtual overrides must be preserved. Ownership traversal is bounded. |
| `HSkill.getStepEffectVal` | Client-side base healing with rank/scaling, dynamic values, applicable stacks and distribution over ticks | Not the final server `evalHeal`, critical roll, or all applied modifiers. Used only for healing effects: `getEffectRange` returns zero for Heal, avoiding the damage path's RNG. |
| Authoritative `UnitAttributes.set_health` | Replicated HP gain/loss | No cause, caster, spell, event ID or overheal. Several effects and damage can share an update. |
| `Unit.combatStats` | Has healing counters in the runtime type | These counters are absent from the unit's serialization schema/network synchronization. They cannot supply remote combat logs. |
| `Unit.receiveHeal`, `Unit.updateRegenerations`, `lastRegenTick` | Where server healing/regen would be applied | First two are throwing `!isServer` stubs in the shipped client; regen tick is not replicated. Do not hook/call these expecting client data. |

## Collection rules

1. Take exact results when delivered. Pair one FX with one result by caster,
   recipient, native skill identity and step within the 120 ms correlation window.
   Equal-sized repeated casts/ticks are not deduplicated against one another.
2. Capture the meter-owned fight destinations when evidence arrives. Delay
   archiving until its pending evidence settles; do not resolve against the current
   phase later. No native hit/skill objects are retained after the hook returns.
3. Retain HP gains only as a lower bound for missing output estimates and to
   distinguish sourced healing from the existing unattributed-recovery bucket.
   Match either arrival order; allocate each gain once within the nearest event
   burst, bounded by exact output when available. Do not expose or serialize
   those internal shares as actual/effective healing.
4. Without an exact result, use the native calculation as estimated output.
   Observed recovery can raise this estimate. If no calculation is available,
   retain the spell with unknown output, or the observed gain as a lower bound.
   Do not use a historically largest critical heal as every subsequent heal's size.
5. Unmatched positive combat HP is `Regen / unattributed`, recorded on its
   recipient. It may be ordinary regen, an unobserved spell, leech or a correction.
   The client does not provide enough evidence to divide these conclusively.
6. Remote visual events do not establish crit/non-crit. Count critical rates only
   from exact results; persist counts describing output estimation and missing evidence.
7. Display plain output/HPS without tilde/lower-bound decorations. No actual-healing
   column, header, bar, effective-healing total, or overheal total is retained.
   Ignore those fields in older logs and strip them when importing/re-encoding.
8. After reconciliation, split outgoing output by caster/recipient identity:
   different UIDs are team healing, equal UIDs are self-healing. Keep HP-only
   recovery and missing recipients unclassified. Credit the full recorded amount
   to the recipient's incoming total once. These totals use the same evidence as
   output; they are not effective healing. Save the split per player/ability and
   incoming totals per fight. Missing fields in older logs remain unavailable.

## Why missing HP cannot reliably determine overheal

`min(healAmount, maxHP - hpImmediatelyBeforeHeal)` would work if the client had
that server-side pre-heal HP for each event. `DamageResult` contains the amount
and target, but no pre-heal HP or effective/overheal result. `receiveHeal` is
server-only; client FX and result callbacks are presentation notifications.
The target's current HP is independently replicated and may already include the
heal, another heal, or damage. `set_health` supplies a state update without a
healing event ID. Pairing those values by arrival time cannot restore a reliable
server ordering. Summing the guessed values compounded that uncertainty, so the
actual-healing feature has been removed rather than recalculated from stale HP.

Queues remain event-driven, processed at most ten times per second, and bounded
to 128 recipients and 64 heal/health entries per recipient. There is no per-frame
roster/HP scan. Scope holds are released on merge, expiry, pressure and reset.
Full-health snapshots and HP-loss evidence used only for effective healing have
been removed.

## Optional live timing experiment

`HealingTrace` observes the proposed pre-heal-HP formula without adding its
effective/overheal values to the meter. It captures exact RPCs even when the
receiver differs from the target, records whether the proposed target-only guard
would reject each event, and captures authoritative HP losses as well as gains.
Sequence numbers and timestamps preserve ordering within one GameApp update.
The trace is disabled by default; see the README for the controlled in-game test.
The 120 ms window is an experimental tuning choice, not a measured timing guarantee.

## Validation

Regression tests cover output preservation, FX/RPC deduplication, both HP/FX
arrival orders, remote self-heals and remote-to-remote heals, status instigators,
summon ownership, unknown formulas and criticals, output fallback, archive/phase
boundaries, queue pressure and shutdown. Tests cover self/team shares, receiving-only
players, unknown-source recovery, incoming totals after FX/RPC deduplication,
selected-player/recap headers, and detached storage. UI tests check the Team/Self
column and full-width layout while retaining damage columns. Serialization tests check
that history, recaps and uploader reports contain no effective-healing fields,
including after importing or re-encoding older logs. Native hooks still require
multiplayer verification in the running game.
