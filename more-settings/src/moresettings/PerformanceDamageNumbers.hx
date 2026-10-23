package moresettings;

import moresettings.GameAccess as G;

/** Skip excessive cosmetic floating widgets without touching combat events. */
class PerformanceDamageNumbers {
    public static var enabled:Bool = false;
    static var budget = new VisualDamageBudget();
    static var failed = false;
    static var warned = false;
    public static function reset():Void { budget.reset(); failed = false; warned = false; }
    public static function suppress():Bool {
        if (!enabled || failed) return false;
        try {
            var skip = !budget.allow(haxe.Timer.stamp(), widget -> G.field(widget, "parent") != null);
            if (skip && !warned) {
                warned = true;
                trace("[More Settings] Performance: floating numbers limited to 16 active and 20 new/second.");
            }
            return skip;
        } catch (e:Dynamic) {
            failed = true; budget.reset();
            trace("[More Settings] Damage number budget disabled: " + Std.string(e));
            return false;
        }
    }
    public static function created(widget:Dynamic):Void {
        if (enabled && !failed) budget.created(widget);
    }
}
