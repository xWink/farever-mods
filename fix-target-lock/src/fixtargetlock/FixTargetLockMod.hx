package fixtargetlock;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import modconfig.ConfigMigration;
import hlx.runtime.HlxPrefixControl;
import hlx.runtime.HlxPrefixResult;

typedef TargetLockConfig = {
    var enabled:Bool;
    var autoUnlockOnDeath:Bool;
    var quickSwapTarget:Bool;
    var disableCameraMovement:Bool;
    var quickCast:Bool;
}

@:build(hlx.runtime.Mod.build())
class FixTargetLockMod {
    @:hlx.config
    static var config:TargetLockConfig = {
        enabled: true,
        autoUnlockOnDeath: true,
        quickSwapTarget: false,
        disableCameraMovement: false,
        quickCast: false
    };

    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";

    static var inputType:hl.Bytes;
    static var playerControllerType:hl.Bytes;
    static var unitControllerType:hl.Bytes;
    static var gameCameraType:hl.Bytes;
    static var gameObjectType:hl.Bytes;
    static var constType:hl.Bytes;
    static var isPressedMember:hlx.runtime.ResolvedMember;
    static var lockAutoTargetMember:hlx.runtime.ResolvedMember;
    static var leaveLockMember:hlx.runtime.ResolvedMember;
    static var getGameCameraMember:hlx.runtime.ResolvedMember;
    static var getLockedTargetMember:hlx.runtime.ResolvedMember;
    static var isDeadMember:hlx.runtime.ResolvedMember;
    static var lockTargetMember:hlx.runtime.ResolvedMember;
    static var lastController:Dynamic;
    static var originalTargetLock:Null<Bool>;
    static var targeting = new LockedTargeting();
    static var lockLifecycle = new LockLifecycle();
    static var lastStatus:String = "Waiting for Farever";

    static function main():Void {
        if (ConfigMigration.importLegacy()) loadConfig();
        config.save();
        CombatHooks.configure(config);
        Bus.subscribe(
            SETTINGS_CHANGED_TOPIC_PREFIX + HlxRuntime.moduleName(),
            onBetterModSettingsChanged
        );
    }

    @:hlx.prefix(client.PlayerController.update)
    static function beforeControllerUpdate(instance:Dynamic, dt:Float):HlxPrefixControl {
        lastController = instance;
        try {
            if (lockLifecycle.observe(instance, config.enabled))
                lastStatus = "Unlocked (area or character changed)";
        } catch (error:Dynamic) {
            lastStatus = "Error clearing previous area lock: " + Std.string(error);
            trace("[FixTargetLock] " + lastStatus);
        }
        return Continue;
    }

    @:hlx.postfix(client.PlayerController.updateInputs)
    static function afterUpdateInputs(instance:Dynamic, dt:Float, result:Void):Void {
        try {
            applyFeatureFlag();
            if (!config.enabled) {
                lastStatus = "Disabled";
                return;
            }

            if (!resolveMembers()) {
                lastStatus = "Waiting for Farever input methods";
                return;
            }

            var pressed:Dynamic = HlxRuntime.callResolved(isPressedMember, ["LockTarget"]);
            if (pressed != true) {
                if (!autoUnlockDeadTarget(instance))
                    updateStatus(instance);
                return;
            }

            // updateInputs runs before this frame's updatePicked. Select using
            // the current view so an initial lock/swap cannot reuse a stale target.
            var onlyEnemies = true;
            var aimedTarget = GameAccess.call("client.UnitController", "getAutoTarget", instance,
                [hl.Ref.make(onlyEnemies)]);
            GameAccess.set(instance, "autoTarget", aimedTarget);
            var inLock:Dynamic = HlxRuntime.resolveField(instance, "inLock");
            if (inLock == true) {
                var swapped = false;
                if (config.quickSwapTarget && aimedTarget != null) {
                    var lockedTarget = getLockedTarget(instance);
                    if (lockedTarget != aimedTarget) {
                        HlxRuntime.callResolved(lockTargetMember, [instance, aimedTarget]);
                        updateStatus(instance);
                        swapped = true;
                    }
                }

                if (!swapped) {
                    HlxRuntime.callResolved(leaveLockMember, [instance]);
                    lastStatus = "Unlocked";
                }
            } else {
                HlxRuntime.callResolved(lockAutoTargetMember, [instance]);
                updateStatus(instance);
            }

            autoUnlockDeadTarget(instance);
        } catch (e:Dynamic) {
            lastStatus = "Error: " + Std.string(e);
            trace("[FixTargetLock] " + lastStatus);
        }
    }

    static function resolveMembers():Bool {
        if (inputType == null)
            inputType = HlxRuntime.resolveType("lib.Input");
        if (playerControllerType == null)
            playerControllerType = HlxRuntime.resolveType("client.PlayerController");
        if (inputType == null || playerControllerType == null)
            return false;

        if (isPressedMember == null)
            isPressedMember = HlxRuntime.resolveStaticMember(inputType, "isPressed");
        if (lockAutoTargetMember == null)
            lockAutoTargetMember = HlxRuntime.resolveMember(playerControllerType, "lockAutoTarget");
        if (leaveLockMember == null)
            leaveLockMember = HlxRuntime.resolveMember(playerControllerType, "leaveLock");
        if (lockTargetMember == null)
            lockTargetMember = HlxRuntime.resolveMember(playerControllerType, "lockTarget");

        return isPressedMember != null
            && lockAutoTargetMember != null
            && leaveLockMember != null
            && lockTargetMember != null;
    }

    @:hlx.prefix(GameApp.update)
    static function beforeFrame(instance:Dynamic, dt:Float):HlxPrefixControl {
        CombatHooks.beginFrame();
        targeting.reset();
        return Continue;
    }

