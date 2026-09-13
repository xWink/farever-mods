package minimap;

import minimap.GameAccess as G;

/** Local pixel geometry, retained by the marker pool across refreshes. */
class LandmarkIcons {
    public static function draw(graphics:Dynamic, kind:String, radius:Float):Void {
        if (kind == "obelisk") obelisk(graphics, radius);
        else if (kind == "dungeon") dungeon(graphics, radius);
    }

    static function obelisk(g:Dynamic, r:Float):Void {
        fill(g, 0x282828);
        obeliskShape(g, r + 1);
        end(g);
        fill(g, 0x999999);
        obeliskShape(g, r);
        end(g);

        // The idol's gold spine and four round inlays below its split crown.
        fill(g, 0xd8aa50);
        polygon(g, r, [-0.16, -0.35, 0.16, -0.35, 0.16, 0.9, -0.16, 0.9]);
        for (side in [-1, 1]) {
            circle(g, side * 0.74 * r, -0.65 * r, 0.145 * r);
            circle(g, side * 0.42 * r, -0.54 * r, 0.145 * r);
        }
        end(g);
        // Keep the split crown's center entirely gold, like the spine below.
        fill(g, 0xe2b85f);
        polygon(g, r, [-0.065, -0.94, 0.065, -0.94, 0.1, -0.24, -0.1, -0.24]);
        end(g);
        // A broad stone foot gives the thicker column a substantial base.
        fill(g, 0x636363);
        polygon(g, r, [-0.62, 0.78, 0.62, 0.78, 0.62, 1, -0.62, 1]);
        end(g);

        // Broader hands and shoulders remain legible at the default icon size.
        fill(g, 0x555555);
        polygon(g, r, [-0.72, -0.14, 0.72, -0.14, 0.61, 0.21, -0.61, 0.21]);
        end(g);
        fill(g, 0xbfbfbf);
        polygon(g, r, [-0.68, -0.14, 0.68, -0.14, 0.61, 0.02, -0.61, 0.02]);
        end(g);
    }

    static function obeliskShape(g:Dynamic, r:Float):Void {
        polygon(g, r, [-0.58, -0.35, 0.58, -0.35, 0.62, 1, -0.62, 1]);
        // Separate convex pieces preserve the open split when triangulated.
        for (side in [-1, 1])
            polygon(g, r, [-1, -0.83, -0.24, -1, -0.19, -0.8,
                -0.25, -0.22, -0.84, -0.22, -1, -0.43], side);
    }

    static function dungeon(g:Dynamic, r:Float):Void {
        fill(g, 0x201b2e);
        doorway(g, r + 1);
        end(g);
        fill(g, 0xc2bdad);
        doorway(g, r);
        end(g);
        // An inset opening leaves a thick stone arch and two door posts.
        fill(g, 0x38315f);
        polygon(g, r, [-0.51, 0.78, -0.51, -0.31, -0.32, -0.6,
            0, -0.73, 0.32, -0.6, 0.51, -0.31, 0.51, 0.78]);
        end(g);
        fill(g, 0x8559df);
        polygon(g, r, [-0.37, 0.73, -0.42, -0.2, -0.24, -0.48,
            0.04, -0.59, 0.35, -0.25, 0.38, 0.73]);
        end(g);
        // A curved cyan ribbon reads as a portal at the default 16 px size.
        fill(g, 0x55dfff);
        polygon(g, r, [0.08, -0.5, 0.28, -0.25, 0.29, 0.16, 0.08, 0.08]);
        polygon(g, r, [0.29, 0.16, 0.12, 0.44, -0.05, 0.27, 0.08, 0.08]);
        polygon(g, r, [-0.05, 0.27, 0.12, 0.44, -0.14, 0.65, -0.31, 0.49]);
        end(g);
        fill(g, 0xe0fcff);
        circle(g, 0.12 * r, -0.13 * r, 0.09 * r);
        end(g);
        fill(g, 0x777b86);
        polygon(g, r, [-0.8, 0.79, 0.8, 0.79, 0.8, 0.97, -0.8, 0.97]);
        end(g);
    }

    static function doorway(g:Dynamic, r:Float):Void {
        polygon(g, r, [-0.8, 1, -0.8, -0.38, -0.5, -0.82, 0, -1,
            0.5, -0.82, 0.8, -0.38, 0.8, 1]);
    }

    static function fill(g:Dynamic, color:Int):Void
        G.call("h2d.Graphics", "beginFill", g, [color, 1.0]);

    static function end(g:Dynamic):Void
        G.call("h2d.Graphics", "endFill", g);

    static function circle(g:Dynamic, x:Float, y:Float, r:Float):Void
        G.call("h2d.Graphics", "drawCircle", g, [x, y, r, 16]);

    static function polygon(g:Dynamic, r:Float, vertices:Array<Float>, side:Int = 1):Void {
        var count = Std.int(vertices.length / 2);
        for (i in 0...count + 1) {
            // Reverse mirrored vertices to retain the same winding.
            var j = (side < 0 ? (count - i) % count : i % count) * 2;
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", g, [side * vertices[j] * r, vertices[j + 1] * r]);
        }
    }
}
