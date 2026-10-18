package minimap;

typedef MapEdgePoint = {x:Float, y:Float};

/** Screen-space clipping and compass geometry, shared by both minimap shapes. */
class MinimapGeometry {
    public static inline var FRAME_BORDER = 3;
    public static function markerInView(x:Float, y:Float, size:Float, circular:Bool, radius:Float):Bool {
        var half = size / 2;
        // Sparkling pawprints have circular outlines. Count a partly clipped
        // ring as visible too, rather than showing a duplicate edge arrow.
        if (circular) return x * x + y * y <= (half + radius) * (half + radius);
        var dx = Math.max(0, Math.abs(x) - half), dy = Math.max(0, Math.abs(y) - half);
        return dx * dx + dy * dy <= radius * radius;
    }

    public static function showAlert(hasMarker:Bool, x:Float, y:Float, size:Float, circular:Bool, radius:Float):Bool
        return x * x + y * y > 0.000001 && (!hasMarker || !markerInView(x, y, size, circular, radius));

    public static function edge(x:Float, y:Float, size:Float, circular:Bool, inset:Float):MapEdgePoint {
        var extent = circular ? Math.sqrt(x * x + y * y) : Math.max(Math.abs(x), Math.abs(y));
        var factor = extent <= 0.000001 ? 0 : Math.max(0, size / 2 - inset) / extent;
        return {x: size / 2 + x * factor, y: size / 2 + y * factor};
    }

    public static function north(size:Float, circular:Bool, rotation:Float, markerScale:Float):MapEdgePoint
        // The complete enlarged glyph fits inside a 12 px radius. Leave two
        // more pixels for the mask edge, including on rotated square maps.
        return edge(Math.sin(rotation), -Math.cos(rotation), size, circular, 14 * markerScale);

    public static function alert(x:Float, y:Float, size:Float, circular:Bool, markerScale:Float, north:Null<MapEdgePoint>):MapEdgePoint {
        var point = edge(x, y, size, circular, 14 * markerScale);
        if (north == null) return point;
        var dx = point.x - north.x, dy = point.y - north.y;
        // Reserve space for the compass only when this arrow would cover it.
        return dx * dx + dy * dy < 24 * 24 * markerScale * markerScale
            ? edge(x, y, size, circular, 38 * markerScale) : point;
    }
}
