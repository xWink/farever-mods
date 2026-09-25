package moresettings;

import moresettings.GameAccess as G;

private class TerrainEntry {
    public var terrain:Dynamic;
    public var values:Array<Dynamic> = [];
    public var textures:Array<Dynamic> = [];
    public var textureCount:Int = 0;
    public var frame:Int = 0;
    public var used:Int = 0;
    public var same:Bool = false;
    public var ready:Bool = false;
    public var valid:Bool = false;
    public var pending:Bool = false;
    public var revision:Int = 0;
    public function new(terrain:Dynamic) this.terrain = terrain;
    public function add(value:Dynamic):Void {
        if (used >= values.length || values[used] != value) same = false;
        values[used++] = value;
    }
}

/** Reuse the native terrain composition only while all of its inputs match. */
class TerrainGlobalsCache {
    // Bounded even if a future client stops calling Terrain.dispose().
    public static inline var MAX_TERRAINS:Int = 4;
    var entries:Array<TerrainEntry> = [];
    var getChunk:Array<Dynamic>->Dynamic;
    var getObject:Array<Dynamic>->Dynamic;
    var bindGlobals:Array<Dynamic>->Dynamic;
    var touchTexture:Array<Dynamic>->Dynamic;
    var chunkArgs:Array<Dynamic> = [null, 0.0, 0.0, null, null];
    var objectArgs:Array<Dynamic> = [null, 0];
    var rendererArgs:Array<Dynamic> = [null];
    var textureArgs:Array<Dynamic> = [null, 0];
    var busy:Bool = false;

    public function new() {}

    function find(terrain:Dynamic):TerrainEntry {
        for (entry in entries) if (entry.terrain == terrain) return entry;
        return null;
    }

    public function clear():Void {
        entries.resize(0);
        releaseArguments();
    }

    public function forget(terrain:Dynamic):Void {
        var entry = find(terrain);
        if (entry != null) entries.remove(entry);
    }

    // Ground.refresh() uploads into existing textures, so identity alone cannot
    // detect it. Invalidate before that native operation, including on failure.
    public function invalidate(terrain:Dynamic):Void {
        var entry = find(terrain);
        if (entry != null) { entry.valid = false; entry.revision++; }
    }

    function releaseArguments():Void {
        chunkArgs[0] = null;
        objectArgs[0] = null;
        rendererArgs[0] = null;
        textureArgs[0] = null;
    }

    function bind():Void {
        if (getChunk != null) return;
        getChunk = G.bind("world.terrain.TerrainData", "getChunk");
        getObject = G.bind("haxe.ds.IntMap", "get");
        bindGlobals = G.bind("client.Renderer", "setTerrainGlobals");
        touchTexture = G.bind("h3d.mat.Texture", "set_lastFrame");
    }

    /** Called before updateGlobals; true means its existing result was reused. */
    public function reuse(terrain:Dynamic, context:Dynamic):Bool {
        if (busy) { invalidate(terrain); return false; }
        var entry = find(terrain);
        if (entry == null) {
            if (entries.length >= MAX_TERRAINS) entries.shift();
            entry = new TerrainEntry(terrain);
            entries.push(entry);
        }
        entry.pending = false;
        var wasValid = entry.valid;
        entry.valid = false;
        // The first pass always uses the game's implementation. Capture only
        // after it has allocated any lazily created GPU resources.
        if (!wasValid) { entry.pending = true; return false; }
        busy = true;
        var reused = false;
        try {
            bind();
            var revision = entry.revision;
            inspect(entry, context);
            if (entry.ready && entry.same && entry.revision == revision) {
                // Copying sampled these textures every frame in the native
                // path. Retain that lifetime without pinning resources forever.
                // The native setter preserves PREVENT_AUTO_DISPOSE textures.
                textureArgs[1] = entry.frame;
                for (tex in entry.textures) {
                    textureArgs[0] = tex;
                    touchTexture(textureArgs);
                }
                // Every render context still receives native terrain bindings,
                // even if another camera/renderer used the textures previously.
                var renderer = G.field(G.field(context, "scene"), "renderer");
                G.set(renderer, "terrain", terrain);
                rendererArgs[0] = renderer;
                bindGlobals(rendererArgs);
                entry.valid = true;
                reused = true;
            }
        } catch (e:Dynamic) {
            busy = false; releaseArguments(); throw e;
        }
        busy = false;
        releaseArguments();
        entry.pending = !reused;
        return reused;
    }

