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
   recipient, native skill identity and step within the bounded correlation window.
   Equal-sized repeated casts/ticks are not deduplicated against one another.
2. Capture the meter-owned fight destinations when evidence arrives. Delay
   archiving until its pending evidence settles; do not resolve against the current
   phase later. No native hit/skill objects are retained after the hook returns.
3. Match a unique positive HP change in either arrival order. Multiple candidate
   heals, multiple gains, or intervening losses make individual actual healing
   unknown. Consume an ambiguous gain once; never also create a regen entry for it.
4. If isolated and full throughout the observed window, an unchanged full-health
   target can imply zero effective healing. This remains an inference. Forced
   shutdown/overflow flushes never assume a full observation window elapsed.
5. Without an exact result, show the native calculation as estimated output.
   Observed recovery can raise this estimate. If no calculation is available,
   retain the spell with unknown output, or the observed gain as a lower bound.
   Do not use a historically largest critical heal as every subsequent heal's size.
6. Unmatched positive combat HP is `Regen / unattributed`, recorded on its
   recipient. It may be ordinary regen, an unobserved spell, leech or a correction.
   The client does not provide enough evidence to divide these conclusively.
7. Remote visual events do not establish crit/non-crit. Count critical rates only
   from exact results; persist counts describing estimation and missing evidence.

Queues are event-driven, processed at most ten times per second, and bounded to
128 recipients and 64 heal/health entries per recipient. There is no per-frame
roster/HP scan. Scope holds are released on merge, expiry, pressure and reset.

## Validation

Regression tests cover both FX/RPC orders, both HP/FX orders, remote self-heals,
remote-to-remote healing, status instigators, summon ownership, simultaneous
healers, prediction/spawn exclusion, full overheal, intervening damage, missing
formulas, exact-notification precedence, history persistence, phase transitions,
queue pressure and shutdown. These are deterministic model/bridge tests; the
native hooks still need multiplayer verification in the running game.
