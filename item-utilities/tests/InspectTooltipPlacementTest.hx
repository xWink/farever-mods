import itemutilities.InspectTooltipPlacement;
import itemutilities.InspectTooltipPlacement.InspectTipBounds;

class InspectTooltipPlacementTest {
    static var checks = 0;
    static function check(value:Bool, message:String):Void {
        checks++;
        if (!value) throw message;
    }
    static function near(a:Float, b:Float):Bool return Math.abs(a - b) < 0.00001;

    static function main():Void {
        // The main card starts at x=250, but its comparison is 380 units
        // farther left; the Equipped label also extends above the card.
        var comparison:InspectTipBounds = {xMin: -380, yMin: -22, xMax: 375, yMax: 480};
        var screen:InspectTipBounds = {xMin: 8, yMin: 8, xMax: 1504, yMax: 892};
        var left = InspectTooltipPlacement.fit(250, 130, comparison, screen);
        check(near(left.x, 388) && near(left.scale, 1), "move the entire comparison on screen without shrinking it");
        check(near(left.y, 130), "leave the valid vertical position alone");
        var top = InspectTooltipPlacement.fit(600, 0, comparison, screen);
        check(near(top.y, 30), "include the Equipped label in top-edge fitting");
        var inside = InspectTooltipPlacement.fit(600, 100, comparison, screen);
        check(near(inside.x, 600) && near(inside.y, 100), "preserve normal native placement when it fits");

        // Different screen sizes and UI scales: all values are in the tip's
        // parent space, after the runtime converts the viewport corners.
        for (parentScale in [0.75, 1.0, 1.5, 2.0])
            for (resolution in [{w: 640., h: 480.}, {w: 1280., h: 720.}, {w: 1920., h: 1080.}]) {
                var viewport:InspectTipBounds = {xMin: 8 / parentScale - 40, yMin: 8 / parentScale - 20,
                    xMax: (resolution.w - 8) / parentScale - 40, yMax: (resolution.h - 8) / parentScale - 20};
                for (bounds in [comparison, {xMin: 0., yMin: 0., xMax: 375., yMax: 300.},
                        {xMin: -430., yMin: -25., xMax: 430., yMax: 1300.}])
                    for (x in [-600., 250., 1800.]) for (y in [-300., 130., 1000.]) {
                        var fit = InspectTooltipPlacement.fit(x, y, bounds, viewport);
                        check(fit.scale > 0 && fit.scale <= 1, "scale down only when necessary");
                        check(fit.x + bounds.xMin * fit.scale >= viewport.xMin - 0.00001, "left edge stays on screen");
                        check(fit.x + bounds.xMax * fit.scale <= viewport.xMax + 0.00001, "right edge stays on screen");
                        check(fit.y + bounds.yMin * fit.scale >= viewport.yMin - 0.00001, "top edge stays on screen");
                        check(fit.y + bounds.yMax * fit.scale <= viewport.yMax + 0.00001, "bottom edge stays on screen");
                        var again = InspectTooltipPlacement.fit(fit.x, fit.y, bounds, viewport);
                        check(near(again.x, fit.x) && near(again.y, fit.y) && near(again.scale, fit.scale),
                            "repeated sync does not drift or progressively shrink the tooltip");
                    }
            }
        var empty = InspectTooltipPlacement.fit(40, 50, {xMin: 0, yMin: 0, xMax: 0, yMax: 0}, screen);
        check(near(empty.x, 40) && near(empty.y, 50) && near(empty.scale, 1), "ignore tips before they have measurable bounds");
        trace('Inspect tooltip placement: $checks checks passed');
    }
}
