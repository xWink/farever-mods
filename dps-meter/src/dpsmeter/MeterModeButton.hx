package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** The same compact crossed-axes/healing-cross toggle in meter and history. */
class MeterModeButton {
    public var object(default, null):Dynamic;
    public var healing(default, null):Bool;
    var graphic:Dynamic;
    var changed:Bool->Void;
    public function new(parent:Dynamic, id:String, changed:Bool->Void, healing:Bool = false) {
        this.changed = changed; this.healing = healing;
        object = button(parent, "", id, () -> changed(!this.healing));
        padding(object, 0); size(object, 34, 30);
        graphic = G.create("h2d.Graphics", [object]); absolute(object, graphic); position(graphic, 5, 3);
        // Supersample just the small icon, like the existing utility/help icons.
        // Extra curve segments alone cannot remove pixel stair-steps.
        var antialias = G.create("h2d.filter.Nothing", []);
        G.set(antialias, "smooth", true); G.set(antialias, "boundsExtend", 1.0);
        G.call("h2d.filter.Filter", "set_useScreenResolution", antialias, [true]);
        G.call("h2d.filter.Filter", "set_resolutionScale", antialias, [4.0]);
        G.call("h2d.Object", "set_filter", graphic, [antialias]);
        draw();
    }
    public function resize(height:Int):Void {
        size(object, 34, height); position(graphic, 5, (height - 24) / 2);
    }
    public function setHealing(value:Bool):Void {
        if (healing == value) return;
        healing = value; draw();
    }
    function draw():Void {
        G.call("h2d.Graphics", "clear", graphic);
        if (!healing) {
            // Curved crescent blades follow the supplied crossed-axes reference.
            // Mirror each whole axe; only the handles cross, never the heads.
            axe(false); axe(true);
            G.call("h2d.Graphics", "flush", graphic);
            return;
        }
        G.call("h2d.Graphics", "lineStyle", graphic, [1.5, 0x5b4334, 1.0]);
        G.call("h2d.Graphics", "beginFill", graphic, [0x77bb83, 1.0]);
        path([[8.,2.],[16.,2.],[16.,8.],[22.,8.],[22.,16.],[16.,16.],[16.,22.],[8.,22.],[8.,16.],[2.,16.],[2.,8.],[8.,8.],[8.,2.]]);
        G.call("h2d.Graphics", "endFill", graphic);
    }
    function axe(mirror:Bool):Void {
        G.call("h2d.Graphics", "lineStyle", graphic, [0.9, 0x5b4334, 1.0]);
        G.call("h2d.Graphics", "beginFill", graphic, [0xb99164, 1.0]);
        path([for (p in [[33.,43.],[42.,34.],[256.,248.],[247.,257.],[33.,43.]]) axePoint(p[0], p[1], mirror)]);
        G.call("h2d.Graphics", "endFill", graphic);
        // Upper blade: convex cutting edge and deeply concave inner edge.
        blade([46.,7.], [
            [86.,-17.,144.,37.,126.,85.],
            [111.,66.,94.,61.,79.,72.],
            [72.,64.,64.,57.,58.,50.],
            [73.,31.,63.,19.,46.,7.]
        ], mirror);
        // Lower blade has the complementary broad crescent, not a pointed fan.
        blade([7.,48.], [
            [-13.,94.,34.,144.,83.,125.],
            [62.,112.,59.,94.,64.,78.],
            [61.,72.,56.,67.,51.,61.],
            [31.,72.,15.,68.,7.,48.]
        ], mirror);
    }
    static function axePoint(x:Float, y:Float, mirror:Bool):Array<Float>
        return [12 + (mirror ? 159 - x : x - 159) * .084, 1 + y * .084];
    function blade(start:Array<Float>, curves:Array<Array<Float>>, mirror:Bool):Void {
        G.call("h2d.Graphics", "beginFill", graphic, [0xe8d4b2, 1.0]);
        var first = axePoint(start[0], start[1], mirror);
        var points = [first], previous = first;
        // Evaluate cubic curves with enough segments for the 4x native filter.
        // The points are generated only when the button/mode changes.
        for (c in curves) {
            var a = axePoint(c[0], c[1], mirror), b = axePoint(c[2], c[3], mirror), end = axePoint(c[4], c[5], mirror);
            for (i in 1...17) {
                var t = i / 16.0, u = 1 - t;
                points.push([u*u*u*previous[0] + 3*u*u*t*a[0] + 3*u*t*t*b[0] + t*t*t*end[0],
                    u*u*u*previous[1] + 3*u*u*t*a[1] + 3*u*t*t*b[1] + t*t*t*end[1]]);
            }
            previous = end;
        }
        // Enlarge the curved heads by 15% around their attachment to the haft.
        var center = axePoint(64, 64, mirror);
        path([for (p in points) [center[0] + (p[0] - center[0]) * 1.15,
            center[1] + (p[1] - center[1]) * 1.15]]);
        G.call("h2d.Graphics", "endFill", graphic);
    }
    function path(points:Array<Array<Float>>):Void {
        G.call("h2d.Graphics", "moveTo", graphic, [points[0][0], points[0][1]]);
        for (i in 1...points.length) G.call("h2d.Graphics", "lineTo", graphic, [points[i][0], points[i][1]]);
    }
}
