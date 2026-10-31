# Combat presentation

Checked against the supplied October 1 Live `hlboot.dat` (HL6), SHA-256
`617f602066c762869d5c15a01c83714664b0026868f0d24b129bbcc850da88d8`.

## Damage suppression

`ui.comp.DamageDisplay.display(DamageResult, VectorImpl)` already returns null
when the native damage-number visibility flag is false. The mod uses the same
return for its disabled-numbers option. `ent.Unit.rpcReceiveDamage__impl`
ignores this return; the damage RPC itself is not skipped. Incoming numeric
damage uses `ui.hud.EffectsFeed.displayDamage`, which only creates/stylizes a
feed row and can also be skipped. The same option now suppresses healing:
`ui.comp.HealDisplay.display(DamageResult, {x:Float,y:Float,z:Float})` already
returns null when native number visibility is disabled, and
`ent.Unit.rpcDisplayHeal__impl` ignores the returned display. The mod returns
null through the same presentation boundary. Received/self healing uses
`ui.hud.EffectsFeed.displayHeal(DamageResult):Void`, which only creates/styles
a feed row and is skipped separately. Its fancy-styling postfix also checks
the hiding option because HLX still runs postfixes after a skipped call; it
must not restyle a previous healing row. Combat notifications and actual healing
continue normally. Both new targets are callable (static display companion and
instance displayHeal prototype), and their native signatures are preserved.

## Allied minion bars

Overhead `ui.hud.FoeWidget` contains `ui.hud.FoeCombatInfo.healthBar`, an
instance of `ui.comp.HealthBar`. Filtering bar components keeps other widget
indicators intact. Temporary summons also create a separate
`ui.comp.AttributeBar(unit, "Lifetime")` in `FoeCombatInfo`'s `main-bar` container.
The Almaz staff's `Staff_SummonDemon_Skill2` summons `Summon_Imp` for 12 seconds;
its lifetime bar bypassed the original HealthBar-only hook. The AttributeBar
initializer now attaches only bars whose native `atbId` is `Lifetime` to the same
visibility filter. Other attribute bars are excluded. Classification requires an
`ent.Foe` with a
`summonOwner`, the local hero's layer, and native `isEnemy(hero) == false`. The local hero's own summons are excluded.
Player/party bars and health bars outside an overhead FoeWidget are excluded.

The refresh callback belongs to the parent widget, which remains active when
its health component is hidden. The visibility hook remembers later native
visibility requests so disabling the setting restores the intended state.
Ownership/hostility refresh is capped at five checks per second per bar, and
disabled, unfiltered bars return without native lookups.

`CombatUiTest` exercises production visibility code with native adapters in
both the interpreter and HashLink. It covers visibility restoration,
hostility/ownership changes, excluded bars, and Combat settings descriptors.
Native mod compilation also passes. Multiplayer minion presentation needs
in-game testing.
