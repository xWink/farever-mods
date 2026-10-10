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
            // Two double-bit battle axes, with broad blades on both sides of
            // each haft. Native vector paths stay sharp at different UI scales.
            axe(-Math.PI / 4);
            axe(Math.PI / 4);
            return;
        }
        G.call("h2d.Graphics", "lineStyle", graphic, [1.5, 0x5b4334, 1.0]);
        G.call("h2d.Graphics", "beginFill", graphic, [0x77bb83, 1.0]);
        path([[8.,2.],[16.,2.],[16.,8.],[22.,8.],[22.,16.],[16.,16.],[16.,22.],[8.,22.],[8.,16.],[2.,16.],[2.,8.],[8.,8.],[8.,2.]]);
        G.call("h2d.Graphics", "endFill", graphic);
    }
    function axe(angle:Float):Void {
        G.call("h2d.Graphics", "lineStyle", graphic, [1.1, 0x5b4334, 1.0]);
        G.call("h2d.Graphics", "beginFill", graphic, [0xb99164, 1.0]);
        rotated([[11.,3.],[13.,3.],[13.,22.],[11.,22.],[11.,3.]], angle);
        G.call("h2d.Graphics", "endFill", graphic);
        G.call("h2d.Graphics", "beginFill", graphic, [0xe8d4b2, 1.0]);
        rotated([[11.,4.],[8.,3.],[7.,2.],[6.,4.],[5.5,6.],[6.,8.],[7.,10.],[8.,9.],[11.,8.],
            [13.,8.],[16.,9.],[17.,10.],[18.,8.],[18.5,6.],[18.,4.],[17.,2.],[16.,3.],[13.,4.],[11.,4.]], angle);
        G.call("h2d.Graphics", "endFill", graphic);
    }
    function rotated(points:Array<Array<Float>>, angle:Float):Void {
        var cosine = Math.cos(angle), sine = Math.sin(angle);
        path([for (p in points) [12 + (p[0] - 12) * cosine - (p[1] - 12) * sine,
            12 + (p[0] - 12) * sine + (p[1] - 12) * cosine]]);
    }
    function path(points:Array<Array<Float>>):Void {
        G.call("h2d.Graphics", "moveTo", graphic, [points[0][0], points[0][1]]);
        for (i in 1...points.length) G.call("h2d.Graphics", "lineTo", graphic, [points[i][0], points[i][1]]);
    }
}
