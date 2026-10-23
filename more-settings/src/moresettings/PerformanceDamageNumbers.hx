package moresettings;

import moresettings.GameAccess as G;

/** Skip excessive cosmetic floating widgets without touching combat events. */
class PerformanceDamageNumbers {
    public static var enabled:Bool = false;
    static var budget = new VisualDamageBudget();
    static var failed = false;
    static var warned = false;
    static var limit:Int = 20;
    public static function configure(active:Bool, amount:Int):Void {
        var count=Std.int(Math.max(0,Math.min(200,amount)));
        if (enabled != active || count != limit) reset();
        enabled=active;limit=count;budget.configure(count);
    }
    public static function reset():Void { budget.reset(); failed = false; warned = false; }
    public static function suppress():Bool {
        if (limit == 0) return true;
        if (!enabled || failed) return false;
        try {
            var skip = !budget.allow(haxe.Timer.stamp(), widget -> G.field(widget, "parent") != null);
            if (skip && !warned) {
                warned = true;
                trace("[More Settings] Performance: floating numbers limited to "+Std.string(limit)+" active and new per second.");
            }
            return skip;
        } catch (e:Dynamic) {
            failed = true; budget.reset();
            trace("[More Settings] Damage number budget disabled: " + Std.string(e));
            return false;
        }
    }
    public static function created(widget:Dynamic):Void {
        if (enabled && limit > 0 && !failed) budget.created(widget);
    }
}
