package moresettings;

import haxe.ds.ObjectMap;
import moresettings.GameAccess as G;

private typedef TimestampRow = {
    var message:Dynamic;
    var label:Dynamic;
    var prefix:String;
    var original:String;
    var displayed:String;
}

/** Decorate rendered chat rows without changing messages, history or outgoing text. */
class ChatTimestamps {
    static var enabled = false;
    static var rows:ObjectMap<Dynamic, TimestampRow> = new ObjectMap();

    public static function configure(value:Bool):Void {
        if (value == enabled) return;
        enabled = value;
        for (row in rows) apply(row);
    }

    public static function attach(instance:Dynamic):Void {
        // Native init may rebuild a row. Capture its newly generated markup.
        var previous = rows.get(instance);
        rows.remove(instance);
        var message = G.field(instance, "message");
        var channel = G.field(message, "channel");
        if (channel == null) return;
        switch (Type.enumConstructor(channel)) {
            // These two channels already get native [HH:MM] timestamps.
            case "System", "AllSystem": return;
            case "Local", "All", "Group", "Player":
            default: return;
        }
        var label = G.field(instance, "msgText");
        if (label == null) return;
        var original = rawText(label);
        if (previous != null && previous.message == message && previous.label == label
            && previous.displayed == original) {
            rows.set(instance, previous);
            apply(previous);
            return;
        }
        var row:TimestampRow = {message: message, label: label,
            prefix: prefix(G.number(G.field(message, "localStamp"), Math.NaN),
                haxe.Timer.stamp(), Date.now().getTime()),
            original: original, displayed: original};
        rows.set(instance, row);
        apply(row);
    }

    /** localStamp is the game's monotonic receipt time, not Unix time. */
    public static function prefix(localStamp:Float, now:Float, wallTime:Float):String {
        var elapsed = Math.isFinite(localStamp) && Math.isFinite(now) ? Math.max(0, now - localStamp) : 0;
        var date = Date.fromTime(wallTime - elapsed * 1000);
        return "[" + StringTools.lpad(Std.string(date.getHours()), "0", 2) + ":"
            + StringTools.lpad(Std.string(date.getMinutes()), "0", 2) + "] ";
    }

    static function rawText(label:Dynamic):String {
        // FmtText retains input markup separately from HtmlText's formatted text.
        // Reusing that input avoids applying the native formatter twice.
        var value = G.field(label, "prevUnformatted");
        return G.text(value == null ? G.field(label, "text") : value);
    }

    static function apply(row:TimestampRow):Void {
        var current = rawText(row.label);
        // Preserve another UI writer's replacement when toggling this option.
        if (current != row.displayed) row.original = current;
        var next = enabled ? row.prefix + row.original : row.original;
        if (current != next) G.call("ui.comp.FmtText", "set_text", row.label, [next]);
        row.displayed = next;
    }

    public static function forget(instance:Dynamic):Void rows.remove(instance);
    public static function dispose():Void rows = new ObjectMap();
}
