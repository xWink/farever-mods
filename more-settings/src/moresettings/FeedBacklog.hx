package moresettings;

import moresettings.GameAccess as G;

/** Bound stale numeric HUD rows while preserving combat/state notifications. */
class FeedBacklog {
    public static inline var MAX_LINES:Int = 32;

    public static function trim(feed:Dynamic):Void {
        var active = G.field(feed, "activeLines");
        var count = G.integer(G.field(active, "length"));
        if (count < MAX_LINES) return;
        var lines = G.array(active);
        var removed = false;
        for (line in lines) {
            if (count < MAX_LINES) break;
            var element = G.field(line, "elt");
            var dom = G.field(element, "dom");
            // Native displayDamage/displayHeal apply these classes. Arbitrary
            // text, combat transitions and game-beat notifications are retained.
            if (dom == null || (G.call("domkit.Properties", "hasClass", dom, ["damage"]) != true
                && G.call("domkit.Properties", "hasClass", dom, ["heal"]) != true)) continue;
            G.call("h2d.Object", "remove", element);
            G.call("hl.types.ArrayObj", "remove", active, [line]);
            count--;
            removed = true;
        }
        if (!removed) return;
        // Deleting old rows alone does not repair negative scheduled times:
        // native addLine() would keep extending the same delayed tail forever.
        var survivors = G.array(active);
        var next = 0.0;
        for (line in survivors) {
            var elapsed = G.number(G.field(line, "elapsed"));
            if (elapsed >= 0) next = Math.min(next, elapsed - 0.15);
        }
        for (line in survivors) {
            if (G.number(G.field(line, "elapsed")) >= 0) continue;
            G.set(line, "elapsed", next);
            next -= 0.15;
        }
    }
}
