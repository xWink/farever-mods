package moresettings;

/** Repeat native binding presses while held, without bypassing skill legality. */
class HoldRepeat {
    var next:Float = -1;
    public function new() {}
    public function reset():Void next = -1;
    public function sample(enabled:Bool, held:Bool, allowed:Bool, now:Float, original:Bool):Bool {
        if (!enabled || !held || !allowed || !Math.isFinite(now)) {
            reset(); return original;
        }
        if (original || next < 0 || now < next - 0.1) {
            next = now + 0.1;
            return original;
        }
        if (now < next) return original;
        next = now + 0.1;
        return true;
    }
    public static function blockFullscreen(enabled:Bool, action:String, ctrl:Bool, f:Bool):Bool
        return enabled && action == "Fullscreen" && ctrl && f;
}
