package minimap;

import minimap.GameAccess as G;

/** One retained N/compass glyph; map rotation changes only its transform. */
class MinimapCompass {
    var graphic:Dynamic;
    var lastSize:Int = 0;
    var lastHeight:Int = 0;
    var lastCircular:Bool = false;
    var lastRotation:Float = Math.NaN;
    var lastScale:Float = 0;
    var lastVisible:Bool = true;

    public function new(parent:Dynamic) {
        graphic = G.create("h2d.Graphics", [parent]);
        repaint();
    }

    /** Scene removal erases Graphics. Draw the glyph again without moving it. */
    public function repaint():Void {
        if (graphic == null) return;
        G.call("h2d.Graphics", "clear", graphic);
        // Filled convex shapes give the enlarged N square, complete ends.
        // Avoid line joins/caps: their thin strokes lost detail at HUD size.
        // Draw every outline first so the stems and diagonal join seamlessly.
        for (outline in [true, false]) {
            G.call("h2d.Graphics", "beginFill", graphic, [outline ? 0x201b1b : 0xfff3d6, 1.0]);
            polygon(outline ? [0., -11., 5., -3., -5., -3.] : [0., -8.5, 2.5, -4.5, -2.5, -4.5]);
            polygon(outline ? [-6., -2., -1.5, -2., -1.5, 10., -6., 10.]
                : [-5., -1., -2.5, -1., -2.5, 9., -5., 9.]);
            polygon(outline ? [1.5, -2., 6., -2., 6., 10., 1.5, 10.]
                : [2.5, -1., 5., -1., 5., 9., 2.5, 9.]);
            polygon(outline ? [-6., -2., -1.5, -2., 6., 10., 1.5, 10.]
                : [-5., -1., -2.5, -1., 5., 9., 2.5, 9.]);
            G.call("h2d.Graphics", "endFill", graphic);
        }
    }

    public function update(size:Int, circular:Bool, rotation:Float, markerScale:Float, visible:Bool = true, height:Int = -1):Void {
        var viewHeight = height > 0 ? height : size;
        if (visible != lastVisible) {
            G.call("h2d.Object", "set_visible", graphic, [visible]);
            lastVisible = visible;
        }
        if (!visible) return;
        if (size == lastSize && viewHeight == lastHeight && circular == lastCircular && rotation == lastRotation && markerScale == lastScale) return;
        var point = MinimapGeometry.north(size, circular, rotation, markerScale, viewHeight);
        G.call("h2d.Object", "setPosition", graphic, [point.x, point.y]);
        G.call("h2d.Object", "set_rotation", graphic, [rotation]);
        if (markerScale != lastScale) G.call("h2d.Object", "setScale", graphic, [markerScale]);
        lastSize = size; lastHeight = viewHeight; lastCircular = circular; lastRotation = rotation; lastScale = markerScale;
    }

    function polygon(points:Array<Float>):Void {
        for (i in 0...Std.int(points.length / 2) + 1) {
            var j = (i * 2) % points.length;
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", graphic, [points[j], points[j + 1]]);
        }
    }
}
