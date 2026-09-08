package disableprofanityfilter;

import hlx.runtime.Bus;
import hlx.runtime.ModConfig;
import modconfig.ConfigMigration;
import hlx.runtime.HlxPrefixResult;

typedef ProfanityConfig = {
    var disableProfanityFilter:Bool;
}

@:build(hlx.runtime.Mod.build())
class DisableProfanityFilterMod {
    @:hlx.config
    static var config:ProfanityConfig = {
        disableProfanityFilter: true
    };

    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";

    static function main():Void {
        if (ConfigMigration.importLegacy()) loadConfig();
        config.save();
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
        if (!config.disableProfanityFilter)
            return Continue;
        return SkipWith(StringTools.htmlEscape(text));
    }

    static function loadConfig():Void {
        config = ModConfig.load(HlxRuntime.moduleName(), config);
    }
}
