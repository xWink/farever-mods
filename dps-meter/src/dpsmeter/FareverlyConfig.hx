package dpsmeter;

import fareverly.Protocol;
import modconfig.CommonSettings;

/** The common API-key string is the only persisted Fareverly credential. */
class FareverlyConfig {
    public static inline var KEY = "fareverlyApiKey";
    public static function read(?path:String):String {
        var value = Reflect.field(CommonSettings.read(path), KEY);
        return Std.isOfType(value, String) ? value : "";
    }
    public static function save(value:Credential, expectedKey:String, ?path:String):Bool {
        // Called on the game thread, alongside BMS edits. A delayed browser
        // response must not replace text the player edited in the meantime.
        if (read(path) != expectedKey) return false;
        CommonSettings.write(KEY, value.accessToken, path);
        return true;
    }
}
