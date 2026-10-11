# September 30 Live combat audit

Supplied client: `hlboot(20260930-154724).dat`, HashLink bytecode 6.
SHA-256: `8bb2ce5180018ebffe0c3f357c77b86bf5ebcecd06aa65b97a69367f2f806e49`.
Function indices below are investigation references, never runtime constants.

## Lock input

Unlike the earlier PTR, this Live client's `PlayerController.updateInputs`
(f13250) contains no `LockTarget` input query. It only attempts lock reacquisition
and handles the admin position shortcuts. Fix Target Lock retains its toggle;
there is no Live/PTR capability detection or deprecation path.

`PlayerController.update` calls updateInputs before UnitController.updatePicked.
The mod now refreshes the native auto-target on a lock/swap press rather than
using the previous frame's target. Native lockTarget (f13246) validates
canBeLocked and writes Hero.lockedTarget through its normal setter.

## Skill targeting

Native startSkillAim (f13205) first calls getReplacedSkill, then checks the
replacement's aiming step and virtual script.allowAiming. The former mod
short-circuit bypassed this sequence and invoked the base script method directly.
The mod now lets the native skill-aim method execute, pinning autoTarget and its
getAutoTarget calls only inside that call's scope. Native instant skills submit
Target(lockedEnemy), while manual aiming still enters the native Point workflow.
The previous crosshair target is restored afterwards. Nested and interrupted
scopes cannot leave subsequent target picking pinned.

## Camera and quick cast

The tested quick-cast and camera implementations formerly duplicated in More
Settings now belong solely to Fix Target Lock. More Settings contains neither
those settings nor their hooks. Existing Fix Target Lock preferences remain.

GameCamera.postUpdate applies steering through smoothLerp(LockRotateSpeed, dt).
The camera option scopes that speed to zero and restores it, instead of turning
off the shared TargetLock flag. All other camera behavior remains native.
Quick cast latches the skill-button release, respects focus/UI gates, preserves
native cancellation, and restores temporary input modes after errors.

## Verification limits

CombatTest runs in the interpreter and HashLink (43 checks), covering scopes,
controller ownership, nested calls, cancellation, first-frame releases, focus,
and exception recovery. Full compilation and native API signature auditing also
pass. These checks do not run the game renderer, server, or physical input;
in-game lock acquisition, attacks, manual aiming, quick cast, and camera feel
still require play-testing on the supplied Live version.

## October 1 evening client update

Supplied client: `hlboot(20261001-232103).dat`, HashLink bytecode 6.
SHA-256: `617f602066c762869d5c15a01c83714664b0026868f0d24b129bbcc850da88d8`.

`UnitController.getAutoTarget` now invokes `canBeLocked` virtually. The new
`ent.boss.Cleodora.canBeLocked` rejects an attached Cleodora before delegating to
the base implementation. The mod's skill-aim eligibility check previously called
the base implementation directly, bypassing that restriction for an existing
lock. It now resolves the method on the target's actual runtime type, preserving
native overrides and inherited behavior. If eligibility lookup throws, the mod
leaves skill target selection to the game instead of pinning an unvalidated target.

Native hook signatures remain compatible. The 43 combat regression checks and
full mod/bootstrap compilation pass. The override was verified through bytecode
and HLX resolver inspection; an actual Cleodora encounter still needs in-game
validation.

## October 4 quick-cast timing fix

Audited the October 1 evening client above. `updateSkillInput` accepts queueable
skills into `requestedSkillInput`; `tryResolveSkillRequests` retries them during
`SkillQueueTime`. `requestSkill` does not open `startTargetMode` until `checkUse`
succeeds. A short press can therefore be released before aiming begins. The old
mod then polled only `isReleased`, whose edge had expired, leaving the indicator
waiting for another press/release. A regression reproduces this failure with the
previous implementation.

Quick cast now samples held state through native `lib.Input.checkInput` instead
of depending on a one-frame release event. Its readers call native `hxd.Key.isDown`
and `gamepad.Pad.isDown(code, null)`. Native bindings, modifier matching, active
gamepad checks, and console/cinematic restrictions stay in the native reader;
only ground aiming's input-mode restriction is temporarily bypassed. A binding
skipped by those restrictions is distinguished from a button that is up. Losing
focus or access to the binding clears the latch and requires a fresh valid hold
before another release can confirm. Native casting, targeting, queues, and
cancellation are unchanged.

Regression coverage includes queued taps released before aiming, missed release
edges, held aiming, keyboard/gamepad paths, first-frame latching, focus and
blocked-binding recovery, cancellation/job changes, and nested controllers.
Automated tests simulate input states; physical gameplay still needs validation.

## October 10 area-transition lock fix

Audited `hlboot(20261007-191837).dat`, HashLink bytecode 6.
`GameApp.syncPlayer` (f12903) reuses `PlayerController.inst` and replaces its
`unit` without resetting `inLock` or `autoTarget`. Native
`PlayerController.updateInputs` (f13256) immediately calls `lockAutoTarget`
when `inLock` is true and the current hero's `lockedTarget` is zero. The mod's
existing postfix dead-target check runs after this reacquisition and can see
a valid replacement target, missing the stale lock intent.

A prefix on `PlayerController.update` (f13247, receiver + Float -> Void)
now observes controller, hero and layer identity before native input processing,
even when input is blocked. On a transition, it clears `autoTarget` and calls
native `leaveLock` (f13259), which resets `Hero.lockedTarget` through its native
setter and clears `inLock`. A temporarily missing hero clears only controller
state until a hero returns. The guard is independent of auto-unlock-on-death,
does not mutate native state while the mod is disabled, and releases its
references on disposal.

Combat regressions reproduce automatic reacquisition without the guard and
verify that hero/map changes prevent it, while deliberate same-area locks
survive. They also cover controller replacement, a missing hero, disabled
handling, interrupted cleanup and session reset. These are simulated transitions;
the actual dungeon-exit path still needs in-game confirmation.
