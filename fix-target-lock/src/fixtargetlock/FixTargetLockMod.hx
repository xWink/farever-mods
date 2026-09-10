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
    var holdToCast:Bool;
}

private typedef GroundAimInput = {
    var key:String;
    var released:Bool;
}

@:build(hlx.runtime.Mod.build())
class FixTargetLockMod {
    @:hlx.config
    static var config:TargetLockConfig = {
        enabled: true,
        autoUnlockOnDeath: true,
        quickSwapTarget: false,
        disableCameraMovement: false,
        holdToCast: false
    };

    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";

    static var inputType:hl.Bytes;
    static var playerControllerType:hl.Bytes;
    static var unitControllerType:hl.Bytes;
    static var gameCameraType:hl.Bytes;
    static var gameObjectType:hl.Bytes;
    static var baseSkillType:hl.Bytes;
    static var skillScriptType:hl.Bytes;
    static var skillTargetType:hl.Bytes;
    static var constType:hl.Bytes;
    static var isPressedMember:hlx.runtime.ResolvedMember;
    static var lockAutoTargetMember:hlx.runtime.ResolvedMember;
    static var leaveLockMember:hlx.runtime.ResolvedMember;
    static var getGameCameraMember:hlx.runtime.ResolvedMember;
    static var getLockedTargetMember:hlx.runtime.ResolvedMember;
    static var isDeadMember:hlx.runtime.ResolvedMember;
    static var lockTargetMember:hlx.runtime.ResolvedMember;
    static var getStepByTypeMember:hlx.runtime.ResolvedMember;
    static var allowAimingMember:hlx.runtime.ResolvedMember;
    static var isDownMember:hlx.runtime.ResolvedMember;
    static var isReleasedMember:hlx.runtime.ResolvedMember;
    static var activeGroundAim:GroundAimInput;
    static var lastController:Dynamic;
    static var originalTargetLock:Null<Bool>;
    static var lastAppliedTargetLock:Null<Bool>;
    static var cameraUpdateTargetLock:Null<Bool>;
    static var lastStatus:String = "Waiting for Farever";

    static function main():Void {
        if (ConfigMigration.importLegacy()) loadConfig();
        config.save();
        Bus.subscribe(
            SETTINGS_CHANGED_TOPIC_PREFIX + HlxRuntime.moduleName(),
            onBetterModSettingsChanged
        );
    }

