package moresettings;

import moresettings.GameAccess as G;

/** Same closed lock, T-shaped keyhole and smooth corners as Item Utilities. */
class CharacterLockIcons {
    public static function smooth(object:Dynamic):Void {
        var filter = G.create("h2d.filter.Nothing", []);
        G.set(filter, "smooth", true);
        G.set(filter, "boundsExtend", 1.0);
        G.call("h2d.filter.Filter", "set_useScreenResolution", filter, [true]);
        G.call("h2d.filter.Filter", "set_resolutionScale", filter, [4.0]);
        G.call("h2d.Object", "set_filter", object, [filter]);
    }
    public static function background(g:Dynamic):Void {
        var previous = 0.0;
        for (step in 1...9) {
            var coverage = step / 8.0;
            var inset = -0.5 + (step - 0.5) / 8.0;
            G.call("h2d.Graphics", "beginFill", g, [0xFFFFFF, (coverage-previous)/(1-previous)]);
            G.call("h2d.Graphics", "drawRoundedRect", g, [inset,inset,32-2*inset,32-2*inset,6-inset,16]);
            G.call("h2d.Graphics", "endFill", g);
            previous = coverage;
        }
        G.call("h2d.Graphics", "flush", g);
    }
    public static function draw(g:Dynamic):Void {
        var points:Array<Float> = [11,14];
        arc(points, 5, Math.PI, Math.PI*2);
        points.push(21); points.push(14);
        points.push(19.2); points.push(14);
        arc(points, 3.2, 0, -Math.PI);
        points.push(12.8); points.push(14);
        G.call("h2d.Graphics", "beginFill", g, [0xF0E3D4,1.]);
        for (i in 0...Std.int(points.length/2))
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", g, [points[i*2],points[i*2+1]]);
        G.call("h2d.Graphics", "endFill", g);
        rect(g, 0xF0E3D4, 8.5,13,15,11);
        rect(g, 0x333842, 13.5,16.4,5,2);
        rect(g, 0x333842, 15.25,17.4,1.5,4);
        G.call("h2d.Graphics", "flush", g);
    }
    static function arc(points:Array<Float>, radius:Float, from:Float, to:Float):Void {
        for (i in 0...13) {
            var angle = from + (to-from)*i/12;
            points.push(16+Math.cos(angle)*radius); points.push(10+Math.sin(angle)*radius);
        }
    }
    static function rect(g:Dynamic, color:Int, x:Float, y:Float, w:Float, h:Float):Void {
        G.call("h2d.Graphics", "beginFill", g, [color,1.]);
        G.call("h2d.Graphics", "drawRect", g, [x,y,w,h]);
        G.call("h2d.Graphics", "endFill", g);
    }
}
