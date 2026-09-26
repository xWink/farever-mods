package minimap;

import minimap.GameAccess as G;

/** Flat, front-facing chest silhouettes; geometry is retained by the icon pool. */
class ChestIcons {
    public static function draw(g:Dynamic, kind:String, r:Float):Void {
        if (kind == "recipeChest") recipe(g, r);
        else treasure(g, r, kind == "vaultChest");
    }

    static function treasure(g:Dynamic, r:Float, vault:Bool):Void {
        var trim = vault ? 0xd5ad55 : 0x8e8375;
        var trimLight = vault ? 0xf2d27a : 0xbcb1a0;
        var wood = vault ? 0xa83d40 : 0x99502f;
        var lower = vault ? 0x792d37 : 0x704328;
        if (vault) {
            // The vault's gold diamond crest rises above its red lid.
            patch(g, r, trim, [0, -1.03, 0.39, -0.67, 0, -0.31, -0.39, -0.67], true);
            patch(g, r, trimLight, [0, -0.87, 0.2, -0.67, 0, -0.47, -0.2, -0.67]);
        }
        patch(g, r, lower, [-0.88, -0.17, 0.88, -0.17, 0.84, 0.78, -0.84, 0.78], true);
        if (!vault) {
            // Broad lower planks retain the abandoned chest's wooden body.
            patch(g, r, 0x9f703d, [-0.7, 0.15, -0.46, 0.15, -0.48, 0.66, -0.72, 0.66]);
            patch(g, r, 0x9f703d, [0.44, 0.15, 0.68, 0.15, 0.72, 0.66, 0.48, 0.66]);
        }
        patch(g, r, wood, [-0.99, -0.68, 0.99, -0.68, 0.94, -0.08,
            0.75, 0.14, -0.75, 0.14, -0.94, -0.08], true);
        patch(g, r, vault ? 0xc2554d : 0xb87245,
            [-0.91, -0.64, 0.91, -0.64, 0.9, -0.53, -0.9, -0.53]);
        if (!vault)
            patch(g, r, 0x673924, [-0.72, -0.32, 0.72, -0.32, 0.72, -0.26, -0.72, -0.26]);
        // Two outer bands and a central strap are shared by the game models.
        for (side in [-1, 1]) {
            patch(g, r, trim, [side * 0.98, -0.72, side * 0.74, -0.72,
                side * 0.66, 0.77, side * 0.89, 0.77], true);
            patch(g, r, trimLight, [side * 0.98, -0.72, side * 0.74, -0.72,
                side * 0.73, -0.58, side * 0.97, -0.58]);
        }
        patch(g, r, trim, [-0.12, -0.71, 0.12, -0.71, 0.15, 0.77, -0.15, 0.77], true);
        patch(g, r, trim, [-0.87, -0.06, 0.87, -0.06, 0.87, 0.13, -0.87, 0.13]);
        if (vault) {
            ellipse(g, r, trimLight, 0, 0.1, 0.3, 0.28, true);
        } else {
            // A brass arched lock contrasts with the dull iron straps.
            patch(g, r, 0xc49b50, [-0.3, 0.2, -0.3, 0.02, -0.2, -0.17,
                0, -0.23, 0.2, -0.17, 0.3, 0.02, 0.3, 0.2], true);
        }
        ellipse(g, r, 0x292326, 0, 0.07, 0.09, 0.09);
        patch(g, r, 0x292326, [-0.035, 0.06, 0.035, 0.06, 0.07, 0.23, -0.07, 0.23]);
        for (side in [-1, 1]) {
            ellipse(g, r, 0x514237, side * 0.84, -0.39, 0.045, 0.045);
            ellipse(g, r, 0x514237, side * 0.78, 0.5, 0.045, 0.045);
        }
    }

    static function recipe(g:Dynamic, r:Float):Void {
        // Cream parchment protrudes from a burgundy drawstring pouch.
        patch(g, r, 0xe8cda1, [-0.4, -0.88, -0.13, -0.97, 0.02, -0.3, -0.24, -0.23], true);
        patch(g, r, 0xffe6b9, [-0.44, -0.91, -0.13, -1, -0.09, -0.88, -0.41, -0.79]);
        patch(g, r, 0xf3dcb5, [0.06, -0.72, 0.27, -0.69, 0.21, -0.18, -0.02, -0.22], true);
        patch(g, r, 0xdfbc90, [0.35, -0.59, 0.51, -0.49, 0.28, -0.11, 0.12, -0.2], true);
        ellipse(g, r, 0x84384a, 0, 0.21, 0.57, 0.48, true);
        patch(g, r, 0x9c4855, [-0.46, -0.26, -0.31, -0.43, 0.31, -0.43,
            0.46, -0.26, 0.23, -0.09, -0.23, -0.09], true);
        patch(g, r, 0xc79a63, [-0.35, -0.24, 0.35, -0.24, 0.26, -0.13, -0.26, -0.13]);
        // Two loose rolled recipes at its foot remain visible at small sizes.
        patch(g, r, 0xf3dcb5, [-0.84, 0.49, 0.35, 0.49, 0.35, 0.72, -0.84, 0.72], true);
        ellipse(g, r, 0xd9b98b, -0.81, 0.605, 0.07, 0.115);
        patch(g, r, 0x9e4050, [-0.11, 0.49, 0.04, 0.49, 0.04, 0.72, -0.11, 0.72]);
        patch(g, r, 0xffe6bf, [-0.13, 0.84, 0.58, 0.42, 0.71, 0.62, 0, 1.02], true);
        patch(g, r, 0xb35661, [0.19, 0.65, 0.32, 0.58, 0.44, 0.77, 0.31, 0.85]);
    }

    static function ellipse(g:Dynamic, r:Float, color:Int, x:Float, y:Float, rx:Float, ry:Float, outline:Bool = false):Void {
        var points:Array<Float> = [];
        for (i in 0...24) {
            var angle = i * Math.PI * 2 / 24;
            points.push(x + Math.cos(angle) * rx);
            points.push(y + Math.sin(angle) * ry);
        }
        patch(g, r, color, points, outline);
    }

    static function patch(g:Dynamic, r:Float, color:Int, points:Array<Float>, outline:Bool = false):Void {
        G.call("h2d.Graphics", "lineStyle", g, [outline ? 1.0 : 0.0, 0x292326, outline ? 1.0 : 0.0]);
        G.call("h2d.Graphics", "beginFill", g, [color, 1.0]);
        var count = Std.int(points.length / 2);
        for (i in 0...count + 1) {
            var j = (i % count) * 2;
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", g, [points[j] * r, points[j + 1] * r]);
        }
        G.call("h2d.Graphics", "endFill", g);
        G.call("h2d.Graphics", "lineStyle", g, [0.0, 0, 0.0]);
    }
}
