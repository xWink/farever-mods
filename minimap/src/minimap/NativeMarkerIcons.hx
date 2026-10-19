package minimap;

import minimap.GameAccess as G;

/** Draw complete native atlas regions without modifying the game's tiles. */
class NativeMarkerIcons {
    static var tiles:Map<String, Dynamic> = [];

    public static function draw(g:Dynamic, sheet:String, id:String, size:Float, x:Float = 0, y:Float = 0):Bool {
        var key = sheet + ":" + id;
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
            tile = source;
            tiles[key] = tile;
        }
        var w = G.number(G.field(tile, "width")), h = G.number(G.field(tile, "height"));
        var scale = size / Math.max(w, h);
        var left = x - w * scale / 2, top = y - h * scale / 2;
        // Graphics.drawTile ignores Tile.scaleToSize when mapping texture pixels.
        // Scale the fill explicitly, compensating for the atlas region's origin.
        G.call("h2d.Graphics", "beginTileFill", g, [
            left + G.number(G.field(tile, "x")) * (1 - scale),
            top + G.number(G.field(tile, "y")) * (1 - scale), scale, scale, tile]);
        G.call("h2d.Graphics", "drawRect", g, [left, top, w * scale, h * scale]);
        G.call("h2d.Graphics", "endFill", g);
        return true;
    }
}
