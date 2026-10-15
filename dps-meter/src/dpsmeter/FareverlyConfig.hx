package dpsmeter;

import fareverly.Protocol;
import dpsmeter.MeterConfig.MeterSettings;
import sys.FileSystem;
import sys.io.File;

/** Fareverly is an ordinary DPS Meter setting; only the game thread saves it. */
class FareverlyConfig {
    public static inline var PATH = "hlx/config/dps-meter/config.json";
    static inline var LEGACY_PATH = "hlx/config/fareverly/account.json";

    public static function key(config:Dynamic):String {
        var value = Reflect.field(config, "fareverlyApiKey");
        return Std.isOfType(value, String) ? value : "";
    }
    static function text(config:Dynamic, name:String):String {
        var value = Reflect.field(config, name);
        return Std.isOfType(value, String) ? value : "";
    }
    public static function credential(config:Dynamic):Credential {
        var token = key(config);
        // Partial edits and a newly pasted key must be verified before uploading.
        // Metadata for the previous key must never authorize a replacement key.
        if (!Protocol.validKey(token) || text(config, "fareverlyKeyFingerprint") != haxe.crypto.Sha256.encode(token))
            return Protocol.empty();
        return {accessToken:token, accountId:text(config, "fareverlyAccountId"),
            steamId:text(config, "fareverlySteamId"), expiresAt:text(config, "fareverlyExpiresAt")};
    }
    public static function read(?path:String):Credential {
        if (path == null) path = PATH;
        if (!FileSystem.exists(path)) return Protocol.empty();
        try return credential(haxe.Json.parse(File.getContent(path)))
        catch (_:Dynamic) throw "DPS Meter settings could not be read.";
    }
    public static function apply(config:MeterSettings, value:Credential, expectedKey:String):Bool {
        if (key(config) != expectedKey) return false;
        config.fareverlyApiKey = value.accessToken;
        config.fareverlyAccountId = value.accountId;
        config.fareverlySteamId = value.steamId;
        config.fareverlyExpiresAt = value.expiresAt;
        config.fareverlyKeyFingerprint = value.accessToken == "" ? "" : haxe.crypto.Sha256.encode(value.accessToken);
        return true;
    }
    public static function importLegacy(config:MeterSettings, ?configPath:String, ?legacyPath:String):Bool {
        if (configPath == null) configPath = PATH;
        if (legacyPath == null) legacyPath = LEGACY_PATH;
        try {
            // An existing field, even an intentionally cleared one, wins.
            if (key(config) != "") return false;
            if (FileSystem.exists(configPath)
                && Reflect.hasField(haxe.Json.parse(File.getContent(configPath)), "fareverlyApiKey")) return false;
            if (!FileSystem.exists(legacyPath) || FileSystem.stat(legacyPath).size > 4096) return false;
            var value:Credential = haxe.Json.parse(File.getContent(legacyPath));
            if (value == null || !Protocol.validKey(value.accessToken) || !Protocol.validAccount(value.accountId)
                || !Std.isOfType(value.steamId, String) || !Std.isOfType(value.expiresAt, String)) return false;
            // Keep the legacy file untouched as a backup. Nothing writes or polls it.
            return apply(config, value, "");
        } catch (_:Dynamic) {
            trace("[DPS Meter] Could not import the previous Fareverly key; existing files were kept.");
            return false;
        }
    }
}