    @:hlx.postfix(client.PlayerController.updateInputs)
    static function afterUpdateInputs(instance:Dynamic, dt:Float, result:Void):Void {
        lastController = instance;

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

            var inLock:Dynamic = HlxRuntime.resolveField(instance, "inLock");
            if (inLock == true) {
                var swapped = false;
                var aimedTarget:Dynamic = HlxRuntime.resolveField(instance, "autoTarget");
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

    // Farever normally refreshes autoTarget inside startSkillAim and can pass a
    // newly looked-at enemy to the attack despite Hero.lockedTarget. Every skill
    // that immediately submits Target(autoTarget), including basic attacks, is
    // redirected to the hard lock. Skills entering manual point/ground aiming
    // continue through Farever's original targeting path.
    @:hlx.prefix(client.UnitController.startSkillAim)
    static function forceLockedAttackTarget(instance:Dynamic, skill:Dynamic, callback:Dynamic, input:String):HlxPrefixControl {
        if (!config.enabled || instance != lastController)
            return Continue;

        try {
            var inLock:Dynamic = HlxRuntime.resolveField(instance, "inLock");
            if (inLock != true)
                return Continue;

            var lockedTarget = getLockedTarget(instance);
            if (lockedTarget == null)
                return Continue;

            if (baseSkillType == null)
                baseSkillType = HlxRuntime.resolveType("st.skill.BaseSkill");
            if (baseSkillType == null)
                return Continue;
            if (getStepByTypeMember == null)
                getStepByTypeMember = HlxRuntime.resolveMember(baseSkillType, "getStepByType");
            if (getStepByTypeMember == null)
                return Continue;

            // Step type 25 is Farever's explicit aiming step. startSkillAim only
            // enters manual targeting when that step exists and the skill script
            // allows aiming; every other branch immediately emits Target(autoTarget).
            var aimingStep:Dynamic = HlxRuntime.callResolved(getStepByTypeMember, [skill, 25]);
            if (aimingStep != null) {
                if (skillScriptType == null)
                    skillScriptType = HlxRuntime.resolveType("script.SkillScript");
                if (skillScriptType == null)
                    return Continue;
                if (allowAimingMember == null)
                    allowAimingMember = HlxRuntime.resolveMember(skillScriptType, "allowAiming");
                if (allowAimingMember == null)
                    return Continue;

                var script:Dynamic = HlxRuntime.resolveField(skill, "script");
                if (script == null)
                    return Continue;
                var usesManualAim:Dynamic = HlxRuntime.callResolved(allowAimingMember, [script]);
                if (usesManualAim == true)
                    return Continue;
            }

            if (skillTargetType == null)
                skillTargetType = HlxRuntime.resolveType("st.skill.SkillTarget");
            if (skillTargetType == null)
                return Continue;

            var forcedTarget:Dynamic = HlxRuntime.constructEnum(skillTargetType, "Target", [lockedTarget]);
            if (forcedTarget == null)
                return Continue;

            Reflect.callMethod(null, callback, [forcedTarget]);
            return Skip;
        } catch (e:Dynamic) {
            // Preserve normal combat if a game update changes any target types.
            trace("[FixTargetLock] strict target fallback: " + Std.string(e));
            return Continue;
        }
    }

    @:hlx.postfix(client.UnitController.startTargetMode)
    static function afterStartTargetMode(instance:Dynamic, skill:Dynamic, callback:Dynamic,
        input:String, result:Void):Void {
        if (!config.enabled || !config.holdToCast || instance != lastController || input == null)
            return;
        if (!resolveGroundAimInput())
            return;

        var released = readAimInput(isReleasedMember, input);
        if (!released && !readAimInput(isDownMember, input))
            return;
        var nativeUpdate:Float->Void = cast HlxRuntime.resolveField(instance, "currentJobFunc");
        if (nativeUpdate == null)
            return;

        var aim:GroundAimInput = { key: input, released: released };
        HlxRuntime.setField(instance, "currentJobFunc", function(dt:Float):Void {
            var previous = activeGroundAim;
            activeGroundAim = null;
            try {
                if (config.enabled && config.holdToCast
                    && aimInputActive()) {
                    // Native aiming skips confirmation on its first frame.
                    // Remember an early release until that confirmation runs.
                    aim.released = aim.released || readAimInput(isReleasedMember, aim.key);
                    activeGroundAim = aim;
                } else {
                    aim.released = false;
                }
                // Preserve positioning, indicator FX, cancellation, and cast submission.
                nativeUpdate(dt);
            } catch (error:Dynamic) {
                activeGroundAim = previous;
                throw error;
            }
            activeGroundAim = previous;
        });
    }

    @:hlx.prefix(lib.Input.isPressedWithoutMode)
    static function confirmGroundAimOnRelease(input:String):HlxPrefixResult<Bool> {
        if (activeGroundAim != null && input == activeGroundAim.key)
            return SkipWith(activeGroundAim.released);
        return Continue;
    }

    static function resolveGroundAimInput():Bool {
        if (inputType == null)
            inputType = HlxRuntime.resolveType("lib.Input");
        if (inputType == null)
            return false;
        if (isDownMember == null)
            isDownMember = HlxRuntime.resolveStaticMember(inputType, "isDown");
        if (isReleasedMember == null)
            isReleasedMember = HlxRuntime.resolveStaticMember(inputType, "isReleased");
        return isDownMember != null && isReleasedMember != null;
    }

    static function aimInputActive():Bool {
        var checkActive:hl.Ref<Bool>->Bool = cast HlxRuntime.resolveStaticField(inputType, "checkActive");
        return checkActive != null && checkActive(null);
    }

    static function readAimInput(member:hlx.runtime.ResolvedMember, input:String):Bool {
        // Target mode blocks ordinary skill inputs. Match the native
        // isPressedWithoutMode query while retaining binding and focus handling.
        var previous:Dynamic = HlxRuntime.resolveStaticField(inputType, "_noCheckMode");
        HlxRuntime.setStaticField(inputType, "_noCheckMode", true);
        var result:Dynamic;
        try {
            result = HlxRuntime.callResolved(member, [input]);
        } catch (error:Dynamic) {
            HlxRuntime.setStaticField(inputType, "_noCheckMode", previous);
            throw error;
        }
        HlxRuntime.setStaticField(inputType, "_noCheckMode", previous);
        return result == true;
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
        if (lastAppliedTargetLock == desired)
            return;

        Reflect.setField(camera, "TargetLock", desired);
        lastAppliedTargetLock = desired;
    }

    @:hlx.prefix(client.GameCamera.postUpdate)
    static function beforeCameraPostUpdate(instance:Dynamic, dt:Float):HlxPrefixControl {
        cameraUpdateTargetLock = null;
        if (!config.enabled || !config.disableCameraMovement)
            return Continue;

        try {
            if (constType == null)
                constType = HlxRuntime.resolveType("Const");
            if (constType == null)
                return Continue;
            var camera:Dynamic = HlxRuntime.resolveStaticField(constType, "Camera");
            if (camera == null)
                return Continue;

            var current:Dynamic = Reflect.field(camera, "TargetLock");
            if (current == null)
                return Continue;
            cameraUpdateTargetLock = cast current;
            Reflect.setField(camera, "TargetLock", false);
        } catch (_:Dynamic) {
            cameraUpdateTargetLock = null;
        }
        return Continue;
    }

    @:hlx.postfix(client.GameCamera.postUpdate)
    static function afterCameraPostUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        if (cameraUpdateTargetLock == null)
            return;
        try {
            if (constType != null) {
                var camera:Dynamic = HlxRuntime.resolveStaticField(constType, "Camera");
                if (camera != null)
                    Reflect.setField(camera, "TargetLock", cameraUpdateTargetLock);
            }
        } catch (_:Dynamic) {}
        cameraUpdateTargetLock = null;
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
        lastAppliedTargetLock = null;
        applyFeatureFlag();
    }

    static function onBetterModSettingsChanged(_:Dynamic):Void {
        var wasEnabled = config.enabled;
        loadConfig();
        if (wasEnabled && !config.enabled)
            disableAndUnlock();
        else if (!wasEnabled && config.enabled) {
            lastAppliedTargetLock = null;
            applyFeatureFlag();
        }
    }

    static function loadConfig():Void {
        config = ModConfig.load(HlxRuntime.moduleName(), config);
    }
}
