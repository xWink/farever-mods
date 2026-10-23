package moresettings;

/** Tracks attached floating widgets, not damage or healing events. */
class VisualDamageBudget {
    var active:Array<Dynamic> = [];
    var rate = new VisualRateLimit(0.05);
    public var maximum(default, null):Int = 20;
    public function new() {}
    public function configure(value:Int):Void {
        var limit=Std.int(Math.max(0,Math.min(200,value)));
        if (limit == maximum) return;
        maximum = limit;
        rate = new VisualRateLimit(1.0/Math.max(1,limit));
        reset();
    }
    public function reset():Void { active = []; rate.reset(); }
    public function allow(now:Float, attached:Dynamic->Bool):Bool {
        active = active.filter(attached);
        return maximum > 0 && active.length < maximum && rate.allow(now);
    }
    public function created(widget:Dynamic):Void {
        if (widget != null && active.indexOf(widget) < 0) active.push(widget);
    }
}
