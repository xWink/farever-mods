package moresettings;

import moresettings.GameAccess as G;

/** Skip excessive cosmetic floating widgets without touching combat events. */
class PerformanceDamageNumbers {
    public static var enabled:Bool = false;
    static var budget = new VisualDamageBudget();
    static var failed = false;
    static var limit:Int = -1;
    public static function configure(amount:Int):Void {
        var count=amount < 0 ? -1 : amount;
        var active=count >= 0;
        if (enabled != active || count != limit) reset();
        enabled=active;limit=count;
        if (active) budget.configure(count);
    }
    public static function reset():Void { budget.reset(); failed = false; }
    public static function suppress():Bool {
        if (limit == 0) return true;
        if (!enabled || failed) return false;
        try {
            return !budget.allow(haxe.Timer.stamp(), widget -> G.field(widget, "parent") != null);
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
