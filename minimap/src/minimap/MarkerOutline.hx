package minimap;

import minimap.GameAccess as G;

/** A one-pixel dark silhouette, baked into the shared marker texture. */
class MarkerOutline {
    public static function needed(kind:String):Bool return switch kind {
        case "activity", "quest", "dungeon", "soulstone", "riftPortal", "upcomingRift", "inactiveRift", "nextRift",
             "pilgrim", "demon", "glory": true;
        default: false; // Other markers already include an outline in their geometry.
    };

    public static function apply(object:Dynamic, pixels:Float):Void {
        var outline = G.create("h2d.filter.Outline", [null, null, null, null]);
        G.call("h2d.filter.Outline", "set_size", outline, [pixels]);
        G.call("h2d.filter.Outline", "set_quality", outline, [1.]);
        G.call("h2d.filter.Outline", "set_color", outline, [0x201b1b]);
        G.call("h2d.filter.Outline", "set_alpha", outline, [1.]);
        G.call("h2d.filter.Filter", "set_useScreenResolution", outline, [true]);
        G.call("h2d.Object", "set_filter", object, [outline]);
    }
}
