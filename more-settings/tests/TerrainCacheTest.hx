import moresettings.TerrainGlobalsCache;
import moresettings.GameAccess as G;

class TerrainCacheTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, message:String):Void {
        checks++;
        if (a != b) throw '$message: expected $b, got $a';
    }
    static function key(x:Int, y:Int):Int return (x + 16384) | ((y + 16384) << 16);
    static function texture():Dynamic return {t: {}, width: 17, height: 17, format: "RGBA", lastFrame: 0};
    static function chunk(x:Int, y:Int):Dynamic return {position: {x: x, y: y}, absX: x * 16.0, absY: y * 16.0};
    static function object(chunk:Dynamic):Dynamic return {
        chunk: chunk, cellsBuffer: {vbuf: {}}, needRefresh: false,
        ground: {needRefresh: false, shader: {normalTex__: texture(), heightTex__: texture()}}
    };
    static function fixture():Dynamic {
        var chunks:Map<Int, Dynamic> = [];
        var objects:Map<Int, Dynamic> = [];
        for (x in -1...3) for (y in -1...2) {
            var c = chunk(x, y); chunks[key(x, y)] = c; objects[key(x, y)] = object(c);
        }
        var terrain:Dynamic = {
            data: {chunkWidth: 16.0, chunkSize: 16, chunks: chunks}, chunkObjects: objects,
            defaultBuffer: {}, bufferArray: {}, posArray: {}, globalPos: {},
            globalTextures: {
                normal: {tex: texture(), defaultColor: 1, f: () -> {}},
                softHeight: {tex: texture(), defaultColor: 2, f: () -> {}}
            }
        };
        var renderer:Dynamic = {types: ["client.Renderer"], terrain: null, boundTerrain: null};
        var context:Dynamic = {camera: {pos: {x: 2.0, y: 3.0}}, scene: {renderer: renderer},
            wasContextLost: false, engine: {driver: {frameCount: 1}}};
        return {terrain: terrain, context: context, objects: objects, chunks: chunks};
    }
    static function prime(cache:TerrainGlobalsCache, f:Dynamic):Void {
        eq(cache.reuse(f.terrain, f.context), false, "first pass builds natively");
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), true, "unchanged completed composition reused");
    }
    static function changed(cache:TerrainGlobalsCache, f:Dynamic, why:String):Void {
        eq(cache.reuse(f.terrain, f.context), false, why);
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), true, "native rebuild makes new inputs reusable: " + why);
    }
    static function main():Void {
        var cache = new TerrainGlobalsCache();
        var f = fixture();
        prime(cache, f);
        // A stable scene avoids 120 complete compositions, while preserving
        // native chunk lookups and renderer binding on every render pass.
        G.terrainLookups = 0; G.terrainBindings = 0;
        for (_ in 0...120) {
            eq(cache.reuse(f.terrain, f.context), true, "stable frame skips composition");
            cache.remember(f.terrain, f.context); // Postfix also runs on Skip.
        }
        eq(G.terrainLookups, 120 * 9, "native chunk update checks retained exactly once per reused frame");
        eq(G.terrainBindings, 120, "terrain globals bound on every reused frame");
        eq(f.context.scene.renderer.boundTerrain, f.terrain, "renderer receives this terrain");
        f.context.camera.pos.x = 15.0;
        eq(cache.reuse(f.terrain, f.context), true, "movement inside neighborhood reuses composition");
        f.context.camera.pos.x = 16.0;
        changed(cache, f, "crossing a chunk boundary rebuilds");
        f.context.camera.pos.x = -0.1;
        changed(cache, f, "negative world coordinates rebuild correctly");

        // A second camera overwrites the shared native targets. Returning to
        // the first camera must rebuild, rather than resurrect an old key.
        f.context.camera.pos.x = 2.0;
        changed(cache, f, "returning camera rebuilds the shared targets");
        f.context.scene.renderer = {types: ["client.Renderer"], terrain: null, boundTerrain: null};
        eq(cache.reuse(f.terrain, f.context), true, "same neighborhood can bind to a different renderer");
        eq(f.context.scene.renderer.boundTerrain, f.terrain, "second renderer receives native bindings");

        var center = f.objects.get(key(0, 0));
        center.ground.shader.normalTex__ = texture(); changed(cache, f, "normal source replacement");
        center.ground.shader.heightTex__.t = {}; changed(cache, f, "source GPU resource recreation");
        center.ground.shader.heightTex__.width = 33; changed(cache, f, "source dimension change");
        center.cellsBuffer.vbuf = {}; changed(cache, f, "buffer GPU resource recreation");
        center.cellsBuffer = {vbuf: {}}; changed(cache, f, "chunk buffer replacement");
        center.chunk.absX = 0.5; changed(cache, f, "chunk binding position change");
        f.terrain.globalTextures.normal.tex.t = {}; changed(cache, f, "destination GPU resource recreation");
        f.terrain.globalTextures.softHeight.tex = texture(); changed(cache, f, "destination texture replacement");
        f.terrain.globalTextures.normal.defaultColor = 3; changed(cache, f, "native clear color change");
        f.terrain.globalTextures.normal.f = () -> { return 1; }; changed(cache, f, "native source selector change");
        f.terrain.bufferArray = {}; changed(cache, f, "native buffer binding array replacement");
        f.terrain.posArray = {}; changed(cache, f, "native position binding array replacement");
        f.context.engine = {driver: {frameCount: 2}}; changed(cache, f, "render engine replacement");
        f.context.engine.driver = {frameCount: 3}; changed(cache, f, "driver replacement");

        f.context.engine.driver.frameCount = 1234;
        center.ground.shader.heightTex__.lastFrame = -1;
        eq(cache.reuse(f.terrain, f.context), true, "advancing frame does not invalidate content");
        eq(center.ground.shader.normalTex__.lastFrame, 1234, "source texture stays recently used");
        eq(f.terrain.globalTextures.normal.tex.lastFrame, 1234, "destination texture stays recently used");
        eq(center.ground.shader.heightTex__.lastFrame, -1, "native no-auto-dispose sentinel preserved");

        // Uploading new pixels can preserve BOTH the texture and GPU handle.
        cache.invalidate(f.terrain); changed(cache, f, "in-place ground refresh invalidates composition");
        center.ground.needRefresh = true;
        eq(cache.reuse(f.terrain, f.context), false, "pending ground refresh uses native path");
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), false, "pending refresh cannot become a valid cache entry");
        center.ground.needRefresh = false;
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), true, "refreshed native result is reusable");

        f.objects.remove(key(0, 0)); changed(cache, f, "chunk unload");
        f.objects.set(key(0, 0), center); changed(cache, f, "chunk arrival");
        f.chunks.remove(key(0, 0)); changed(cache, f, "terrain data removal even if old object remains");
        f.chunks.set(key(0, 0), center.chunk); changed(cache, f, "terrain data arrival");
        center.ground.shader.normalTex__ = null; changed(cache, f, "missing source follows native skip behavior");
        center.ground.shader.normalTex__ = texture(); changed(cache, f, "missing source becomes available");
        center.ground.shader.normalTex__.t = null;
        eq(cache.reuse(f.terrain, f.context), false, "disposed source is never reused");
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), false, "disposed source stays on native path");
        center.ground.shader.normalTex__.t = {};
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), true, "reallocated source is reusable after native rebuild");

        f.context.wasContextLost = true;
        eq(cache.reuse(f.terrain, f.context), false, "lost graphics context rebuilds");
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), false, "context-loss frames never reused");
        f.context.wasContextLost = false;
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), true, "recovered context can reuse rebuilt textures");

        var fired = false;
        G.beforeTerrainLookup = () -> {
            if (!fired) { fired = true; cache.invalidate(f.terrain); }
        };
        eq(cache.reuse(f.terrain, f.context), false, "refresh during native lookup cannot race cache validation");
        G.beforeTerrainLookup = null;
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), true, "native rebuild after lookup invalidation");

        G.failTerrainBinding = true;
        var caught = false;
        try cache.reuse(f.terrain, f.context) catch (_:Dynamic) caught = true;
        eq(caught, true, "binding failure reaches hook for native fallback");
        G.failTerrainBinding = false;
        changed(cache, f, "failed reuse cannot remain marked valid");
        cache.clear(); prime(cache, f); // Settings off/on.
        cache.forget(f.terrain); prime(cache, f); // World disposal.
        for (_ in 0...TerrainGlobalsCache.MAX_TERRAINS) prime(cache, fixture());
        eq(cache.reuse(f.terrain, f.context), false, "old worlds evicted to bound retained references");

        cache = new TerrainGlobalsCache(); f = fixture();
        f.context.camera.pos.x = Math.NaN;
        eq(cache.reuse(f.terrain, f.context), false, "invalid camera takes native path");
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), false, "invalid state never cached");
        f.context.camera.pos.x = 2;
        f.context.scene.renderer.types = ["other.Renderer"];
        cache.remember(f.terrain, f.context);
        eq(cache.reuse(f.terrain, f.context), false, "unknown renderer takes native path");
        Sys.println('Terrain composition cache: $checks checks passed.');
    }
}
