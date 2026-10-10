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
            // Broad, curved double-bit heads stay separated above the crossed
            // handles. Use the button's side padding to keep the blades legible.
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
        rotated([[11.,0.5],[13.,0.5],[13.,27.5],[11.,27.5],[11.,0.5]], angle);
        G.call("h2d.Graphics", "endFill", graphic);
        G.call("h2d.Graphics", "beginFill", graphic, [0xe8d4b2, 1.0]);
        rotated([[11.,4.],[9.8,3.9],[8.7,3.5],[7.7,2.8],[6.8,1.8],[6.,0.5],
            [5.45,1.75],[5.05,3.],[4.85,4.25],[4.8,5.5],[4.85,6.75],[5.05,8.],[5.45,9.25],[6.,10.5],
            [6.8,9.2],[7.7,8.2],[8.7,7.5],[9.8,7.1],[11.,7.],[13.,7.],
            [14.2,7.1],[15.3,7.5],[16.3,8.2],[17.2,9.2],[18.,10.5],
            [18.55,9.25],[18.95,8.],[19.15,6.75],[19.2,5.5],[19.15,4.25],[18.95,3.],[18.55,1.75],[18.,0.5],
            [17.2,1.8],[16.3,2.8],[15.3,3.5],[14.2,3.9],[13.,4.],[11.,4.]], angle);
        G.call("h2d.Graphics", "endFill", graphic);
    }
    function rotated(points:Array<Array<Float>>, angle:Float):Void {
        var cosine = Math.cos(angle), sine = Math.sin(angle);
        // Lower the crossing to leave a gap between the broad heads, then fit
        // the whole silhouette inside the existing button with room for its outline.
        path([for (p in points) [12 + 0.86 * ((p[0] - 12) * cosine - (p[1] - 18) * sine),
            16.2 + 0.86 * ((p[0] - 12) * sine + (p[1] - 18) * cosine)]]);
    }
    function path(points:Array<Array<Float>>):Void {
        G.call("h2d.Graphics", "moveTo", graphic, [points[0][0], points[0][1]]);
        for (i in 1...points.length) G.call("h2d.Graphics", "lineTo", graphic, [points[i][0], points[i][1]]);
    }
}
