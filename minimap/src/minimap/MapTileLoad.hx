package minimap;

import minimap.GameAccess as G;

/** Native asynchronous texture request; GPU uploads remain on the game thread. */
class MapTileLoad {
    static inline var LOADING = 512;
    var image:Dynamic;

    public function new(resource:Dynamic) {
        image = G.call("hxd.res.Any", "toImage", resource);
        var previous = G.field(image, "enableAsyncLoading");
        // The native image loader checks format/backend support and falls back
        // itself when asynchronous decoding is unavailable. Never force it.
        G.set(image, "enableAsyncLoading", true);
        try G.call("hxd.res.Image", "toTexture", image) catch (e:Dynamic) {
            G.set(image, "enableAsyncLoading", previous);
            throw e;
        }
        G.set(image, "enableAsyncLoading", previous);
    }

    public function take():Dynamic {
        if (image == null) return null;
        var texture = G.field(image, "tex");
        if (texture == null || (G.integer(G.field(texture, "flags")) & LOADING) != 0) return null;
        // Construct the tile only after the full-size texture has arrived.
        // Native async placeholders can have different dimensions.
        var tile = G.call("h2d.Tile", "clone", G.call("hxd.res.Image", "toTile", image));
        G.set(tile, "dx", 0.0); G.set(tile, "dy", 0.0);
        image = null;
        return tile;
    }
}
