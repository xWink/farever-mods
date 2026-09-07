package dpsmeter;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

class MeterConfig {
    public static inline var PATH = "hlx/mods/dps-meter/config.json";
    public var enabled:Bool = true;
    public var visible:Bool = true;
    public var unlocked:Bool = false;
    public var sendLogs:Bool = true;
    public var debug:Bool = false;
    public var me:String = "";
    public var group:String = "";
    public var x:Float = 60;
    public var y:Float = 220;
    public var width:Int = 440;
    public var height:Int = 340;
    public var toggleHotkey:Int = 121;
    public var unlockHotkey:Int = 122;
    public function new() {}
    public function load():Void {
        if (!FileSystem.exists(PATH)) {
            importLegacy();
            save();
            return;
        }
        try {
            var data:Dynamic = Json.parse(File.getContent(PATH));
            for (key in ["enabled", "visible", "unlocked", "sendLogs", "debug"])
                if (Std.isOfType(Reflect.field(data, key), Bool)) Reflect.setField(this, key, Reflect.field(data, key));
            for (key in ["me", "group"])
                if (Std.isOfType(Reflect.field(data, key), String)) Reflect.setField(this, key, Reflect.field(data, key));
            for (key in ["x", "y", "width", "height", "toggleHotkey", "unlockHotkey"]) {
                var value:Dynamic = Reflect.field(data, key);
                if (value != null && Math.isFinite(Std.parseFloat(Std.string(value))))
                    Reflect.setField(this, key, key == "x" || key == "y" ? Std.parseFloat(Std.string(value)) : Std.int(value));
            }
            width = Std.int(Math.max(360, Math.min(1200, width)));
            height = Std.int(Math.max(220, Math.min(1000, height)));
        } catch (e:Dynamic) trace("[DpsMeter] Could not read settings: " + e);
    }
    function importLegacy():Void {
        if (!FileSystem.exists("group-dps.ini")) return;
        for (line in File.getContent("group-dps.ini").split("\n")) {
            var p = line.indexOf("=");
            if (p < 0) continue;
            var key = StringTools.trim(line.substr(0, p));
            var value = StringTools.trim(line.substr(p + 1));
            var n = Std.parseInt(value);
            switch (key) {
                case "me": me = value;
                case "group": group = value;
                case "send_logs": sendLogs = n != 0;
                case "debug": debug = n == 1;
                case "overlay_x": if (n != null) x = n;
                case "overlay_y": if (n != null) y = n;
                case "overlay_w": if (n != null) width = Std.int(Math.max(360, n));
                case "overlay_h": if (n != null && n > 0) height = Std.int(Math.max(220, n));
                default:
            }
        }
    }
    public function save():Void {
        try File.saveContent(PATH, Json.stringify({enabled: enabled, visible: visible, unlocked: unlocked,
            sendLogs: sendLogs, debug: debug, me: me, group: group, x: x, y: y,
            width: width, height: height, toggleHotkey: toggleHotkey, unlockHotkey: unlockHotkey}, null, "  "))
        catch (e:Dynamic) trace("[DpsMeter] Could not save settings: " + e);
    }
}
