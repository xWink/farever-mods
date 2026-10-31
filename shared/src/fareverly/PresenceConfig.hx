package fareverly;

import modconfig.CommonSettings;

/** Read by each HTTP worker immediately before sending its next heartbeat. */
class PresenceConfig {
    public static inline var KEY = "fareverlyAppearBusy";
    public static function busy(?path:String):Bool {
        try {return Reflect.field(CommonSettings.read(path),KEY)==true;}
        catch(_:Dynamic){return false;}
    }
}
