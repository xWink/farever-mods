package minimap;

import minimap.MinimapGeometry.MapEdgePoint;

typedef PinClick = {x:Float, y:Float, time:Float};

/** Minimap click inversion and the off-screen arrow, shared with tests. */
class PinPlacement {
    public static inline var DOUBLE_CLICK = 0.35;
    public static inline var SLOP = 12.0;

    public static function world(mouseX:Float, mouseY:Float, size:Float, heroX:Float, heroY:Float,
        scale:Float, rotation:Float, height:Float = -1):{x:Float, y:Float} {
        var dx = mouseX - size / 2;
        var dy = mouseY - (height > 0 ? height : size) / 2;
        var c = Math.cos(rotation);
        var s = Math.sin(rotation);
        return {
            x: heroX + (dx * c + dy * s) / scale,
            y: heroY + (dy * c - dx * s) / scale
        };
    }

    /** Rotated UI-pixel offset from the minimap centre, matching marker alerts. */
    public static function screen(pinX:Float, pinY:Float, heroX:Float, heroY:Float,
        scale:Float, rotation:Float):{x:Float, y:Float} {
        var dx = (pinX - heroX) * scale;
        var dy = (pinY - heroY) * scale;
        var c = Math.cos(rotation);
        var s = Math.sin(rotation);
        return {x: dx * c - dy * s, y: dx * s + dy * c};
    }

    public static function offScreen(offsetX:Float, offsetY:Float, size:Float, circular:Bool, radius:Float, height:Float = -1):Bool {
        return MinimapGeometry.showAlert(true, offsetX, offsetY, size, circular, radius, height);
    }

    public static function edge(offsetX:Float, offsetY:Float, size:Float, circular:Bool,
        markerScale:Float, north:Null<MapEdgePoint>, height:Float = -1):MapEdgePoint {
        return MinimapGeometry.alert(offsetX, offsetY, size, circular, markerScale, north, height);
    }

    /** Grab-drag: the map follows the cursor, including while the view is rotated. */
    public static function drag(panX:Float, panY:Float, mouseX:Float, mouseY:Float,
        rotation:Float, scale:Float):{x:Float, y:Float} {
        if (!(scale > 0) || !Math.isFinite(mouseX) || !Math.isFinite(mouseY)) return {x: panX, y: panY};
        var c = Math.cos(rotation);
        var s = Math.sin(rotation);
        var localX = mouseX * c + mouseY * s;
        var localY = -mouseX * s + mouseY * c;
        return {x: panX - localX / scale, y: panY - localY / scale};
    }

    public static function doubleClick(previous:PinClick, x:Float, y:Float, time:Float):Bool {
        if (previous == null) return false;
        var elapsed = time - previous.time;
        if (!(elapsed > 0) || elapsed > DOUBLE_CLICK) return false;
        var dx = x - previous.x;
        var dy = y - previous.y;
        return dx * dx + dy * dy <= SLOP * SLOP;
    }
}
