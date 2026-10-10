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
3. Match HP gains in either arrival order. Allocate each gain once among heals
   in the nearest event burst (within 120 ms of the nearest candidate), weighting
   by remaining output. Exact results cap the amount a heal can receive; FX-only
   size estimates can be raised by observed recovery. Surplus/unmatched gains
   remain unattributed. Shares are estimates, not authoritative per-caster values.
   Several updates can contribute to one heal. A distinct negative HP update does
   not erase an observed positive update. Damage and healing merged into one net
   decrease cannot be recovered by this method.
4. A full-health snapshot without an assigned gain can imply zero effective
   healing, unless a loss in the same event burst or lost queue context prevents
   that inference. Other full-health healers do not automatically invalidate it.
   Forced shutdown/overflow flushes never assume an observation window elapsed.
5. Without an exact result, use the native calculation as estimated output.
   Observed recovery can raise this estimate. If no calculation is available,
   retain the spell with unknown output, or the observed gain as a lower bound.
   Do not use a historically largest critical heal as every subsequent heal's size.
6. Unmatched positive combat HP is `Regen / unattributed`, recorded on its
   recipient. It may be ordinary regen, an unobserved spell, leech or a correction.
   The client does not provide enough evidence to divide these conclusively.
7. Remote visual events do not establish crit/non-crit. Count critical rates only
   from exact results; persist counts describing estimation and missing evidence.
8. Display plain numbers without tilde/lower-bound/partial decorations. If any
   actual-healing observations are missing, display `Unavailable` rather than the
   surviving subset. This also prevents older incomplete logs from claiming the
   character healed only 115 HP, or zero. Missing observations were not stored as
   raw events, so historical undercounts cannot be recalculated retroactively.

Queues are event-driven, processed at most ten times per second, and bounded to
128 recipients and 64 heal/health entries per recipient. There is no per-frame
roster/HP scan. Scope holds are released on merge, expiry, pressure and reset.

## Validation

Regression tests cover both FX/RPC orders, both HP/FX orders, remote self-heals,
remote-to-remote healing, status instigators, summon ownership, simultaneous
healers, continuous healing ticks, proportionate sharing, multiple HP updates,
nearest-burst selection, prediction/spawn exclusion, full overheal, intervening damage, missing
formulas, exact-notification precedence, history persistence, phase transitions,
queue pressure and shutdown. These are deterministic model/bridge tests; the
native hooks still need multiplayer verification in the running game.
