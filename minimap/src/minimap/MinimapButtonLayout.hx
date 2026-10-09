package minimap;

typedef ButtonSpot = {
    var x:Float;
    var y:Float;
    var size:Float;
}

/** Places category buttons beside the card: a column on a square map, an arc on a round one. */
class MinimapButtonLayout {
    public static inline var GAP = 2.0;
    static inline var BORDER = 3.0;

    public static function spots(mapSize:Int, circular:Bool):Array<ButtonSpot> {
        var count = MinimapMenu.shortcuts().length;
        var spots:Array<ButtonSpot> = [];
        if (count <= 0 || mapSize <= 0) return spots;
        if (!circular) return column(mapSize, count);
        return arc(mapSize, count);
    }

    /** Width past the card's right edge, including the gap before the buttons. */
    public static function extra(mapSize:Int, circular:Bool):Float {
        var frame = mapSize + BORDER * 2;
        var right = frame;
        for (spot in spots(mapSize, circular)) right = Math.max(right, spot.x + spot.size);
        return right - frame;
    }

    static function column(mapSize:Int, count:Int):Array<ButtonSpot> {
        var span = mapSize + BORDER * 2;
        var button = (span - GAP * (count - 1)) / count;
        var x = mapSize + BORDER * 2 + GAP;
        var spots:Array<ButtonSpot> = [];
        for (index in 0...count) spots.push({x: x, y: index * (button + GAP), size: button});
        return spots;
    }

    static function arc(mapSize:Int, count:Int):Array<ButtonSpot> {
        var radius = mapSize / 2 + BORDER;
        var button = Math.max(14.0, Math.min(28, mapSize * 0.1));
        var orbit = radius + BORDER + button / 2;
        var spread = spreadFor(radius, orbit, button, count);
        // Shrink until the arc stays inside the card, keeping a gap between buttons.
        while (button > 14) {
            var reach = Math.sin(spread / 2) * orbit + button / 2;
            if (reach <= radius) break;
            button -= 1;
            orbit = radius + BORDER + button / 2;
            spread = spreadFor(radius, orbit, button, count);
        }
        var spots:Array<ButtonSpot> = [];
        for (index in 0...count) {
            var t = count == 1 ? 0.0 : index / (count - 1);
            // Zero points right; negative is up, so the first category stays at the top.
            var angle = -spread / 2 + t * spread;
            var cx = radius + Math.cos(angle) * orbit;
            var cy = radius + Math.sin(angle) * orbit;
            spots.push({x: cx - button / 2, y: cy - button / 2, size: button});
        }
        return spots;
    }

    static function spreadFor(radius:Float, orbit:Float, button:Float, count:Int):Float {
        if (count <= 1) return 0;
        var limit = Math.max(0.0, radius - button / 2 - 2);
        var half = Math.asin(Math.min(0.98, limit / Math.max(1, orbit)));
        var spread = half * 2;
        var minChord = button + 3;
        var chord = 2 * orbit * Math.sin(spread / (count - 1) / 2);
        if (chord < minChord) {
            var step = 2 * Math.asin(Math.min(0.95, minChord / (2 * orbit)));
            spread = step * (count - 1);
        }
        return spread;
    }
}
