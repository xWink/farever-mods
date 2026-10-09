package moresettings;

/** Bounded, sequential intervals between the game's existing renderer markers.
    Nested scenes pause the parent's interval, so stages do not double count. */
class RenderStages {
    public static inline var CAPACITY = 48;
    static inline var MAX_DEPTH = 8;
    public var names = new Array<String>();
    public var totals = new Array<Float>();
    public var maximum = new Array<Float>();
    public var calls = new Array<Int>();
    public var used(default, null) = 0;
    public var dropped(default, null) = 0;
    public var depth(default, null) = 0;
    var current = [for (_ in 0...MAX_DEPTH) -1];
    var started = [for (_ in 0...MAX_DEPTH) 0.0];

    public function new() {
        for (_ in 0...CAPACITY) { names.push(null); totals.push(0); maximum.push(0); calls.push(0); }
    }
    public function reset():Void {
        for (i in 0...used) { names[i] = null; totals[i] = maximum[i] = 0; calls[i] = 0; }
        used = dropped = depth = 0;
    }
    function slot(name:String):Int {
        for (i in 0...used) if (names[i] == name) return i;
        if (used == CAPACITY) { dropped++; return -1; }
        names[used] = name;
        return used++;
    }
    function finish(now:Float):Void {
        if (depth <= 0 || depth > MAX_DEPTH) return;
        var i = current[depth - 1];
        if (i < 0) return;
        var elapsed = Math.max(0, now - started[depth - 1]);
        totals[i] += elapsed;
        if (elapsed > maximum[i]) maximum[i] = elapsed;
        calls[i]++;
    }
    public function beginScene(now:Float):Void {
        finish(now);
        depth++;
        if (depth > MAX_DEPTH) { dropped++; return; }
        current[depth - 1] = slot("scene-setup");
        started[depth - 1] = now;
    }
    public function mark(name:String, now:Float):Void {
        if (depth <= 0 || depth > MAX_DEPTH || name == null) return;
        finish(now);
        current[depth - 1] = slot(name);
        started[depth - 1] = now;
    }
    public function endScene(now:Float):Void {
        if (depth <= 0) return;
        finish(now);
        depth--;
        if (depth > 0 && depth <= MAX_DEPTH) started[depth - 1] = now;
    }
    public function copyFrom(other:RenderStages):Void {
        reset(); used = other.used; dropped = other.dropped; depth = other.depth;
        for (i in 0...used) {
            names[i] = other.names[i]; totals[i] = other.totals[i];
            maximum[i] = other.maximum[i]; calls[i] = other.calls[i];
        }
    }
    /** Formatting/sorting only after quiet gameplay; keep each log line bounded. */
    public function describe():String {
        var indices = [for (i in 0...used) if (calls[i] > 0) i];
        indices.sort((a, b) -> totals[a] > totals[b] ? -1 : totals[a] < totals[b] ? 1 : a - b);
        var parts = [];
        for (n in 0...Std.int(Math.min(4, indices.length))) {
            var i = indices[n];
            var name = StringTools.replace(StringTools.replace(names[i].substr(0, 64), "\n", " "), "\r", " ");
            parts.push(name + "=" + Math.round(totals[i] * 1000) + "ms(max="
                + Math.round(maximum[i] * 1000) + ",n=" + calls[i] + ")");
        }
        return 'render-stages={observed=${indices.length} dropped=$dropped top=[' + parts.join(" ") + "]}";
    }
}
