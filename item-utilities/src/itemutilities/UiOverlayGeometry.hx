package itemutilities;

/** Heaps affine coordinates, without native dependencies for regression tests. */
class UiOverlayGeometry {
    public var a:Float;
    public var b:Float;
    public var c:Float;
    public var d:Float;
    public var x:Float;
    public var y:Float;

    public function new(a:Float = 1, b:Float = 0, c:Float = 0, d:Float = 1,
        x:Float = 0, y:Float = 0) {
        this.a = a;
        this.b = b;
        this.c = c;
        this.d = d;
        this.x = x;
        this.y = y;
    }

    public inline function pointX(px:Float, py:Float):Float return px * a + py * c + x;
    public inline function pointY(px:Float, py:Float):Float return px * b + py * d + y;

    /** Apply this transform first, then the enclosing camera/viewport transform. */
    public function then(outer:UiOverlayGeometry):UiOverlayGeometry {
        return new UiOverlayGeometry(
            a * outer.a + b * outer.c, a * outer.b + b * outer.d,
            c * outer.a + d * outer.c, c * outer.b + d * outer.d,
            outer.pointX(x, y), outer.pointY(x, y));
    }

    /** Map overlay pixels back into the native input object's coordinate space. */
    public function inverse():UiOverlayGeometry {
        var determinant = a * d - b * c;
        if (!Math.isFinite(determinant) || determinant == 0
            || !Math.isFinite(x) || !Math.isFinite(y)) return null;
        return new UiOverlayGeometry(d / determinant, -b / determinant,
            -c / determinant, a / determinant,
            (c * y - d * x) / determinant, (b * x - a * y) / determinant);
    }

    public function rect(left:Float, top:Float, width:Float, height:Float):OverlayRect {
        if (width <= 0 || height <= 0) return null;
        var x0 = pointX(left, top);
        var y0 = pointY(left, top);
        var dx = width * a;
        var dy = width * b;
        var ex = height * c;
        var ey = height * d;
        var bounds = new OverlayRect(
            x0 + Math.min(0, dx) + Math.min(0, ex),
            y0 + Math.min(0, dy) + Math.min(0, ey),
            x0 + Math.max(0, dx) + Math.max(0, ex),
            y0 + Math.max(0, dy) + Math.max(0, ey));
        return bounds.valid() ? bounds : null;
    }
}
