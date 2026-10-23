package moresettings;

/** Stable quota for client-side models. Simulation is always retained. */
class VisualQuota {
    var slots = new haxe.ds.ObjectMap<Dynamic, Bool>();
    var count:Int = 0;
    final maximum:Int;
    public function new(maximum:Int) this.maximum = maximum;
    public function admit(key:Dynamic):Bool {
        if (slots.exists(key)) return true;
        if (count >= maximum) return false;
        slots.set(key, true); count++; return true;
    }
    public function release(key:Dynamic):Void {
        if (slots.remove(key)) count--;
    }
    public function reset():Void { slots = new haxe.ds.ObjectMap(); count = 0; }
}
