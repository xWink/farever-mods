package itemutilities;

import itemutilities.InspectAccess as G;

/** Small, flat utility symbols drawn inside their owning native window. */
class NativeUtilityIcons {
    static inline var MARK = 0xF0E3D4;

    public static function smooth(object:Dynamic):Void {
        // Use the same bounded supersampling as BMS help icons. One filter
        // covers the button and symbol together; no full-window render target.
        var filter = G.create("h2d.filter.Nothing", []);
        G.set(filter, "smooth", true);
        G.set(filter, "boundsExtend", 1.0);
        G.call("h2d.filter.Filter", "set_useScreenResolution", filter, [true]);
        G.call("h2d.filter.Filter", "set_resolutionScale", filter, [4.0]);
        G.call("h2d.Object", "set_filter", object, [filter]);
    }

    public static function background(g:Dynamic, w:Float, h:Float):Void {
        G.call("h2d.Graphics", "clear", g);
        // A one-pixel coverage ramp avoids hard stair-steps on the corners
        // even at fractional UI scales; the drawable's tint supplies its color.
        var previous = 0.0;
        for (step in 1...9) {
            var coverage = step / 8.0;
            var inset = -0.5 + (step - 0.5) / 8.0;
            G.call("h2d.Graphics", "beginFill", g, [0xFFFFFF, (coverage - previous) / (1 - previous)]);
            G.call("h2d.Graphics", "drawRoundedRect", g, [inset,inset,w-2*inset,h-2*inset,6-inset,16]);
            G.call("h2d.Graphics", "endFill", g);
            previous = coverage;
        }
    }

    public static function draw(g:Dynamic, kind:String):Void {
        switch kind {
            case "junk-badge":
                trash(g, 2, 2, 0.55, 0xB8C2D1);
            case "junk", "sell-junk":
                trash(g, 6, 4, 1, MARK);
            case "badge":
                line(g, 0xB8C2D1, 2, [5,8, 5,5, 7,2, 10,2, 12,5, 12,8]);
                rect(g, 0xB8C2D1, 3,7,11,9,2);
                keyhole(g, 8.5, 11);
            case "lock":
                // A filled U-shaped shackle joins both sides of the body.
                // Avoid a stroked arc's duplicate endpoint, which can break
                // the native line join and make the lock appear open.
                var shackle:Array<Float> = [11,14];
                arc(shackle,16,10,5,Math.PI,Math.PI*2);
                shackle.push(21); shackle.push(14);
                shackle.push(19.2); shackle.push(14);
                arc(shackle,16,10,3.2,0,-Math.PI);
                shackle.push(12.8); shackle.push(14);
                fill(g, MARK, shackle);
                rect(g, MARK, 8.5,13,15,11,0);
                // A broad crossbar remains visibly T-shaped at button size.
                rect(g, 0x333842, 13.5,16.4,5,2,0.3);
                rect(g, 0x333842, 15.25,17.4,1.5,4,0);
            case "materials":
                // Flat hammer: two clean shapes, without bevels or highlights.
                rect(g, 0xC79C65, 9,9,3.5,11.5,1);
                fill(g, 0xBFD3DE, [4,5, 13,5, 17,7, 17,9,
                    12.5,10.5, 4,10.5]);
            case "food":
                // Simple apple silhouette and leaf.
                circle(g, 0xE56D51, 7.8,12.1,4.4);
                circle(g, 0xE56D51, 12.2,12.1,4.4);
                fill(g, 0xE56D51, [4,13, 16,13, 14.8,17.5,
                    12.5,20, 10,19.3, 7.5,20, 5.2,17.5]);
                fill(g, 0x9FC77B, [10.3,7.5, 12,4.5, 16,4,
                    14.5,7, 12,8]);
            case "consumable":
                // A single-color flask, with a small negative-space neck.
                fill(g, 0x91CBE8, [8,5, 13,5, 13,10, 17,17,
                    17,19, 15.5,20, 5.5,20, 4,19, 4,17, 8,10]);
                rect(g, 0x665E59, 9.4,7,2.2,3,0.3);
                rect(g, 0x91CBE8, 7,4,7,2,0.7);
            case "demon":
                // One flat, horned enchantment silhouette.
                fill(g, 0xC391E1, [10.5,7, 14,10, 16,8, 17.5,4.5,
                    18,9, 15.5,12.5, 10.5,21, 5.5,12.5, 3,9,
                    3.5,4.5, 5,8, 7,10]);
            case "equipment":
                // Tunic silhouette for armour, weapons and wearable gear.
                fill(g, 0xBFD3DE, [7,5, 9,7, 12,7, 14,5, 19,9, 16,13,
                    14,11, 14,21, 7,21, 7,11, 5,13, 2,9]);
            case "collectible":
                // A golden star for learned and collected unlocks.
                fill(g, 0xE8BA72, [10.5,3, 13,9, 19.5,9, 14.5,13.5,
                    16.5,20, 10.5,16, 4.5,20, 6.5,13.5, 1.5,9, 8,9]);
            case "misc":
                // Minimal circle / square / triangle for miscellaneous items.
                circle(g, 0xD8BE92, 6.5,7.5,3);
                rect(g, 0xD8BE92, 11.5,4.5,6,6,0.8);
                fill(g, 0xD8BE92, [4,20, 9.5,12, 15,20]);
            case "all":
                var star:Array<Float> = [];
                for (i in 0...16) {
                    var angle = -Math.PI / 2 + i * Math.PI / 8;
                    var radius = i % 2 == 0 ? 8.0 : 2.4;
                    star.push(10.5 + Math.cos(angle) * radius);
                    star.push(12 + Math.sin(angle) * radius);
                }
                fill(g, 0xE8BA72, star);
        }
        if (kind == "sell-junk") {
            // Small outward arrow distinguishes the merchant action from marking.
            line(g, MARK, 2, [21,20, 28,20, 25,17, 28,20, 25,23]);
        } else if (["badge", "lock", "junk", "junk-badge"].indexOf(kind) < 0) {
            rect(g, MARK, 23,7,2,9.5,0.8);
            fill(g, MARK, [19.7,14, 28.3,14, 24,19]);
            line(g, MARK, 1.8, [19,19.5, 19,22, 19.5,22.5,
                28.5,22.5, 29,22, 29,19.5]);
        }
        G.call("h2d.Graphics", "flush", g);
    }

