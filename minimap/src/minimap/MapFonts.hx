package minimap;

import minimap.GameAccess as G;

/** Reuse loaded native UI fonts instead of enlarging the fallback bitmap font. */
class MapFonts {
    public static function find(object:Dynamic, depth:Int):Dynamic {
        if (object == null || depth < 0) return null;
        var font = G.field(object, "font");
        if (font != null) return font;
        var count = G.integer(G.call("h2d.Object", "get_numChildren", object));
        for (i in 0...count) {
            font = find(G.call("h2d.Object", "getChildAt", object, [i]), depth - 1);
            if (font != null) return font;
        }
        return null;
    }
}
