package minimap;

import minimap.GameAccess as G;

/** Borrow native atlas artwork; resize clones without modifying the game's tiles. */
class NativeMarkerIcons {
    static var tiles:Map<String, Dynamic> = [];

    public static function draw(g:Dynamic, sheet:String, id:String, size:Float, x:Float = 0, y:Float = 0):Bool {
        var key = sheet + ":" + id + ":" + size;
        var tile = tiles[key];
        if (tile == null) {
            var data = G.field(G.current("Data", sheet), "byId");
            if (data == null) return false;
            var inf = G.call("haxe.ds.StringMap", "get", data, [id]);
            var gfx = G.field(inf, "gfx");
            if (gfx == null) return false;
            var source = G.staticCall("ui.BaseUI", "getTile", [gfx, null, null]);
            if (source == null) return false;
            var w = G.number(G.field(source, "width")), h = G.number(G.field(source, "height"));
            if (w <= 0 || h <= 0) return false;
            tile = G.call("h2d.Tile", "clone", source);
            G.call("h2d.Tile", "scaleToSize", tile, [w * size / Math.max(w, h), h * size / Math.max(w, h)]);
            tiles[key] = tile;
        }
        G.call("h2d.Graphics", "drawTile", g, [x - G.number(G.field(tile, "width")) / 2,
            y - G.number(G.field(tile, "height")) / 2, tile]);
        return true;
    }
}
