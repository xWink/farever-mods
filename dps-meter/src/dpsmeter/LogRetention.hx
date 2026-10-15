package dpsmeter;

class LogRetention {
    public static function months(value:Int):Int return Std.int(Math.max(1, Math.min(24, value)));
    public static function cutoff(now:Date, age:Int):Float {
        var month = now.getMonth() - months(age);
        var year = now.getFullYear() + Std.int(Math.floor(month / 12));
        month = (month % 12 + 12) % 12;
        var leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
        var days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        var day = Std.int(Math.min(now.getDate(), days[month]));
        return new Date(year, month, day, now.getHours(), now.getMinutes(), now.getSeconds()).getTime();
    }
    public static function expired(startedAt:Float, before:Float):Bool
        return Math.isFinite(startedAt) && startedAt > 0 && startedAt < before;
}
