import minimap.MinimapButtonLayout as L;

class MinimapButtonLayoutTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        for (size in [160, 250, 400]) {
            var square = L.spots(size, false);
            var round = L.spots(size, true);
            eq(square.length, 9, "square map keeps one button per category");
            eq(round.length, 9, "round map keeps one button per category");
            var frame = size + 6;
            var radius = size / 2 + 3;
            eq(square[0].x == square[8].x, true, "square buttons stay in a column");
            eq(square[0].y < square[8].y, true, "square buttons run top to bottom");
            eq(round[0].y < round[4].y && round[8].y > round[4].y, true, "curved buttons run top to bottom");
            eq(round[4].x > round[0].x && round[4].x > round[8].x, true, "the middle button sits furthest right");
            eq(round[0].y >= -0.01 && round[8].y + round[8].size <= frame + 0.01, true,
                "curved buttons stay beside the card");
            for (spot in round) {
                var cx = spot.x + spot.size / 2;
                var cy = spot.y + spot.size / 2;
                var distance = Math.sqrt((cx - radius) * (cx - radius) + (cy - radius) * (cy - radius));
                eq(distance > radius + 2, true, "curved buttons sit just outside the circle");
            }
            for (index in 0...8) {
                var a = round[index];
                var b = round[index + 1];
                var dx = (a.x + a.size / 2) - (b.x + b.size / 2);
                var dy = (a.y + a.size / 2) - (b.y + b.size / 2);
                eq(dx * dx + dy * dy > a.size * a.size, true, "curved buttons do not overlap");
            }
            eq(L.extra(size, false) > 0 && L.extra(size, true) > 0, true, "buttons need room past the card");
        }
        trace("MinimapButtonLayoutTest passed (" + checks + " checks)");
    }
}
