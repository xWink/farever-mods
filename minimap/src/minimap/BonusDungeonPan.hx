package minimap;

import minimap.GameAccess as G;

/** Slow only navigation started by the bonus card; native input keeps its speed. */
class BonusDungeonPan {
    var window:Dynamic;
    var targetX:Float = 0;
    var targetY:Float = 0;
    var targetZoom:Float = 0;
    var startX:Float = 0;
    var startY:Float = 0;
    var armed:Bool = false;

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
        if (distanceSquared < 0.0001) { reset(); return; }
        var movedX = G.number(G.field(panning, "x")) - startX;
        var movedY = G.number(G.field(panning, "y")) - startY;
        var fraction = Math.max(0, Math.min(1, (movedX * dx + movedY * dy) / distanceSquared));
        // Native interpolation is 1 - pow(0.7, dt * wantedFPS). Taking the
        // square root of its remaining fraction runs that easing at half time,
        // consistently across frame rates, before native scroll/layout work.
        var slower = 1 - Math.sqrt(1 - fraction);
        G.set(panning, "x", startX + dx * slower);
        G.set(panning, "y", startY + dy * slower);
    }

    public function reset():Void { window = null; armed = false; }
}