    // Keep native skill replacement, virtual allowAiming dispatch, and ground
    // targeting. Only the auto-target chosen within instant skill aim is pinned.
    @:hlx.prefix(client.UnitController.startSkillAim)
    static function beforeSkillAim(instance:Dynamic, skill:Dynamic, callback:Dynamic, input:String):HlxPrefixControl {
        var target:Dynamic = null;
        try {
            if (config.enabled && instance == lastController
                && GameAccess.field(instance, "inLock") == true) {
                target = getLockedTarget(instance);
                // The native picker uses virtual dispatch: bosses can become
                // temporarily un-lockable (e.g. Cleodora while attached).
                if (target != null && (GameAccess.callInstance(target, "canBeLocked") != true
                    || GameAccess.call("ent.GameObject", "isDead", target) == true)) target = null;
            }
        } catch (error:Dynamic) {
            target = null;
            trace("[FixTargetLock] target lookup: " + Std.string(error));
        }
        targeting.begin(instance, target);
        return Continue;
    }

    @:hlx.postfix(client.UnitController.startSkillAim)
    static function afterSkillAim(instance:Dynamic, skill:Dynamic, callback:Dynamic, input:String, result:Void):Void
        targeting.end();

    @:hlx.prefix(client.UnitController.getAutoTarget)
    static function lockedSkillTarget(instance:Dynamic, onlyEnemies:hl.Ref<Bool>):HlxPrefixResult<Dynamic> {
        var target = targeting.target(instance);
        return target == null ? Continue : SkipWith(target);
    }

    @:hlx.prefix(GameApp.dispose)
    static function beforeDispose(instance:Dynamic):HlxPrefixControl {
        CombatHooks.dispose();
        targeting.reset();
        lockLifecycle.reset();
        lastController = null;
        return Continue;
    }

    static function resolveDeathCheckMembers():Bool {
        if (unitControllerType == null)
            unitControllerType = HlxRuntime.resolveType("client.UnitController");
        if (gameCameraType == null)
            gameCameraType = HlxRuntime.resolveType("client.GameCamera");
        if (gameObjectType == null)
            gameObjectType = HlxRuntime.resolveType("ent.GameObject");
        if (unitControllerType == null || gameCameraType == null || gameObjectType == null)
            return false;

        if (getGameCameraMember == null)
            getGameCameraMember = HlxRuntime.resolveMember(unitControllerType, "get_gameCamera");
        if (getLockedTargetMember == null)
            getLockedTargetMember = HlxRuntime.resolveMember(gameCameraType, "getLockedTarget");
        if (isDeadMember == null)
            isDeadMember = HlxRuntime.resolveMember(gameObjectType, "isDead");

        return getGameCameraMember != null
            && getLockedTargetMember != null
            && isDeadMember != null;
    }

    static function autoUnlockDeadTarget(controller:Dynamic):Bool {
        if (!config.autoUnlockOnDeath)
            return false;

        var inLock:Dynamic = HlxRuntime.resolveField(controller, "inLock");
        if (inLock != true || !resolveDeathCheckMembers())
            return false;

        var target:Dynamic = getLockedTarget(controller);

        // A missing weak target is no longer a usable lock and is treated like a
        // despawned/dead target. Otherwise, ask the game for its native death state.
        var shouldUnlock = target == null;
        if (!shouldUnlock) {
            var dead:Dynamic = HlxRuntime.callResolved(isDeadMember, [target]);
            shouldUnlock = dead == true;
        }

        if (shouldUnlock) {
            HlxRuntime.callResolved(leaveLockMember, [controller]);
            lastStatus = "Unlocked (target defeated)";
            return true;
        }
        return false;
    }

    static function getLockedTarget(controller:Dynamic):Dynamic {
        if (!resolveDeathCheckMembers())
            return null;
        var camera:Dynamic = HlxRuntime.callResolved(getGameCameraMember, [controller]);
        return camera == null
            ? null
            : HlxRuntime.callResolved(getLockedTargetMember, [camera]);
    }

    static function applyFeatureFlag():Void {
        if (constType == null)
            constType = HlxRuntime.resolveType("Const");
        if (constType == null)
            return;

        var camera:Dynamic = HlxRuntime.resolveStaticField(constType, "Camera");
        if (camera == null)
            return;

        if (originalTargetLock == null) {
            var current:Dynamic = Reflect.field(camera, "TargetLock");
            if (current == null)
                return;
            originalTargetLock = cast current;
        }

        // Keep Farever's lock mode enabled outside the camera update. Other
        // systems use this flag for locked sensitivity and targeting behavior.
        var desired = config.enabled ? true : originalTargetLock;
        if (Reflect.field(camera, "TargetLock") == desired)
            return;

        Reflect.setField(camera, "TargetLock", desired);
    }

    static function updateStatus(controller:Dynamic):Void {
        var inLock:Dynamic = HlxRuntime.resolveField(controller, "inLock");
        if (inLock == true)
            lastStatus = "Target locked (native hard-lock indicator active)";
        else
            lastStatus = "Ready - look at an enemy and press Lock Target";
    }

    static function disableAndUnlock():Void {
        if (lastController != null && resolveMembers()) {
            try HlxRuntime.callResolved(leaveLockMember, [lastController]) catch (_:Dynamic) {}
        }
        applyFeatureFlag();
    }

    static function onBetterModSettingsChanged(_:Dynamic):Void {
        var wasEnabled = config.enabled;
        loadConfig();
        CombatHooks.configure(config);
        if (wasEnabled && !config.enabled)
            disableAndUnlock();
        else if (!wasEnabled && config.enabled) {
            applyFeatureFlag();
        }
    }

    static function loadConfig():Void {
        config = ModConfig.load(HlxRuntime.moduleName(), config);
    }
}
