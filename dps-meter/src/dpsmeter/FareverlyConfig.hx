package dpsmeter;

import fareverly.Protocol;
import dpsmeter.MeterConfig.MeterSettings;
import sys.FileSystem;
import sys.io.File;

/** Only the API-key string is persisted, in the ordinary DPS Meter config. */
class FareverlyConfig {
    public static inline var PATH = "hlx/config/dps-meter/config.json";
    static final unsupportedFields = ["fareverlyAccountId", "fareverlySteamId", "fareverlyExpiresAt", "fareverlyKeyFingerprint"];

    public static function key(config:Dynamic):String {
        var value = Reflect.field(config, "fareverlyApiKey");
        return Std.isOfType(value, String) ? value : "";
    }
    public static function read(?path:String):String {
        if (path == null) path = PATH;
        if (!FileSystem.exists(path)) return "";
        try {
            var saved:Dynamic = haxe.Json.parse(File.getContent(path));
            // Do not use rejected credentials even if startup could not save
            // the cleaned config (for example, a read-only file).
            for (field in unsupportedFields) if (Reflect.hasField(saved, field)) return "";
            return key(saved);
        }
        catch (_:Dynamic) throw "DPS Meter settings could not be read.";
    }
    public static function apply(config:MeterSettings, value:Credential, expectedKey:String):Bool {
        if (key(config) != expectedKey) return false;
        config.fareverlyApiKey = value.accessToken;
        return true;
    }
    public static function discardUnsupported(config:MeterSettings, ?path:String):Bool {
        if (path == null) path = PATH;
        // Reject the previous metadata format, including keys it imported.
        // Never open the former shared credential file. Normal config.save()
        // removes these unsupported fields, so new key-only settings survive.
        if (!FileSystem.exists(path)) return false;
        try {
            var saved:Dynamic = haxe.Json.parse(File.getContent(path));
            for (field in unsupportedFields) if (Reflect.hasField(saved, field)) {
                config.fareverlyApiKey = "";
                return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }
}
