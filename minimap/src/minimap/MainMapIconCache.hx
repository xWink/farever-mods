package minimap;

import minimap.GameAccess as G;

/** One small GPU bake per appearance, shared by every marker and filter button. */
class MainMapIconCache {
    // Eight samples per local icon pixel preserve detail at enlarged marker/UI
    // scales. This is independent of zoom and never allocates a map-sized target.
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
        var geometryReleased = false;
        try {
            holder = G.create("h2d.Object", [null]);
            var graphics = G.create("h2d.Graphics", [holder]);
            draw(graphics);
            G.call("h2d.Object", "setScale", graphics, [SAMPLES * 1.]);
            G.call("h2d.Object", "setPosition", graphics, [SIZE * SAMPLES / 2., SIZE * SAMPLES / 2.]);
            texture = G.create("h3d.mat.Texture", [SIZE * SAMPLES, SIZE * SAMPLES, flags, format]);
            G.call("h3d.mat.Texture", "clear", texture, [0, null, null]);
            G.call("h2d.Object", "drawTo", holder, [texture]);
            geometryReleased = true;
            cached = G.staticCall("h2d.Tile", "fromTexture", [texture]);
            G.call("h2d.Tile", "scaleToSize", cached, [SIZE * 1., SIZE * 1.]);
            G.call("h2d.Tile", "setCenterRatio", cached, [0.5, 0.5]);
            G.call("h3d.mat.Texture", "preventAutoDispose", texture);
        } catch (error:Dynamic) {
            // drawTo normally calls onRemove itself; a failed draw can leave
            // temporary geometry allocated even though this root has no parent.
            if (holder != null && !geometryReleased) try G.call("h2d.Object", "onRemove", holder) catch (_:Dynamic) {}
            if (texture != null) try G.call("h3d.mat.Texture", "dispose", texture) catch (_:Dynamic) {}
            throw error;
        }
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
