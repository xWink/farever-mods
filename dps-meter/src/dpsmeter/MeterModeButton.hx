package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** The same compact sword/healing-cross toggle in both meter and history. */
class MeterModeButton {
    public var object(default, null):Dynamic;
    public var healing(default, null):Bool;
    var graphic:Dynamic;
    var changed:Bool->Void;
    public function new(parent:Dynamic, id:String, changed:Bool->Void, healing:Bool = false) {
        this.changed = changed; this.healing = healing;
        object = button(parent, "", id, () -> { this.healing = !this.healing; draw(); changed(this.healing); });
        padding(object, 0); size(object, 34, 30);
        graphic = G.create("h2d.Graphics", [object]); absolute(object, graphic); position(graphic, 5, 3);
        draw();
    }
    public function resize(height:Int):Void {
        size(object, 34, height); position(graphic, 5, (height - 24) / 2);
    }
    function draw():Void {
        G.call("h2d.Graphics", "clear", graphic);
        G.call("h2d.Graphics", "lineStyle", graphic, [1.5, 0x5b4334, 1.0]);
        G.call("h2d.Graphics", "beginFill", graphic, [healing ? 0x77bb83 : 0xe8d4b2, 1.0]);
        var points:Array<Array<Float>> = healing
            ? [[8.,2.],[16.,2.],[16.,8.],[22.,8.],[22.,16.],[16.,16.],[16.,22.],[8.,22.],[8.,16.],[2.,16.],[2.,8.],[8.,8.],[8.,2.]]
            : [[5.,22.],[2.,19.],[7.,14.],[4.,11.],[6.,9.],[9.,12.],[18.,3.],[23.,1.],[21.,7.],[12.,16.],[15.,19.],[13.,21.],[10.,18.],[5.,22.]];
        G.call("h2d.Graphics", "moveTo", graphic, [points[0][0], points[0][1]]);
        for (i in 1...points.length) G.call("h2d.Graphics", "lineTo", graphic, [points[i][0], points[i][1]]);
        G.call("h2d.Graphics", "endFill", graphic);
    }
}