    static function trash(g:Dynamic, x:Float, y:Float, scale:Float, color:Int):Void {
        rect(g, color, x+3*scale, y+6*scale, 14*scale, 15*scale, 1*scale);
        rect(g, color, x+1*scale, y+3*scale, 18*scale, 2.5*scale, 0.7*scale);
        rect(g, color, x+6*scale, y, 8*scale, 2.5*scale, 0.7*scale);
        for (i in 0...3) rect(g, 0x333842, x+(6+i*3.5)*scale, y+9*scale, 1.5*scale, 9*scale, 0.5*scale);
    }

    static function keyhole(g:Dynamic, x:Float, y:Float):Void {
        circle(g, 0x333842, x, y, 1.25);
        line(g, 0x333842, 1.5, [x,y, x,y+3]);
    }

    static function arc(points:Array<Float>, cx:Float, cy:Float, r:Float, from:Float, to:Float):Void {
        for (i in 0...13) {
            var angle = from + (to - from) * i / 12;
            points.push(cx + Math.cos(angle) * r);
            points.push(cy + Math.sin(angle) * r);
        }
    }
    static function line(g:Dynamic, color:Int, width:Float, points:Array<Float>):Void {
        G.call("h2d.Graphics", "lineStyle", g, [width,color,1.]);
        path(g, points);
        G.call("h2d.Graphics", "lineStyle", g, [0.,0,0.]);
    }
    static function fill(g:Dynamic, color:Int, points:Array<Float>):Void {
        G.call("h2d.Graphics", "beginFill", g, [color,1.]);
        path(g, points);
        G.call("h2d.Graphics", "endFill", g);
    }
    static function path(g:Dynamic, points:Array<Float>):Void {
        for (i in 0...Std.int(points.length / 2))
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", g, [points[i * 2],points[i * 2 + 1]]);
    }
    static function rect(g:Dynamic, color:Int, x:Float, y:Float, w:Float, h:Float, radius:Float):Void {
        G.call("h2d.Graphics", "beginFill", g, [color,1.]);
        G.call("h2d.Graphics", "drawRoundedRect", g, [x,y,w,h,radius,16]);
        G.call("h2d.Graphics", "endFill", g);
    }
    static function circle(g:Dynamic, color:Int, x:Float, y:Float, r:Float):Void {
        G.call("h2d.Graphics", "beginFill", g, [color,1.]);
        G.call("h2d.Graphics", "drawCircle", g, [x,y,r,48]);
        G.call("h2d.Graphics", "endFill", g);
    }
}
