package minimap;

import minimap.GameAccess as G;

/** A half-pixel dark silhouette, baked into the shared marker texture. */
class MarkerOutline {
    public static inline var THICKNESS = 0.5;
    public static function needed(kind:String):Bool return switch kind {
        case "activity", "quest", "dungeon", "soulstone", "riftPortal", "upcomingRift", "inactiveRift", "nextRift",
             "pilgrim", "demon", "glory", "bank": true;
        default: false; // Other markers already include an outline in their geometry.
    };

    public static function compose(parent:Dynamic, tile:Dynamic, pixels:Float, blend:Dynamic):Void {
        // Bake a small dilation of the source alpha. Native Outline filters
        // turn the offscreen capture's bounds into an opaque rectangle here.
        // Tinting bitmap RGB to black preserves every transparent source pixel.
        for (i in 0...8) {
            var angle = i * Math.PI / 4;
            var shadow = bitmap(parent, tile, blend);
            G.call("h3d.Vector4Impl", "setColor", G.field(shadow, "color"), [0xff000000]);
            G.call("h2d.Object", "setPosition", shadow, [Math.cos(angle) * pixels, Math.sin(angle) * pixels]);
        }
        // Original artwork covers the inside of the silhouette, at its original
        // position and size. Only the thin outer edge remains visible.
        bitmap(parent, tile, blend);
    }

    static function bitmap(parent:Dynamic, tile:Dynamic, blend:Dynamic):Dynamic {
        var object = G.create("h2d.Bitmap", [tile, parent]);
        G.set(object, "smooth", true);
        G.set(object, "blendMode", blend);
        return object;
    }
}
