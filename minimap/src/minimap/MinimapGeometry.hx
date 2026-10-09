package minimap;

typedef MapEdgePoint = {x:Float, y:Float};

/** Screen-space clipping and compass geometry, shared by both minimap shapes. */
class MinimapGeometry {
    public static function markerInView(x:Float, y:Float, size:Float, circular:Bool, radius:Float, height:Float = -1):Bool {
        var tall = height > 0 ? height : size;
        var halfW = size / 2;
        var halfH = tall / 2;
        // Sparkling pawprints have circular outlines. Count a partly clipped
        // ring as visible too, rather than showing a duplicate edge arrow.
        if (circular) {
            var half = halfW < halfH ? halfW : halfH;
            return x * x + y * y <= (half + radius) * (half + radius);
        }
        var dx = Math.max(0, Math.abs(x) - halfW), dy = Math.max(0, Math.abs(y) - halfH);
        return dx * dx + dy * dy <= radius * radius;
    }

    public static function showAlert(hasMarker:Bool, x:Float, y:Float, size:Float, circular:Bool, radius:Float, height:Float = -1):Bool
        return x * x + y * y > 0.000001 && (!hasMarker || !markerInView(x, y, size, circular, radius, height));

    public static function edge(x:Float, y:Float, size:Float, circular:Bool, inset:Float, height:Float = -1):MapEdgePoint {
        var tall = height > 0 ? height : size;
        if (circular || tall == size) {
            var extent = circular ? Math.sqrt(x * x + y * y) : Math.max(Math.abs(x), Math.abs(y));
            var factor = extent <= 0.000001 ? 0 : Math.max(0, size / 2 - inset) / extent;
            return {x: size / 2 + x * factor, y: size / 2 + y * factor};
        }
        var halfW = Math.max(0, size / 2 - inset);
        var halfH = Math.max(0, tall / 2 - inset);
        var ax = Math.abs(x), ay = Math.abs(y);
        if (ax <= 0.000001 && ay <= 0.000001) return {x: size / 2, y: tall / 2};
        var sx = ax <= 0.000001 ? 1e12 : halfW / ax;
        var sy = ay <= 0.000001 ? 1e12 : halfH / ay;
        var scale = Math.min(sx, sy);
        return {x: size / 2 + x * scale, y: tall / 2 + y * scale};
    }

    public static function north(size:Float, circular:Bool, rotation:Float, markerScale:Float, height:Float = -1):MapEdgePoint
        // The complete enlarged glyph fits inside a 12 px radius. Leave two
        // more pixels for the mask edge, including on rotated square maps.
        return edge(Math.sin(rotation), -Math.cos(rotation), size, circular, 14 * markerScale, height);

    public static function alert(x:Float, y:Float, size:Float, circular:Bool, markerScale:Float, north:Null<MapEdgePoint>, height:Float = -1):MapEdgePoint {
        var point = edge(x, y, size, circular, 14 * markerScale, height);
        if (north == null) return point;
        var dx = point.x - north.x, dy = point.y - north.y;
        // Reserve space for the compass only when this arrow would cover it.
        return dx * dx + dy * dy < 24 * 24 * markerScale * markerScale
            ? edge(x, y, size, circular, 38 * markerScale, height) : point;
    }
}
