import itemutilities.PresetSlots;
import itemutilities.OverlayRect;
import itemutilities.UiOverlayGeometry;

class UiOverlayGeometryTest {
    static var checks = 0;

    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }

    static function near(value:Float, expected:Float, message:String):Void {
        check(Math.isFinite(value) && Math.abs(value - expected) < 0.00001,
            message + ': expected $expected, got $value');
    }

    static function rect(value:OverlayRect, x:Float, y:Float, w:Float, h:Float, message:String):Void {
        check(value != null, message + " exists");
        near(value.left, x, message + " x");
        near(value.top, y, message + " y");
        near(value.width, w, message + " width");
        near(value.height, h, message + " height");
    }

    static function main():Void {
        // Repeated shrink/grow/restore with reflowed native anchors. The same
        // fixtures cover both scene scaling and scaling on the UI root itself.
        for (scale in [1.0, 0.75, 1.5, 2.0, 0.625, 1.0]) {
            for (rootScaled in [false, true]) {
                var parentScale = rootScaled ? scale : 1.0;
                var viewportScale = rootScaled ? 1.0 : scale;
                var anchorX = 900 - 50 / scale;
                var anchorY = 100 + 20 / scale;
                var native = new UiOverlayGeometry(parentScale, 0, 0, parentScale,
                    anchorX * parentScale, anchorY * parentScale);
                var viewport = new UiOverlayGeometry(viewportScale, 0, 0, viewportScale, 80, 25);
                var screen = native.then(viewport);
                var originX = anchorX * scale + 80;
                var originY = anchorY * scale + 25;

                for (offset in [-228, -190, -152, -114, -76, -38]) {
                    rect(screen.rect(offset, 0, 32, 30), originX + offset * scale,
                        originY, 32 * scale, 30 * scale, "header buttons");
                }
                rect(screen.rect(182, 0, PresetSlots.CONTROLS_WIDTH, 36), originX + 182 * scale,
                    originY, PresetSlots.CONTROLS_WIDTH * scale, 36 * scale, "preset group");
                rect(screen.rect(40, 7, 16, 17), originX + 40 * scale,
                    originY + 7 * scale, 16 * scale, 17 * scale, "lock badge");
                var slot = screen.rect(0, 0, 48, 48);
                rect(slot, originX, originY, 48 * scale, 48 * scale, "slot hit box");

                // A scrolled slot has only its last 11 units visible. Its input
                // bounds and badge clip must end at the same native viewport.
                var clip = screen.rect(-10, 37, 400, 200);
                rect(slot.clippedTo(clip), originX, originY + 37 * scale,
                    48 * scale, 11 * scale, "partially visible slot");
                check(screen.rect(40, 7, 16, 17).clippedTo(clip) == null,
                    "badge above the visible row is clipped out");
                check(slot.clippedTo(screen.rect(0, 48, 400, 200)) == null,
                    "fully hidden row cannot intercept clicks");
                check(slot.clippedTo(null) == null, "missing viewport disables bag input");

                // Native getBounds is already in scene space. Apply only the
                // camera/viewport to it, avoiding a second object transform.
                var nativeBounds = native.rect(0, 0, 48, 48);
                var projectedBounds = viewport.rect(nativeBounds.left, nativeBounds.top,
                    nativeBounds.width, nativeBounds.height);
                rect(projectedBounds, slot.left, slot.top, slot.width, slot.height,
                    "native bounds use the same pixel space");
                check(projectedBounds.intersects(slot), "covering window hides the overlay");
                check(!projectedBounds.intersects(screen.rect(49, 0, 32, 30)),
                    "adjacent native window does not hide a button");
            }
        }

        // Camera translation/zoom and nonuniform viewport stretch compose in
        // order: local point -> object -> camera -> viewport pixels.
        var object = new UiOverlayGeometry(2, 0, 0, 3, 100, 200);
        var camera = new UiOverlayGeometry(0.5, 0, 0, 0.25, -10, -20);
        var viewport = new UiOverlayGeometry(1.5, 0, 0, 2, 80, 40);
        rect(object.then(camera).then(viewport).rect(10, 20, 32, 30),
            155, 130, 48, 45, "camera and viewport composition");

        var normal = new UiOverlayGeometry();
        check(normal.rect(0, 0, 0, 30) == null, "zero width is not drawable");
        check(normal.rect(0, 0, 32, -1) == null, "negative height is not drawable");
        check(new UiOverlayGeometry(0, 0, 0, 0).rect(0, 0, 32, 30) == null,
            "collapsed viewport has no clickable overlays");
        check(new UiOverlayGeometry(Math.NaN).rect(0, 0, 32, 30) == null,
            "missing native transform is not used as pixels");
        check(new UiOverlayGeometry(1, 0, 0, 1, Math.POSITIVE_INFINITY).rect(0, 0, 32, 30) == null,
            "invalid origin has no clickable overlays");
        trace('UiOverlayGeometry: $checks checks passed');
    }
}
