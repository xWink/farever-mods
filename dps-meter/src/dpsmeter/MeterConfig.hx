package dpsmeter;

import sys.FileSystem;
import sys.io.File;

typedef MeterSettings = {
    var enabled:Bool;
    var visible:Bool;
    var transparency:Int;
    var hideOutOfCombat:Bool;
    var hideDelay:Int;
    var showBossKills:Bool;
    var showIncompleteCodexKills:Bool;
    var showCompletedCodexKills:Bool;
    var unlocked:Bool;
    var sendLogs:Bool;
    var debug:Bool;
    var me:String;
    var group:String;
    var x:Float;
    var y:Float;
    var width:Int;
    var height:Int;
    var toggleHotkey:Int;
    var unlockHotkey:Int;
}

/** Meter-specific defaults, size limits and original DLL configuration import. */
class MeterConfig {
    public static inline var MIN_HEIGHT:Int = 110;

    public static function defaults():MeterSettings return {
        enabled: true,
        visible: true,
        transparency: 0,
        hideOutOfCombat: false,
        hideDelay: 3,
        showBossKills: true,
        showIncompleteCodexKills: true,
        showCompletedCodexKills: false,
        unlocked: false,
        sendLogs: true,
        debug: false,
        me: "",
        group: "",
        x: 60,
        y: 220,
        width: 440,
        height: 340,
        toggleHotkey: 121,
        unlockHotkey: 122
    };

    public static function normalize(config:MeterSettings):Void {
        config.transparency = Std.int(Math.max(0, Math.min(100, config.transparency)));
        config.width = Std.int(Math.max(360, Math.min(1200, config.width)));
        config.height = Std.int(Math.max(MIN_HEIGHT, Math.min(1000, config.height)));
        config.hideDelay = Std.int(Math.max(0, Math.min(10, config.hideDelay)));
    }

    public static function importLegacy(config:MeterSettings):Void {
        if (!FileSystem.exists("group-dps.ini")) return;
        for (line in File.getContent("group-dps.ini").split("\n")) {
            var p = line.indexOf("=");
            if (p < 0) continue;
            var key = StringTools.trim(line.substr(0, p));
            var value = StringTools.trim(line.substr(p + 1));
            var n = Std.parseInt(value);
            switch (key) {
                case "me": config.me = value;
                case "group": config.group = value;
                case "send_logs": config.sendLogs = n != 0;
                case "debug": config.debug = n == 1;
                case "overlay_x": if (n != null) config.x = n;
                case "overlay_y": if (n != null) config.y = n;
                case "overlay_w": if (n != null) config.width = Std.int(Math.max(360, n));
                case "overlay_h": if (n != null && n > 0) config.height = Std.int(Math.max(MIN_HEIGHT, n));
                default:
            }
        }
    }
}
