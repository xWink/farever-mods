package muteunfocused;

import haxe.Json;
import hlx.runtime.Bus;
import hlx.runtime.ResolvedMember;
import sys.FileSystem;
import sys.io.File;

@:build(hlx.runtime.Mod.build())
class MuteUnfocusedMod {
    static inline var MASTER_VCA = "vca:/MASTER";
    static inline var CONFIG_PATH = "hlx/mods/mute-unfocused/config.json";
    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";

    static var enabled:Bool = true;
    static var backgroundVolume:Float = 0.0;

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
        loadConfig();
        saveConfig();
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
            } else if (enabled && !mutedByUs) {
                applyBackgroundVolume();
            }
        }

        if (!enabled && mutedByUs)
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
        setMasterVolume(backgroundVolume / 100.0);
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
        try {
            if (!FileSystem.exists(CONFIG_PATH))
                return;

            var data:Dynamic = Json.parse(File.getContent(CONFIG_PATH));
            if (Reflect.hasField(data, "enabled"))
                enabled = Reflect.field(data, "enabled");
            if (Reflect.hasField(data, "backgroundVolume"))
                backgroundVolume = clamp(cast Reflect.field(data, "backgroundVolume"), 0.0, 100.0);

        } catch (_:Dynamic) {}
    }

    static function saveConfig():Void {
        try {
            var data = {
                enabled: enabled,
                backgroundVolume: backgroundVolume
            };
            File.saveContent(CONFIG_PATH, Json.stringify(data, null, "  "));
        } catch (_:Dynamic) {}
    }

    static inline function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    static inline function clampInt(value:Int, min:Int, max:Int):Int {
        return value < min ? min : (value > max ? max : value);
    }
}
