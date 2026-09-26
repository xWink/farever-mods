package moresettings;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import hlx.runtime.HlxPrefixResult;
import modconfig.ConfigMigration;
import moresettings.GameAccess as G;
import moresettings.SettingsData.MoreSettingsConfig;

@:build(hlx.runtime.Mod.build())
class MoreSettingsMod {
    @:hlx.config
    static var config:MoreSettingsConfig = SettingsData.defaults();
    static var audio:AudioControl;
    static var hideUi = new HideUiBinding();
    static var reportedInputError:Bool = false;
    static var app:Dynamic;
    static var reportedAudioError:Bool = false;
    static var audioRetryAt:Float = 0;

    static function main():Void {
        var imported = ConfigMigration.importLegacy("more-audio-settings");
        if (!imported) imported = ConfigMigration.importLegacy("mute-unfocused");
        if (!imported) imported = ConfigMigration.importLegacy();
        if (imported) config = ModConfig.load(HlxRuntime.moduleName(), config);
        var previous = ModConfig.load(HlxRuntime.moduleName(), {
            enabled: config.adjustUnfocusedVolume,
            adjustUnfocusedVolume: (null:Null<Bool>),
            disableProfanityFilter: (null:Null<Bool>)
        });
        if (previous.adjustUnfocusedVolume == null) config.adjustUnfocusedVolume = previous.enabled;
        if (previous.disableProfanityFilter == null) {
            // Preserve the standalone mod's preference when combining installs.
            config.disableProfanityFilter = previousProfanityPreference();
        }
        SettingsData.normalize(config);
        BossHealth.enabled = config.showBossHealth;
        PerformanceHooks.enabled = config.performanceOptimization;
        hideUi.configure(config.hideUiKey);
        config.save();
        audio = new AudioControl(config);
        AllyEffects.configure(config);
        Bus.subscribe("better-mod-settings/config-changed/" + HlxRuntime.moduleName(), (_:Dynamic) -> {
            config = ModConfig.load(HlxRuntime.moduleName(), config);
            SettingsData.normalize(config);
            BossHealth.enabled = config.showBossHealth;
            PerformanceHooks.enabled = config.performanceOptimization;
            hideUi.configure(config.hideUiKey);
            AllyEffects.configure(config);
            try audio.configure(config) catch (e:Dynamic) audioError(e);
            audioRetryAt = 0;
        });
    }

    @:hlx.prefix(HText.cleanPlayerText)
    static function cleanPlayerText(text:String):HlxPrefixResult<String> {
        return config.disableProfanityFilter ? SkipWith(StringTools.htmlEscape(text)) : Continue;
    }

    @:hlx.postfix(ui.comp.HealthBar.init)
    static function afterHealthBarInit(instance:Dynamic, result:Void):Void {
        try BossHealth.attach(instance) catch (e:Dynamic) BossHealth.reportError(e);
    }

    @:hlx.postfix(lib.Input.getBindings)
    static function hideUiBindings(key:String, result:Dynamic):Dynamic {
        try return hideUi.bindings(key, result) catch (e:Dynamic) inputError(e);
        return result;
    }

    @:hlx.postfix(lib.Input.isPressed)
    static function hideUiPressed(key:String, result:Bool):Bool {
        try return hideUi.pressed(key, result) catch (e:Dynamic) inputError(e);
        return result;
    }

    @:hlx.prefix(GameApp.update)
    static function beforeUpdate(instance:Dynamic, dt:Float):HlxPrefixResult<Void> {
        app = instance;
        PerformanceHooks.update(instance);
        AllyEffects.update(instance);
        if (audio != null && haxe.Timer.stamp() >= audioRetryAt)
            try audio.update(G.field(instance, "hero")) catch (e:Dynamic) audioError(e);
        return Continue;
    }

    // The original creates flySoundObj. Adjust its event before the next audio update.
    @:hlx.postfix(ent.Hero.onStartFlyPath)
    static function afterTravel(instance:Dynamic, result:Void):Void {
        if (audio != null && instance == G.field(app, "hero"))
            try audio.startTravel(instance) catch (e:Dynamic) audioError(e);
    }

    @:hlx.postfix(Options.applyAudio)
    static function afterAudioSettings(result:Void):Void {
        if (audio != null) try audio.masterChanged() catch (e:Dynamic) audioError(e);
    }

    @:hlx.prefix(GameApp.dispose)
    static function dispose(instance:Dynamic):HlxPrefixResult<Void> {
        if (audio != null) try audio.dispose() catch (e:Dynamic) audioError(e);
        AllyEffects.dispose();
        PerformanceHooks.dispose();
        app = null;
        return Continue;
    }

    static function previousProfanityPreference():Bool {
        for (path in ["hlx/config/disable-profanity-filter/config.json", "hlx/mods/disable-profanity-filter/config.json"]) {
            if (!sys.FileSystem.exists(path)) continue;
            try {
                var old:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
                var value = Reflect.field(old, "disableProfanityFilter");
                if (Std.isOfType(value, Bool)) return value;
            } catch (_:Dynamic) {}
        }
        return true;
    }

    static function audioError(error:Dynamic):Void {
        audioRetryAt = haxe.Timer.stamp() + 5;
        if (!reportedAudioError) {
            reportedAudioError = true;
            trace("[More Settings] Audio: " + Std.string(error));
        }
    }

    static function inputError(error:Dynamic):Void {
        if (!reportedInputError) {
            reportedInputError = true;
            trace("[More Settings] Hide UI binding: " + Std.string(error));
        }
    }
}
