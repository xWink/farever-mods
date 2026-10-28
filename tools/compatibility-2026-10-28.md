# October 28 client compatibility audit

Supplied client: `hlboot(20261028-172516).dat`, HashLink bytecode 6.
SHA-256: `13177583915735b4b5efc6df9fe9a2803565a54a104563914d1ec9c022b029cb`.
Baseline: `hlboot(20261021-162208).dat`, SHA-256
`ebd5728764e1bd5df1345427f195167c4d04b69192e1eed7371b3d36e7e7d8a8`.
The new file parsed completely: 47,445 types and 48,252 functions.

## Changes required

- **More Settings:** `DX12Driver.compileSource` now takes a `RuntimeShader`
  before `RuntimeShaderData`. Both diagnostic contributors must forward all five
  arguments, including the receiver. The return remains ordinary `haxe.io.Bytes`,
  not a raw pointer. The native hook regression now checks the generated
  receiver's argument count and preserves both byte and null results through
  disabled, enabled, gameplay and background-thread calls.
- **More Settings:** `ChunkGround.needRefresh` became the inverse `ready` flag.
  The terrain composition cache must not reuse/capture a result while ground is
  unready. It recognizes both versions; native refresh invalidation remains.
- **More Settings:** projectile telegraphs moved from `playVisuals` to a separate
  `playTelegraph` method. Apply the existing bee visual budget to that cosmetic
  entry point too. Native `killTelegraph` and `syncTelegraph` tolerate a null FX;
  projectile launch, damage and cleanup are untouched. Ally FX discovery already
  includes `telegraphFx`, and initialization already supplies the entity scope.
- **More Settings, Item Utilities, Trade and Marketplace:** `WindowFlags.NeedLayer`
  was renamed to `NeedGameLayer`. Appearance and inspect previously passed a
  missing enum to `Type.enumIndex`; Marketplace safely skipped it but lost the
  layer flag. A shared resolver accepts either name and uses the actual native
  enum index. Tests cover older/current variants, different indices, missing
  flags and throwing lookups.

## Wider review

Scanned all eight mods: 351 existing hook declarations targeting 240 distinct
native methods, plus 2,337 literal native call/member lookup sites. No hook
targets disappeared. The shader compiler was the only changed hook signature.
With the projectile telegraph hook added, all 352 declarations match the new
client's native argument counts.

Compared 819 referenced method bodies, plus 341 input/controller, projectile,
window and terrain bodies including anonymous callbacks, and 404 enum definitions.
Function/type/global index shifts were resolved by name rather than treated as
behavior changes. Nested unit-data virtual types gained fields but the mods pass
those native values dynamically; their call signatures remain usable.

Fix Target Lock's input, lock acquisition, skill targeting, quick-cast callbacks
and camera paths are unchanged relative to the baseline. Its 81 combat checks
pass in both the interpreter and native HashLink. No speculative target-lock
behavior change was made. Live settings, physical input and the user's precise
failure symptom cannot be validated from bytecode alone.

The initial compatibility audit identified no additional change for Better Mod
Settings, Minimap, DPS Meter or Mod Update Alerts. In particular, the damage/victory RPC
hooks and the marketplace/item-link hooks retain their signatures. Native text
scaling, skin/collection and projectile changes were reviewed against their mod
callers; native text layout and game-owned cosmetic selection remain delegated
to the game.

## Chakram Heroic encounter follow-up

The subsequent encounter review found a DPS Meter behavior mismatch despite the
unchanged damage/victory hook signatures. `Phrixes.onDieServer` spawns the Heroic
alternate boss `Phrixes_NightGod`; `Dungeon.populateContext` registers a blocked
`KillBossAlt` objective for it. The final boss summons `Phrixes_NightGodGate`
targets, and `Phrixes_H_NG_Status.onSummonKilled` kills their owner after the last
gate dies. `DungeonBaseContext.areAllBossesDefeated` requires both `KillBoss` and
`KillBossAlt`. This structure was already present in the October 21 baseline;
October 28 changes the alternate spawn to `GameObject.spawnFoe` with persistence
and inherited level, and limits the summon-death handler to the gate kind.

DPS Meter previously archived victory at the original Phrixes death. Heroic now
keeps one encounter through the alternate boss/gates and requires both completed
objectives, with the alternate objective observed incomplete during that attempt.
Normal difficulty and the excluded opening health bar retain their boundaries.
The final phase preserves Chakram's identity, timing, damage and recording
coverage; expected original-entity removal does not create a recording gap.
Reconnects and actual loss of final-phase visibility remain incomplete.

The full DPS Meter interpreter suite and production/bootstrap compile pass.
The new collector regression has 40 passing checks in the interpreter and native
HashLink, including final-objective completion, reordered callbacks, stale goals,
wipes/retries, boss replacement, late gate damage, partial uploads and Normal.
This is bytecode and automated verification, not an in-game/server playtest.

## Validation and limits

All eight mods and their dependency bootstraps compile, and all eight interpreter
suites pass. Focused regressions reproduce the old failures before the fixes:
terrain readiness (213 passing checks), window flags (9), and the real generated
shader/pipeline receiver on HashLink (27). The supplied game bytecode is audit
input only and is not distributed in the repository or mod packages.

These checks do not run the game, renderer or server. In-game startup, appearance,
inspect, marketplace, terrain streaming and target-lock behavior still need
confirmation on this client.
