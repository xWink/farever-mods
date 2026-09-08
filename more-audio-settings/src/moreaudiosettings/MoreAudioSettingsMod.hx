package moreaudiosettings;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import modconfig.ConfigMigration;
import hlx.runtime.ResolvedMember;

typedef MoreAudioSettingsConfig = {
    var adjustUnfocusedVolume:Bool;
    var backgroundVolume:Float;
}

@:build(hlx.runtime.Mod.build())
class MoreAudioSettingsMod {
    @:hlx.config
    static var config:MoreAudioSettingsConfig = {
        adjustUnfocusedVolume: true,
        backgroundVolume: 0.0
    };

    static inline var MASTER_VCA = "vca:/MASTER";
    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";

    static var lastFocused:Bool = true;
    static var mutedByUs:Bool = false;
    static var savedMasterVolume:Float = 1.0;

    static var windowType:hl.Bytes;
    static var windowGetInstance:ResolvedMember;
    static var windowGetIsFocused:ResolvedMember;
    static var fmodApiType:hl.Bytes;
    static var getVcaVolumeMember:ResolvedMember;
    static var setVcaVolumeMember:ResolvedMember;

    static function main():Void {
        if (ConfigMigration.importLegacy("mute-unfocused")) loadConfig();
        // Import the old toggle only when its replacement has not been saved.
        var previous = ModConfig.load(HlxRuntime.moduleName(), {
            enabled: config.adjustUnfocusedVolume,
            adjustUnfocusedVolume: (null:Null<Bool>)
        });
        if (previous.adjustUnfocusedVolume == null)
            config.adjustUnfocusedVolume = previous.enabled;
        config.backgroundVolume = clamp(config.backgroundVolume, 0.0, 100.0);
        config.save();
        Bus.subscribe(
            SETTINGS_CHANGED_TOPIC_PREFIX + HlxRuntime.moduleName(),
            onBetterModSettingsChanged
        );
    }

    static function ensureBindings():Bool {
        if (windowGetInstance != null && windowGetIsFocused != null
            && getVcaVolumeMember != null && setVcaVolumeMember != null)
            return true;

        windowType = HlxRuntime.resolveType("hxd.Window");
        fmodApiType = HlxRuntime.resolveType("fmod.Api");
        if (windowType == null || fmodApiType == null)
            return false;

        windowGetInstance = HlxRuntime.resolveStaticMember(windowType, "getInstance");
        windowGetIsFocused = HlxRuntime.resolveMember(windowType, "get_isFocused");
        getVcaVolumeMember = HlxRuntime.resolveStaticMember(fmodApiType, "getVcaVolume");
        setVcaVolumeMember = HlxRuntime.resolveStaticMember(fmodApiType, "setVcaVolume");

        return windowGetInstance != null && windowGetIsFocused != null
            && getVcaVolumeMember != null && setVcaVolumeMember != null;
    }

    @:hlx.postfix(GameApp.update)
    static function afterGameAppUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        if (!ensureBindings())
            return;

        var focused = isGameFocused();
        if (focused != lastFocused) {
            lastFocused = focused;

            if (focused) {
                if (mutedByUs)
                    restoreVolume();
            } else if (config.adjustUnfocusedVolume && !mutedByUs) {
                applyBackgroundVolume();
            }
        }

        if (!config.adjustUnfocusedVolume && mutedByUs)
            restoreVolume();
    }

    static function isGameFocused():Bool {
        if (!ensureBindings())
            return true;

        var window:Dynamic = HlxRuntime.callResolved(windowGetInstance, []);
        if (window == null)
            return true;

        return cast HlxRuntime.callResolved(windowGetIsFocused, [window]);
    }

    static function getMasterVolume():Float {
        if (!ensureBindings())
            return 1.0;
        return cast HlxRuntime.callResolved(getVcaVolumeMember, [MASTER_VCA]);
    }

    static function setMasterVolume(volume:Float):Void {
        if (ensureBindings())
            HlxRuntime.callResolved(setVcaVolumeMember, [MASTER_VCA, volume]);
    }

    static function applyBackgroundVolume():Void {
        savedMasterVolume = getMasterVolume();
        setMasterVolume(config.backgroundVolume / 100.0);
        mutedByUs = true;
    }

    static function restoreVolume():Void {
        setMasterVolume(savedMasterVolume);
        mutedByUs = false;
    }

    static function onBetterModSettingsChanged(_:Dynamic):Void {
        loadConfig();
    }

    static function loadConfig():Void {
        config = ModConfig.load(HlxRuntime.moduleName(), config);
        config.backgroundVolume = clamp(config.backgroundVolume, 0.0, 100.0);
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    static inline function clampInt(value:Int, min:Int, max:Int):Int {
        return value < min ? min : (value > max ? max : value);
    }
}
