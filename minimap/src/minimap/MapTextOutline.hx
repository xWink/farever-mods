package minimap;

import minimap.GameAccess as G;

class MapTextOutline {
    public static function apply(object:Dynamic, size:Float):Void {
        var outline = G.create("h2d.filter.Outline", [null, null, null, null]);
        G.call("h2d.filter.Outline", "set_size", outline, [size]);
        G.call("h2d.filter.Outline", "set_quality", outline, [0.5]);
        G.call("h2d.filter.Outline", "set_color", outline, [0x171b24]);
        G.call("h2d.Object", "set_filter", object, [outline]);
    }
}
