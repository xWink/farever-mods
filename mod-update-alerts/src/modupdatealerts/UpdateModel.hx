package modupdatealerts;

typedef InstalledMod = {
    var name:String;
    var domain:String;
    var modId:Int;
    var version:String;
}

typedef AvailableUpdate = {
    var name:String;
    var domain:String;
    var modId:Int;
    var current:String;
    var latest:String;
    @:optional var changelog:String;
}

class UpdateModel {
    public static function identity(domain:String, modId:Int):String return domain + "/" + modId;

    /** Numeric releases and SemVer prereleases; unknown schemes are not guessed. */
    public static function compare(a:String, b:String):Null<Int> {
        var left = parse(a), right = parse(b);
        if (left == null || right == null) return null;
        var count = Std.int(Math.max(left.parts.length, right.parts.length));
        for (i in 0...count) {
            var x = i < left.parts.length ? left.parts[i] : 0;
            var y = i < right.parts.length ? right.parts[i] : 0;
            if (x != y) return x > y ? 1 : -1;
        }
        if (left.pre == right.pre) return 0;
        if (left.pre == "") return 1;
        if (right.pre == "") return -1;
        var x = left.pre.split("."), y = right.pre.split(".");
        for (i in 0...Std.int(Math.max(x.length, y.length))) {
            if (i >= x.length) return -1;
            if (i >= y.length) return 1;
            if (x[i] == y[i]) continue;
            var xn = ~/^[0-9]+$/.match(x[i]), yn = ~/^[0-9]+$/.match(y[i]);
            if (xn && yn) {
                var xv = Std.parseFloat(x[i]), yv = Std.parseFloat(y[i]);
                if (xv != yv) return xv > yv ? 1 : -1;
                continue;
            }
            if (xn != yn) return xn ? -1 : 1;
            return Reflect.compare(x[i], y[i]);
        }
        return 0;
    }

    static function parse(value:String):Null<{parts:Array<Float>, pre:String}> {
        if (value == null || value.length > 80) return null;
        var pattern = ~/^[vV]?([0-9]+(?:\.[0-9]+)*)(?:-([0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*))?(?:\+[0-9A-Za-z.-]+)?$/;
        if (!pattern.match(StringTools.trim(value))) return null;
        var parts = [for (v in pattern.matched(1).split(".")) Std.parseFloat(v)];
        for (part in parts) if (!Math.isFinite(part) || part > 9007199254740991.) return null;
        return {parts: parts, pre: pattern.matched(2) == null ? "" : pattern.matched(2)};
    }

    public static function needsReminder(updates:Array<AvailableUpdate>, dismissed:Map<String,String>):Bool {
        for (update in updates) {
            var previous = dismissed.get(identity(update.domain, update.modId));
            if (previous == null) return true;
            var comparison = compare(update.latest, previous);
            if (comparison == null ? update.latest != previous : comparison > 0) return true;
        }
        return false;
    }

    public static function dismiss(updates:Array<AvailableUpdate>, dismissed:Map<String,String>):Void {
        for (update in updates) {
            var key = identity(update.domain, update.modId);
            var old = dismissed.get(key);
            var comparison = old == null ? null : compare(update.latest, old);
            if (old == null || comparison == null || comparison > 0) dismissed.set(key, update.latest);
        }
    }
}
