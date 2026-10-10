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
            // each haft. Keep the heads above the handle crossing with a clear
            // gap between their outlines, even at the native 24px icon size.
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
        rotated([[11.,3.],[13.,3.],[13.,25.],[11.,25.],[11.,3.]], angle);
        G.call("h2d.Graphics", "endFill", graphic);
        G.call("h2d.Graphics", "beginFill", graphic, [0xe8d4b2, 1.0]);
        rotated([[11.,4.],[9.,3.5],[8.5,2.5],[8.,4.],[7.5,6.],[8.,7.5],[8.5,9.],[9.,8.],[11.,7.],
            [13.,7.],[15.,8.],[15.5,9.],[16.,7.5],[16.5,6.],[16.,4.],[15.5,2.5],[15.,3.5],[13.,4.],[11.,4.]], angle);
        G.call("h2d.Graphics", "endFill", graphic);
    }
    function rotated(points:Array<Array<Float>>, angle:Float):Void {
        var cosine = Math.cos(angle), sine = Math.sin(angle);
        path([for (p in points) [12 + (p[0] - 12) * cosine - (p[1] - 14.5) * sine,
            14.5 + (p[0] - 12) * sine + (p[1] - 14.5) * cosine]]);
    }
    function path(points:Array<Array<Float>>):Void {
        G.call("h2d.Graphics", "moveTo", graphic, [points[0][0], points[0][1]]);
        for (i in 1...points.length) G.call("h2d.Graphics", "lineTo", graphic, [points[i][0], points[i][1]]);
    }
}
