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

private typedef GroundAimInput = {
    var controller:Dynamic;
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
        quickCast: false
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
    static var isReleasedMember:hlx.runtime.ResolvedMember;
    static var activeGroundAim:GroundAimInput;
    static var updatingController:Dynamic;
    static var lastController:Dynamic;
    static var originalTargetLock:Null<Bool>;
    static var lastAppliedTargetLock:Null<Bool>;
    static var cameraUpdateTargetLock:Null<Bool>;
    static var lastStatus:String = "Waiting for Farever";
    static inline var QUICK_CAST_DIAGNOSTIC_BUILD = "qc-diag-1";
    static inline var QUICK_CAST_DIAGNOSTIC_LIMIT = 60;
    static var quickCastDiagnosticLines:Int = 0;
    static var quickCastDiagnosticAttempts:Int = 0;
    static var quickCastDiagnosticStage:String = "startup";
    static var quickCastTraceSteps:Bool = false;
    static var quickCastTraceFirstPoll:Bool = false;
    static var quickCastTraceConfirmation:Bool = false;
    static var quickCastDiagnosticErrorReported:Bool = false;

    static function main():Void {
        quickCastLog("loaded");
        if (ConfigMigration.importLegacy()) loadConfig();
        config.save();
        quickCastLog("settings: enabled=" + config.enabled + ", quickCast=" + config.quickCast);
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

    @:hlx.prefix(client.UnitController.startTargetMode)
    static function beforeStartTargetMode(instance:Dynamic, skill:Dynamic, callback:Dynamic,
        input:Dynamic):HlxPrefixControl {
        quickCastDiagnosticAttempts++;
        if (quickCastDiagnosticAttempts <= 3)
            quickCastLog("aim " + quickCastDiagnosticAttempts + ": startTargetMode prefix reached");
        return Continue;
    }

    @:hlx.postfix(client.UnitController.startTargetMode)
    static function afterStartTargetMode(instance:Dynamic, skill:Dynamic, callback:Dynamic,
        input:Dynamic, result:Dynamic):Void {
        quickCastTraceSteps = quickCastDiagnosticAttempts <= 3;
        try {
            quickCastStage("startTargetMode postfix reached; reading enabled");
            var enabled = config.enabled;
            quickCastStage("enabled=" + enabled + "; reading quickCast");
            var quickCast = config.quickCast;
            quickCastStage("quickCast=" + quickCast + "; comparing controller");
            var localController = instance == lastController;
            quickCastStage("local controller=" + localController);
            if (enabled && quickCast && localController && input != null) {
                // Accept the hook argument dynamically so diagnostics can run before
                // any cross-module String conversion. Never stringify game objects.
                quickCastStage("checking input type");
                if (Std.isOfType(input, String)) {
                    var key:String = cast input;
                    quickCastStage("input=" + key + "; creating aiming state");
                    var aim:GroundAimInput = { controller: instance, key: key, released: false };
                    quickCastStage("aiming state created; storing state");
                    activeGroundAim = aim;
                    quickCastTraceFirstPoll = quickCastDiagnosticAttempts <= 3;
                    quickCastTraceConfirmation = quickCastTraceFirstPoll;
                    quickCastStage("aiming state armed");
                } else {
                    quickCastStage("input is not a String; type=" + Type.enumConstructor(Type.typeof(input)));
                }
            } else {
                quickCastStage("setup skipped; null input=" + (input == null));
            }
        } catch (error:Dynamic) {
            activeGroundAim = null;
            quickCastError(error);
        }
        quickCastTraceSteps = false;
    }

    @:hlx.prefix(client.UnitController.update)
    static function beforeControllerUpdate(instance:Dynamic, dt:Float):HlxPrefixControl {
        updatingController = instance;
        return Continue;
    }

    @:hlx.postfix(client.UnitController.update)
    static function afterControllerUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        updatingController = null;
        // Native aiming skips confirmation on its first frame. Capture a quick
        // tap's release here so the following aiming update can still confirm it.
        if (activeGroundAim != null && activeGroundAim.controller == instance)
            updateGroundAimRelease();
    }

    @:hlx.postfix(client.UnitController.setJob)
    static function afterControllerJobChanged(instance:Dynamic, job:Dynamic, update:Dynamic,
        onStop:Dynamic, result:Dynamic):Dynamic {
        if (activeGroundAim != null && activeGroundAim.controller == instance) {
            if (quickCastDiagnosticAttempts <= 3)
                quickCastLog("aim ended: controller job changed");
            activeGroundAim = null;
        }
        return result;
    }

    @:hlx.postfix(client.UnitController.onEnd)
    static function afterControllerEnd(instance:Dynamic, result:Void):Void {
        if (activeGroundAim != null && activeGroundAim.controller == instance)
            activeGroundAim = null;
    }

    @:hlx.prefix(lib.Input.isPressedWithoutMode)
    static function confirmGroundAimOnRelease(input:String):HlxPrefixResult<Bool> {
        if (activeGroundAim != null && activeGroundAim.controller == updatingController
            && input == activeGroundAim.key) {
            updateGroundAimRelease();
            if (activeGroundAim != null) {
                if (quickCastTraceConfirmation) {
                    quickCastLog("native confirmation query reached; released=" + activeGroundAim.released);
                    quickCastTraceConfirmation = false;
                }
                return SkipWith(activeGroundAim.released);
            }
        }
        return Continue;
    }

    static function updateGroundAimRelease():Void {
        quickCastTraceSteps = quickCastTraceFirstPoll;
        quickCastTraceFirstPoll = false;
        try {
            quickCastStage("release poll: checking settings and controller");
            if (!config.enabled || !config.quickCast || activeGroundAim.controller != lastController) {
                activeGroundAim = null;
            } else {
                quickCastStage("release poll: resolving input method");
                if (!resolveGroundAimInput() || !aimInputActive()) {
                    activeGroundAim.released = false;
                    quickCastStage("release poll paused: input unavailable or inactive");
                } else if (!activeGroundAim.released) {
                    var released = readAimInput(isReleasedMember, activeGroundAim.key);
                    activeGroundAim.released = released;
                    if (released && quickCastDiagnosticAttempts <= 3)
                        quickCastLog("release detected for " + activeGroundAim.key);
                }
            }
        } catch (error:Dynamic) {
            activeGroundAim = null;
            quickCastError(error);
        }
        quickCastTraceSteps = false;
    }

    static function resolveGroundAimInput():Bool {
        if (inputType == null)
            inputType = HlxRuntime.resolveType("lib.Input");
        if (inputType == null)
            return false;
        if (isReleasedMember == null)
            isReleasedMember = HlxRuntime.resolveStaticMember(inputType, "isReleased");
        return isReleasedMember != null;
    }

    static function aimInputActive():Bool {
        quickCastStage("reading Input.checkActive");
        var checkActive:Dynamic = HlxRuntime.resolveStaticField(inputType, "checkActive");
        quickCastStage("calling Input.checkActive");
        return checkActive != null && Reflect.callMethod(null, checkActive, [null]) == true;
    }

    static function readAimInput(member:hlx.runtime.ResolvedMember, input:String):Bool {
        // Target mode blocks ordinary skill inputs. Match the native
        // isPressedWithoutMode query while retaining binding and focus handling.
        quickCastStage("reading input mode flag");
        var previous:Dynamic = HlxRuntime.resolveStaticField(inputType, "_noCheckMode");
        quickCastStage("setting input mode flag");
        HlxRuntime.setStaticField(inputType, "_noCheckMode", true);
        var result:Dynamic;
        try {
            quickCastStage("calling Input.isReleased");
            result = HlxRuntime.callResolved(member, [input]);
        } catch (error:Dynamic) {
            HlxRuntime.setStaticField(inputType, "_noCheckMode", previous);
            throw error;
        }
        quickCastStage("restoring input mode flag");
        HlxRuntime.setStaticField(inputType, "_noCheckMode", previous);
        return result == true;
    }

    static inline function quickCastStage(stage:String):Void {
        quickCastDiagnosticStage = stage;
        if (quickCastTraceSteps)
            quickCastLog(stage);
    }

    static function quickCastError(error:Dynamic):Void {
        // Contain repeated failures inside the mod instead of generating a
        // Dispatcher error on every aiming update. The first failure identifies the stage.
        if (quickCastDiagnosticErrorReported)
            return;
        quickCastDiagnosticErrorReported = true;
        quickCastLog("ERROR at " + quickCastDiagnosticStage + ": " + Std.string(error));
    }

    static function quickCastLog(message:String):Void {
        if (quickCastDiagnosticLines >= QUICK_CAST_DIAGNOSTIC_LIMIT)
            return;
        quickCastDiagnosticLines++;
        if (quickCastDiagnosticLines == QUICK_CAST_DIAGNOSTIC_LIMIT)
            trace("[QuickCast " + QUICK_CAST_DIAGNOSTIC_BUILD + "] diagnostic limit reached; further messages suppressed");
        else
            trace("[QuickCast " + QUICK_CAST_DIAGNOSTIC_BUILD + "] " + message);
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
        quickCastLog("settings changed: enabled=" + config.enabled + ", quickCast=" + config.quickCast);
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
