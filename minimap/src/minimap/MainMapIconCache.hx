package minimap;

import minimap.GameAccess as G;

/** One small supersampled bake per appearance, shared by markers and buttons. */
class MainMapIconCache {
    // Draw at 8x, then average down to 2x using two smooth half-size passes.
    // Bilinear sampling alone cannot antialias an 8x texture at normal marker
    // sizes. These cached passes restore soft edges without automatic mipmaps
    // or a filter that redraws the whole map every frame.
    static inline var SIZE = 32;
    static inline var SAMPLES = 8;
    var tiles:Map<String, Dynamic> = [];
    var textures:Array<Dynamic> = [];
    var flags:Dynamic;
    var format:Dynamic;
    var blend:Dynamic;

    public function new(nativeArray:Dynamic) {
        flags = G.call("hl.types.ArrayObj", "slice", nativeArray, [0, 0]);
        var target = G.current("h3d.mat.TextureFlags", "Target");
        format = G.current("hxd.PixelFormat", "RGBA");
        blend = G.current("h2d.BlendMode", "AlphaAdd");
        if (flags == null || target == null || format == null || blend == null)
            throw "Map icon texture API unavailable";
        // Mipmap APIs exist on renderers that cannot generate them. Allocate a
        // single-level target and use the bitmap's smooth filtering instead.
        G.call("hl.types.ArrayObj", "pushDyn", flags, [target]);
    }

    public function tile(key:String, draw:Dynamic->Void):Dynamic {
        var cached = tiles[key];
        if (cached != null) return cached;
        var holder:Dynamic = null, texture:Dynamic = null;
        var allocated:Array<Dynamic> = [];
        var geometryReleased = false;
        try {
            holder = G.create("h2d.Object", [null]);
            var graphics = G.create("h2d.Graphics", [holder]);
            draw(graphics);
            G.call("h2d.Object", "setScale", graphics, [SAMPLES * 1.]);
            G.call("h2d.Object", "setPosition", graphics, [SIZE * SAMPLES / 2., SIZE * SAMPLES / 2.]);
            texture = G.create("h3d.mat.Texture", [SIZE * SAMPLES, SIZE * SAMPLES, flags, format]);
            allocated.push(texture);
            // clear takes RGB and a separate alpha, which defaults to 1. Passing
            // only zero as the color leaves an opaque black square behind icons.
            G.call("h3d.mat.Texture", "clear", texture, [0, 0.0, null]);
            G.call("h2d.Object", "drawTo", holder, [texture]);
            geometryReleased = true;
            for (pixels in [SIZE * 4, SIZE * 2]) {
                var source = G.staticCall("h2d.Tile", "fromTexture", [texture]);
                G.call("h2d.Tile", "scaleToSize", source, [pixels * 1., pixels * 1.]);
                holder = G.create("h2d.Bitmap", [source, null]);
                geometryReleased = false;
                style(holder);
                texture = G.create("h3d.mat.Texture", [pixels, pixels, flags, format]);
                allocated.push(texture);
                G.call("h3d.mat.Texture", "clear", texture, [0, 0.0, null]);
                G.call("h2d.Object", "drawTo", holder, [texture]);
                geometryReleased = true;
            }
            cached = G.staticCall("h2d.Tile", "fromTexture", [texture]);
            G.call("h2d.Tile", "scaleToSize", cached, [SIZE * 1., SIZE * 1.]);
            G.call("h2d.Tile", "setCenterRatio", cached, [0.5, 0.5]);
            G.call("h3d.mat.Texture", "preventAutoDispose", texture);
        } catch (error:Dynamic) {
            // drawTo normally calls onRemove itself; a failed draw can leave
            // temporary geometry allocated even though this root has no parent.
            if (holder != null && !geometryReleased) try G.call("h2d.Object", "onRemove", holder) catch (_:Dynamic) {}
            for (target in allocated) try G.call("h3d.mat.Texture", "dispose", target) catch (_:Dynamic) {}
            throw error;
        }
        for (target in allocated) if (target != texture) G.call("h3d.mat.Texture", "dispose", target);
        tiles[key] = cached;
        textures.push(texture);
        return cached;
    }

    public function bitmap(parent:Dynamic, key:String, draw:Dynamic->Void):Dynamic {
        var object = G.create("h2d.Bitmap", [tile(key, draw), parent]);
        style(object);
        return object;
    }

    public function apply(object:Dynamic, key:String, draw:Dynamic->Void):Void {
        G.call("h2d.Bitmap", "set_tile", object, [tile(key, draw)]);
        style(object);
    }

    function style(object:Dynamic):Void {
        G.set(object, "smooth", true);
        // Render targets contain premultiplied color. AlphaAdd is the native
        // One/OneMinusSrcAlpha mode; ordinary Alpha would darken the soft edges.
        G.set(object, "blendMode", blend);
    }

    public function dispose():Void {
        for (texture in textures) try G.call("h3d.mat.Texture", "dispose", texture) catch (_:Dynamic) {}
        tiles = []; textures = [];
    }
}
