import minimap.MinimapPosition as P;

class MinimapPositionTest {
    static var checks = 0;
    static function close(actual:Float, expected:Float, message:String):Void {
        checks++;
        if (!Math.isFinite(actual) || Math.abs(actual - expected) > 0.00001)
            throw message + ': expected $expected, got $actual';
    }

    static function main():Void {
        // Includes a scaled HUD, ordinary displays, ultrawide, and live size changes.
        for (viewport in [540, 720, 960, 1080, 1280, 1920, 2560, 3440]) {
            for (size in [160, 250, 400]) {
                var extent = size + 6;
                var far = viewport - extent - 24;
                close(P.axis(viewport, extent, 0), 24, "zero preserves near margin");
                close(P.axis(viewport, extent, 100), far, "100 preserves opposite margin including border");
                close(P.axis(viewport, extent, 0, true), far, "right corner starts at far edge");
                close(P.axis(viewport, extent, 100, true), 24, "right corner moves fully left");
                close(P.axis(viewport, extent, 50), (viewport - extent) / 2, "50 centers the frame");
                for (p in [1, 25, 49, 75, 99]) {
                    var forward = P.axis(viewport, extent, p);
                    var backward = P.axis(viewport, extent, p, true);
                    close(forward + backward, viewport - extent, "corner choices mirror each other");
                    close(forward - P.axis(viewport, extent, p - 1), (far - 24) / 100, "each 1% step is uniform");
                }
            }
        }
        close(P.axis(270, 256, 0), 7, "small viewport reduces margins symmetrically");
        close(P.axis(270, 256, 100, true), 7, "small viewport stays centered");
        close(P.axis(200, 256, 100), 0, "oversized map cannot acquire a negative origin");
        close(P.percent(-10), 0, "negative config clamps");
        close(P.percent(120), 100, "excess config clamps");
        close(P.percent(40.6), 41, "manual fractions normalize to whole percentages");
        close(P.percent(Math.NaN), 0, "invalid config returns to normal position");
        close(P.percent(Math.POSITIVE_INFINITY), 0, "infinite config returns to normal position");
        for (left in [false, true]) for (offset in [0., 25., 50., 100.]) {
            // Use a parsed config, as HLX does, so retiring a field is tested
            // across serialization and a second startup too.
            var config:minimap.MinimapSettings = haxe.Json.parse(haxe.Json.stringify({leftCorner:left, xOffset:offset}));
            var before = P.axis(1920, 256, offset, !left);
            P.migrateCorner(config);
            close(P.axis(1920, 256, config.xOffset, true), before, "Retiring the corner switch preserves screen position");
            close(Reflect.hasField(config, 'leftCorner') ? 1 : 0, 0, "Retired corner key is removed from saved config");
            config = haxe.Json.parse(haxe.Json.stringify(config));
            P.migrateCorner(config);
            close(P.axis(1920, 256, config.xOffset, true), before, "Migration does not mirror the position again after reload");
        }
        Sys.println('Minimap position tests passed ($checks checks)');
    }
}
