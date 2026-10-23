package moresettings;

/** Cosmetic-only rate limiter: no catch-up burst after skipped frames. */
class VisualRateLimit {
    var next:Float = -1;
    var last:Float = -1;
    final interval:Float;
    public function new(interval:Float = 0.25) this.interval = interval;
    public function reset():Void { next = -1; last = -1; }
    public function allow(now:Float):Bool {
        if (!Math.isFinite(now)) return true;
        if (now < last) next = -1;
        last = now;
        if (now < next) return false;
        next = now + interval;
        return true;
    }
}
