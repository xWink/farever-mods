package disableprofanityfilter;

import haxe.Json;
import hlx.runtime.Bus;
import hlx.runtime.HlxPrefixResult;
import sys.FileSystem;
import sys.io.File;

@:build(hlx.runtime.Mod.build())
class DisableProfanityFilterMod {
    static inline var CONFIG_PATH = "hlx/mods/disable-profanity-filter/config.json";
    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";

    static var disableProfanityFilter:Bool = true;

    static function main():Void {
        loadConfig();
        saveConfig();
        Bus.subscribe(
            SETTINGS_CHANGED_TOPIC_PREFIX + HlxRuntime.moduleName(),
            onBetterModSettingsChanged
        );
    }

    static function onBetterModSettingsChanged(_:Dynamic):Void {
        loadConfig();
    }

    // Farever's chat messages and speech bubbles pass through cleanPlayerText.
    // Return the original text with the game's HTML escaping still applied, so
    // only profanity replacement is bypassed. Character-name validation uses
    // detectBadWord directly and therefore remains unchanged.
    @:hlx.prefix(HText.cleanPlayerText)
    static function beforeCleanPlayerText(text:String):HlxPrefixResult<String> {
        if (!disableProfanityFilter)
            return Continue;
        return SkipWith(StringTools.htmlEscape(text));
    }

    static function loadConfig():Void {
        try {
            if (!FileSystem.exists(CONFIG_PATH))
                return;

            var data:Dynamic = Json.parse(File.getContent(CONFIG_PATH));
            if (Reflect.hasField(data, "disableProfanityFilter"))
                disableProfanityFilter = Reflect.field(data, "disableProfanityFilter");
        } catch (_:Dynamic) {}
    }

    static function saveConfig():Void {
        try {
            var data = {
                disableProfanityFilter: disableProfanityFilter
            };
            File.saveContent(CONFIG_PATH, Json.stringify(data, null, "  "));
        } catch (_:Dynamic) {}
    }
}