    /** Called only after a successful native updateGlobals. */
    public function remember(terrain:Dynamic, context:Dynamic):Void {
        var entry = find(terrain);
        if (entry == null || !entry.pending || busy) return;
        entry.pending = false;
        entry.valid = false;
        busy = true;
        try {
            bind();
            var revision = entry.revision;
            inspect(entry, context);
            entry.valid = entry.ready && entry.revision == revision;
        } catch (e:Dynamic) {
            busy = false; releaseArguments(); throw e;
        }
        busy = false;
        releaseArguments();
    }

    function texture(entry:TerrainEntry, value:Dynamic):Void {
        entry.add(value);
        if (value == null) return; // Native composition skips missing sources.
        entry.textures[entry.textureCount++] = value;
        var handle = G.field(value, "t");
        if (handle == null) entry.ready = false;
        entry.add(handle);
        entry.add(G.field(value, "width"));
        entry.add(G.field(value, "height"));
        entry.add(G.field(value, "format"));
    }

    function target(entry:TerrainEntry, value:Dynamic):Void {
        entry.add(value);
        entry.add(G.field(value, "defaultColor"));
        entry.add(G.field(value, "f"));
        var tex = G.field(value, "tex");
        if (tex == null) entry.ready = false;
        texture(entry, tex);
    }

    function inspect(entry:TerrainEntry, context:Dynamic):Void {
        entry.used = 0;
        entry.textureCount = 0;
        entry.same = true;
        entry.ready = false;
        var terrain = entry.terrain;
        var data = G.field(terrain, "data");
        var objects = G.field(terrain, "chunkObjects");
        var position = G.field(G.field(context, "camera"), "pos");
        var renderer = G.field(G.field(context, "scene"), "renderer");
        var engine = G.field(context, "engine");
        var driver = G.field(engine, "driver");
        var frame = G.field(driver, "frameCount");
        var width:Float = G.field(data, "chunkWidth");
        var x:Float = G.field(position, "x");
        var y:Float = G.field(position, "y");
        if (data == null || objects == null || position == null || width <= 0
            || !Math.isFinite(width) || !Math.isFinite(x) || !Math.isFinite(y)
            || !Std.isOfType(frame, Int) || G.field(context, "wasContextLost") != false
            || !G.isA(renderer, "client.Renderer")) return;
        entry.ready = true;
        entry.frame = frame;
        entry.add(data);
        entry.add(objects);
        entry.add(engine);
        entry.add(driver);
        entry.add(width);
        entry.add(G.field(data, "chunkSize"));
        entry.add(Math.floor(x / width));
        entry.add(Math.floor(y / width));
        entry.add(G.field(terrain, "defaultBuffer"));
        entry.add(G.field(terrain, "bufferArray"));
        entry.add(G.field(terrain, "posArray"));
        entry.add(G.field(terrain, "globalPos"));
        var globals = G.field(terrain, "globalTextures");
        entry.add(globals);
        target(entry, G.field(globals, "normal"));
        target(entry, G.field(globals, "softHeight"));

        chunkArgs[0] = data;
        objectArgs[0] = objects;
        // Use the exact native lookup, including ensureUpdatedOnce(), instead
        // of inferring that unchanged camera coordinates mean unchanged data.
        for (ix in 0...3) for (iy in 0...3) {
            chunkArgs[1] = x + (ix - 1) * width;
            chunkArgs[2] = y + (iy - 1) * width;
            var chunk = getChunk(chunkArgs);
            entry.add(chunk);
            if (chunk == null) continue;
            var cell = G.field(chunk, "position");
            var cx:Int = G.field(cell, "x");
            var cy:Int = G.field(cell, "y");
            objectArgs[1] = (cx + 16384) | ((cy + 16384) << 16);
            var object = getObject(objectArgs);
            entry.add(object);
            var buffer = G.field(object, "cellsBuffer");
            entry.add(buffer);
            if (buffer == null) continue;
            entry.add(G.field(buffer, "vbuf"));
            var objectChunk = G.field(object, "chunk");
            entry.add(G.field(objectChunk, "absX"));
            entry.add(G.field(objectChunk, "absY"));
            var ground = G.field(object, "ground");
            var shader = G.field(ground, "shader");
            if (shader == null || G.field(ground, "needRefresh") == true
                || G.field(object, "needRefresh") == true) entry.ready = false;
            entry.add(ground);
            entry.add(shader);
            texture(entry, G.field(shader, "normalTex__"));
            texture(entry, G.field(shader, "heightTex__"));
        }
        if (entry.used != entry.values.length) entry.same = false;
        entry.values.resize(entry.used);
        entry.textures.resize(entry.textureCount);
    }
}
