import fixtargetlock.QuickCast;
import fixtargetlock.TargetLockCamera;
import fixtargetlock.LockedTargeting;
import fixtargetlock.LockLifecycle;
import fixtargetlock.GameAccess as G;

class CombatTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        var q = new QuickCast();
        var player:Dynamic = {ended: false, lockedTarget: "Enemy"};
        var other:Dynamic = {ended: false};
        G.data = {_noCheckMode: false, checkActive: (_:Dynamic) -> G.inputActive};
        q.observeController(player);
        q.beginUpdate(player);
        q.start(player, "Skill1");
        eq(q.confirm("Skill1"), null, "Off by default keeps native confirmation");
        q.enabled = true;
        q.start(player, "Skill1");
        eq(q.confirm("Skill1"), false, "Holding the skill keeps native aiming open");
        eq(q.confirm("Skill2"), null, "Another skill input is unchanged");
        eq(q.confirm("AimSkillCancel"), null, "Cancellation remains native");
        eq(G.data._noCheckMode, false, "Input mode restored after checking release");
        q.beginUpdate(other);
        G.releasedInput = "Skill1";
        eq(q.confirm("Skill1"), null, "Nested non-player controller cannot confirm player's skill");
        q.endUpdate(other);
        eq(q.confirm("Skill1"), true, "Releasing the bound skill confirms native ground aim");
        eq(player.lockedTarget, "Enemy", "Quick cast never replaces the lock");
        q.stop(player); // Native setJob on cast/cancel.
        eq(q.confirm("Skill1"), null, "Native job change clears confirmation");
        q.endUpdate(player);

        // Native aiming skips its confirmation block on the first frame.
        q.beginUpdate(player);
        q.start(player, "Skill1");
        q.endUpdate(player);
        G.releasedInput = null;
        q.beginUpdate(player);
        eq(q.confirm("Skill1"), true, "First-frame quick tap is retained for the next native update");
        q.stop(player);
        q.start(player, "Skill2");
        eq(q.confirm("Skill2"), false, "A later skill cannot reuse an old release");
        q.enabled = false;
        eq(q.confirm("Skill2"), null, "Disabling while aiming restores native click confirmation");
        q.enabled = true;
        q.start(other, "Skill1");
        eq(q.confirm("Skill1"), null, "Non-player aiming is not intercepted");
        q.start(player, "Skill1");
        G.inputActive = false;
        G.releasedInput = "Skill1";
        var reads = G.releaseReads;
        eq(q.confirm("Skill1"), false, "Inactive input cannot cast");
        eq(G.releaseReads, reads, "Respect the native focus/UI gate before reading bindings");
        G.inputActive = true;
        G.releasedInput = null;
        eq(q.confirm("Skill1"), false, "Refocusing does not cast a stale release");
        G.data._noCheckMode = true;
        eq(q.confirm("Skill1"), false, "Still holding in an existing mode override");
        eq(G.data._noCheckMode, true, "An existing input mode override is preserved");
        G.data._noCheckMode = false;
        G.failRelease = true;
        var failed = false;
        try q.confirm("Skill1") catch (_:Dynamic) failed = true;
        eq(failed, true, "Input errors reach the guarded hook");
        eq(G.data._noCheckMode, false, "Input mode restored even on native error");
        G.failRelease = false;
        eq(q.confirm("Skill1"), null, "A failed release check returns future input to native handling");
        q.start(player, "Skill1");
        q.observeController(other);
        eq(q.confirm("Skill1"), null, "Controller replacement clears the old skill");
        q.observeController(player);
        q.start(player, "Skill1");
        player.ended = true;
        eq(q.confirm("Skill1"), null, "Ended controllers cannot cast");
        player.ended = false;
        q.start(player, "Skill1");
        q.beginFrame(); // Recover a native update that exited before its postfix.
        eq(q.confirm("Skill1"), null, "An abandoned update scope cannot leak into other input");
        q.reset();

        // Native skill queuing can outlast the one-frame key-up event. The
        // accepted request opens target mode only after the skill is usable.
        q.observeController(player); q.beginUpdate(player);
        G.heldInputs["Skill1"] = false; G.releasedInput = null;
        q.start(player, "Skill1"); q.endUpdate(player);
        q.beginUpdate(player);
        eq(q.confirm("Skill1"), true, "Queued tap already released before aiming still casts");
        q.stop(player); q.endUpdate(player);
        G.heldInputs["Skill1"] = true;

        q.beginUpdate(player); q.start(player, "Skill1"); q.endUpdate(player);
        G.heldInputs["Skill1"] = false; // Release edge passed between controller updates.
        q.beginUpdate(player);
        eq(q.confirm("Skill1"), true, "A missed key-up edge cannot leave aiming stuck");
        G.inputActive = false;
        eq(q.confirm("Skill1"), false, "Losing focus clears even a latched release");
        G.inputActive = true;
        eq(q.confirm("Skill1"), false, "Returning focus with the button up does not cast");
        G.heldInputs["Skill1"] = true;
        eq(q.confirm("Skill1"), false, "A fresh valid hold rearms after focus loss");
        G.heldInputs["Skill1"] = false;
        eq(q.confirm("Skill1"), true, "Release after refocusing works normally");
        q.stop(player);

        G.bindingsAvailable = false;
        q.start(player, "Skill1");
        eq(q.confirm("Skill1"), false, "Blocked native binding is not a released button");
        G.bindingsAvailable = true;
        eq(q.confirm("Skill1"), false, "Closing a blocking UI cannot auto-cast");
        G.heldInputs["Skill1"] = true;
        eq(q.confirm("Skill1"), false, "Fresh hold after a blocked binding keeps aiming open");
        G.heldInputs["Skill1"] = false;
        eq(q.confirm("Skill1"), true, "Native binding works again after a fresh hold and release");
        q.stop(player);

        G.usePad = true; G.heldInputs["Skill1"] = true;
        q.start(player, "Skill1");
        eq(q.confirm("Skill1"), false, "Holding the gamepad skill keeps aiming open");
        G.heldInputs["Skill1"] = false;
        eq(q.confirm("Skill1"), true, "Gamepad release uses current button state too");
        q.stop(player); q.start(player, "Skill1");
        eq(q.confirm("Skill1"), true, "Already released queued gamepad tap still casts");
        q.stop(player); q.endUpdate(player); q.reset();
        G.usePad = false; G.heldInputs["Skill1"] = true;

        var camera = new TargetLockCamera();
        var settings:Dynamic = {LockRotateSpeed: 8.0, TargetLock: true};
        G.data = {Camera: settings};
        camera.begin();
        eq(settings.LockRotateSpeed, 8.0, "Camera default leaves native steering on");
        camera.end();
        camera.enabled = true;
        camera.begin();
        eq(settings.LockRotateSpeed, 0.0, "Disable only automatic lock steering");
        eq(1 - Math.exp(-settings.LockRotateSpeed * 0.016), 0.0, "Native steering interpolation makes no correction");
        eq(settings.TargetLock, true, "Target-lock feature and locked sensitivity stay enabled");
        camera.begin();
        camera.end();
        eq(settings.LockRotateSpeed, 0.0, "Nested camera updates preserve the outer override");
        camera.enabled = false;
        camera.end();
        eq(settings.LockRotateSpeed, 8.0, "Restore even if setting changes before postfix");
        settings.LockRotateSpeed = 12.0;
        camera.enabled = true;
        camera.begin();
        camera.reset();
        eq(settings.LockRotateSpeed, 12.0, "Recover the exact current tuning after an interrupted update");
        G.data = {Camera: {TargetLock: true}};
        camera.begin(); camera.end();
        eq(G.data.Camera.TargetLock, true, "Missing optional steering field leaves native behavior intact");

        var targeting = new LockedTargeting();
        var locked = {name: "locked"};
        var aimed = {name: "crosshair"};
        player.autoTarget = aimed;
        targeting.begin(player, locked);
        eq(player.autoTarget, locked, "Instant skills without a fresh target query use the lock");
        eq(targeting.target(player), locked, "Native skill target query stays on the lock");
        eq(targeting.target(other), null, "Another controller keeps native targeting");
        targeting.begin(other, null);
        eq(targeting.target(player), null, "Nested skill aiming cannot borrow the outer lock");
        targeting.end();
        eq(targeting.target(player), locked, "Nested call restores the outer aim scope");
        targeting.begin(player, locked);
        targeting.end();
        eq(player.autoTarget, locked, "Nested same-controller scope keeps the outer target");
        targeting.end();
        eq(player.autoTarget, aimed, "Native crosshair target restored after skill callback");
        eq(targeting.target(player), null, "Ordinary target picking is never pinned");
        targeting.begin(player, null);
        player.autoTarget = other;
        targeting.end();
        eq(player.autoTarget, other, "Unlocked skill keeps native auto-target changes");
        targeting.begin(player, locked);
        targeting.reset();
        eq(player.autoTarget, other, "Interrupted skill scope restores the prior target next frame");
        eq(targeting.target(player), null, "Interrupted scope cannot affect later skills");
        lockTransitions();
        Sys.println('Combat tests passed ($checks checks)');
    }

    // Reproduce native updateInputs: an orphaned inLock immediately reacquires
    // autoTarget before the mod's existing postfix can notice the missing lock.
    static function nativeLockUpdate(controller:Dynamic):Void {
        if (controller.inLock && controller.unit.lockedTarget == null) {
            controller.unit.lockedTarget = controller.autoTarget;
            controller.inLock = controller.autoTarget != null;
        }
    }

    static function lockTransitions():Void {
        var dungeon = {name:"dungeon"}, overworld = {name:"overworld"};
        var foe = {name:"dungeon foe"}, replacement = {name:"overworld foe"};
        var hero:Dynamic = {layer:dungeon, lockedTarget:foe};
        var controller:Dynamic = {unit:hero, inLock:true, autoTarget:foe};
        var lifecycle = new LockLifecycle();
        eq(lifecycle.observe(controller, true), false, "First observation preserves a valid lock");
        eq(hero.lockedTarget, foe, "Initial target remains selected");

        var unguarded:Dynamic = {unit:{layer:overworld, lockedTarget:null}, inLock:true, autoTarget:replacement};
        nativeLockUpdate(unguarded);
        eq(unguarded.unit.lockedTarget, replacement, "Reproduce unwanted native reacquisition without another keypress");

        controller.unit = {layer:overworld, lockedTarget:null};
        controller.autoTarget = replacement;
        eq(lifecycle.observe(controller, true), true, "Reused controller detects the replacement hero");
        nativeLockUpdate(controller);
        eq(controller.unit.lockedTarget, null, "Transition cleanup prevents the unwanted overworld lock");
        eq(controller.inLock, false, "Native lock mode is off after leaving the dungeon");
        eq(controller.autoTarget, null, "Previous area's auto-target is discarded");

        controller.unit.lockedTarget = replacement; controller.inLock = true; controller.autoTarget = replacement;
        eq(lifecycle.observe(controller, true), false, "A deliberate lock in the new area survives later frames");
        eq(controller.unit.lockedTarget, replacement, "Valid same-area lock stays intact");
        controller.unit.layer = dungeon;
        eq(lifecycle.observe(controller, true), true, "Map change is detected even when the hero is reused");
        eq(controller.unit.lockedTarget, null, "Old nonzero target is cleared through native leaveLock");

        controller.inLock = true; controller.autoTarget = foe; controller.unit = null;
        var unlocks = G.unlocks;
        lifecycle.observe(controller, true);
        eq(controller.inLock, false, "Temporary missing hero clears controller lock intent");
        eq(G.unlocks, unlocks, "No native leaveLock call dereferences a missing hero");
        controller.unit = hero;
        lifecycle.observe(controller, true);
        eq(hero.lockedTarget, null, "Returning hero cannot restore the previous target");

        var other:Dynamic = {unit:hero, inLock:true, autoTarget:foe};
        eq(lifecycle.observe(other, true), true, "Controller replacement resets the old lock context");
        eq(other.inLock, false, "Replacement controller does not inherit lock intent");

        hero.layer = overworld; hero.lockedTarget = replacement; other.inLock = true; other.autoTarget = replacement;
        unlocks = G.unlocks;
        eq(lifecycle.observe(other, false), false, "Disabled mod observes changes without touching native state");
        eq(G.unlocks, unlocks, "Disabled mod makes no unlock call");
        eq(other.inLock, true, "Disabled mod leaves the native lock alone");
        eq(lifecycle.observe(other, true), false, "Re-enabling does not replay transitions from while disabled");

        hero.layer = dungeon; G.failUnlock = true;
        var failed = false;
        try lifecycle.observe(other, true) catch (_:Dynamic) failed = true;
        eq(failed, true, "Native cleanup failures reach the hook's error handler");
        G.failUnlock = false;
        eq(lifecycle.observe(other, true), true, "Interrupted transition cleanup retries next update");
        eq(other.inLock, false, "Retry clears the lock");
        lifecycle.reset();
        other.inLock = true; hero.lockedTarget = foe;
        eq(lifecycle.observe(other, true), false, "Disposal releases the previous session's context");
        eq(hero.lockedTarget, foe, "A fresh session's initial valid lock is preserved");
    }
}
