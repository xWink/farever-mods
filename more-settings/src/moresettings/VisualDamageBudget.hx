package moresettings;

/** Tracks attached floating widgets, not damage or healing events. */
class VisualDamageBudget {
    var active:Array<Dynamic> = [];
    var rate = new VisualRateLimit(0.1);
    public var maximum(default, null):Int = 8;
    public function new() {}
    public function reset():Void { active = []; rate.reset(); }
    public function allow(now:Float, attached:Dynamic->Bool):Bool {
        active = active.filter(attached);
        return active.length < maximum && rate.allow(now);
    }
    public function created(widget:Dynamic):Void {
        if (widget != null && active.indexOf(widget) < 0) active.push(widget);
    }
}
