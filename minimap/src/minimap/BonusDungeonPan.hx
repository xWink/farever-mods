package minimap;

import minimap.GameAccess as G;

/** Slow only navigation started by the bonus card; native input keeps its speed. */
class BonusDungeonPan {
    static inline var SETTLE_DISTANCE = 0.01;
    static final TAIL_START = Math.log(4.);
    var window:Dynamic;
    var targetX:Float = 0;
    var targetY:Float = 0;
    var targetZoom:Float = 0;
    var startX:Float = 0;
    var startY:Float = 0;
    var armed:Bool = false;
    var initialDistance:Float = 0;
    var progress:Float = 0;

    public function new() {}

    public function scrollTo(nextWindow:Dynamic, x:Float, y:Float):Void {
        reset();
        // The optional native Bool is a reference. Null keeps smooth scrolling
        // and preserves the current zoom without passing a boxed Bool.
        G.call("ui.win.MapWindow", "scrollTo", nextWindow, [x, y, null, null]);
        var target = G.field(nextWindow, "targetPanning");
        if (target == null) return;
        window = nextWindow;
        targetX = G.number(G.field(target, "x"));
        targetY = G.number(G.field(target, "y"));
        targetZoom = G.number(G.field(window, "targetZoom"));
        beginUpdate(window);
        var dx = targetX - startX, dy = targetY - startY;
        initialDistance = Math.sqrt(dx * dx + dy * dy);
    }

    public function beginUpdate(instance:Dynamic):Void {
        if (instance != window || window == null) return;
        var panning = G.field(window, "panning");
        armed = panning != null;
        startX = G.number(G.field(panning, "x"));
        startY = G.number(G.field(panning, "y"));
    }

    public function beforeScroll(instance:Dynamic):Void {
        if (instance != window || !armed) return;
        armed = false;
        var target = G.field(window, "targetPanning");
        // Dragging, keyboard panning, zooming, or another scrollTo takes over.
        if (targetX != G.number(G.field(target, "x")) || targetY != G.number(G.field(target, "y"))
            || targetZoom != G.number(G.field(window, "targetZoom"))) { reset(); return; }
        var panning = G.field(window, "panning");
        var dx = targetX - startX, dy = targetY - startY;
        var distanceSquared = dx * dx + dy * dy;
        if (distanceSquared < SETTLE_DISTANCE * SETTLE_DISTANCE) { reset(); return; }
        var movedX = G.number(G.field(panning, "x")) - startX;
        var movedY = G.number(G.field(panning, "y")) - startY;
        var fraction = Math.max(0, Math.min(1, (movedX * dx + movedY * dy) / distanceSquared));
        if (fraction == 1) { reset(); return; }
        // Preserve the current 1/8-native speed for the first 75% of travel.
        // Measure elapsed easing from the native step so frame rate and native
        // wantedFPS continue to determine the same real-time movement.
        var previous = settlingProgress(progress);
        progress -= Math.log(1 - fraction) * 0.125;
        var slower = 1 - Math.exp(previous - settlingProgress(progress));
        if (Math.sqrt(distanceSquared) * (1 - slower) <= SETTLE_DISTANCE) {
            G.set(panning, "x", targetX);
            G.set(panning, "y", targetY);
            reset();
            return;
        }
        G.set(panning, "x", startX + dx * slower);
        G.set(panning, "y", startY + dy * slower);
    }

    function settlingProgress(value:Float):Float {
        var tail = Math.max(0, value - TAIL_START);
        var span = Math.log(initialDistance * 0.25 / SETTLE_DISTANCE);
        if (tail == 0 || span <= 1.5) return value;
        // The final approach takes 2/3 of its former time (50% faster). A
        // quadratic clock starts with the same slope, avoiding a speed jump:
        // at tail=2*span/3, tail + 3*tail^2/(4*span) equals span.
        return value + 0.75 * tail * tail / span;
    }

    public function reset():Void { window = null; armed = false; initialDistance = 0; progress = 0; }
}
