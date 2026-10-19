package minimap;

import minimap.GameAccess as G;

/** Native fog shader on each terrain tile, sharing one small visibility buffer. */
class MinimapFog {
    var world:Dynamic;
    var discovery = new MapDiscovery();
    var zoneTexture:Dynamic;
    var ramp:Dynamic;
    var xMin:Int = 0;
    var yMin:Int = 0;
    var chunkSize:Int;
    var chunksPerSide:Int;
    var buffer:Dynamic;
    var values:Dynamic;
    var allocator:Dynamic;
    var signature:String = "";
    var nextRefresh:Float = 0;
    var shaders:haxe.ds.ObjectMap<Dynamic, Dynamic> = new haxe.ds.ObjectMap();

    public function new(world:Dynamic, loader:Dynamic, settings:Dynamic) {
        this.world = world;
        chunkSize = G.integer(G.field(G.field(world, "terrainData"), "chunkSize"));
        chunksPerSide = G.integer(G.field(settings, "MapTileChunksPerSide"));
        var directory = "Level/" + G.text(G.field(world, "level")) + ".dat/minimap/zones";
        for (resource in G.array(G.call("hxd.res.Loader", "dir", loader, [directory]))) {
            var name = G.text(G.field(G.field(resource, "entry"), "name"));
            if (!StringTools.endsWith(name, ".png")) continue;
            var parts = name.substr(0, name.length - 4).split("_");
            if (parts.length != 2) continue;
            var x = Std.parseInt(parts[0]), y = Std.parseInt(parts[1]);
            if (x == null || y == null) continue;
            xMin = x; yMin = y;
            zoneTexture = G.call("hxd.res.Any", "toTexture", resource);
            break;
        }
        if (zoneTexture == null || chunkSize <= 0 || chunksPerSide <= 0) throw "Map fog data unavailable";
        ramp = G.call("hxd.res.Any", "toTexture", G.call("hxd.res.Loader", "load", loader, ["UI/Map/fowRamp.png"]));
        allocator = G.staticCall("hxd.impl.Allocator", "get", []);
    }

    public function update(hero:Dynamic):Void {
        var now = haxe.Timer.stamp();
        if (now < nextRefresh) return;
        nextRefresh = now + 0.2;
        discovery.sample(hero);
        var zones = G.array(G.current("DataCache", "FOW_ZONES"));
        var flags = [for (zone in zones) discovery.fogVisible(zone)];
        var key = [for (flag in flags) flag ? "1" : "0"].join("");
        if (key == signature || zones.length == 0) return;
        if (values == null) values = G.call("hxd.impl.Allocator", "allocFloats", allocator, [zones.length]);
        for (i in 0...flags.length) G.call("hl.types.ArrayBytes_hl_F32", "setDyn", values, [i, flags[i] ? 1. : 0.]);
        if (buffer == null) buffer = G.call("hxd.impl.Allocator", "ofFloats", allocator,
            [values, G.staticCall("hxd.BufferFormat", "get_INDEX32", []), 3]);
        else G.call("h3d.Buffer", "uploadFloats", buffer, [values, 0, flags.length, 0]);
        signature = key;
    }

    public function attach(bitmap:Dynamic, x:Int, y:Int):Void {
        if (buffer == null) throw "Map fog visibility unavailable";
        var shader = G.create("ui.win.FowShader", []);
        G.call("ui.win.FowShader", "set_tileSize", shader, [chunkSize * chunksPerSide]);
        G.call("ui.win.FowShader", "set_texOffsetx", shader, [(x * chunksPerSide - xMin) * chunkSize]);
        G.call("ui.win.FowShader", "set_texOffsety", shader, [(y * chunksPerSide - yMin) * chunkSize]);
        G.call("ui.win.FowShader", "set_zoneTex", shader, [zoneTexture]);
        G.call("ui.win.FowShader", "set_visibleZones", shader, [buffer]);
        G.call("ui.win.FowShader", "set_fowRamp", shader, [ramp]);
        G.call("ui.win.FowShader", "set_blurSize", shader, [G.number(G.field(G.current("Const", "UI"), "FowBlurSize"))]);
        G.call("ui.win.FowShader", "set_playZone", shader, [0]);
        G.call("h2d.Drawable", "addShader", bitmap, [shader]);
        shaders.set(bitmap, shader);
    }

    public function detach(bitmap:Dynamic):Void shaders.remove(bitmap);

    public function dispose():Void {
        // The resource loader owns both textures. Only our buffer is private.
        shaders = new haxe.ds.ObjectMap();
        if (buffer != null) G.call("h3d.Buffer", "dispose", buffer);
        if (values != null) G.call("hxd.impl.Allocator", "disposeFloats", allocator, [values]);
        values = null; buffer = null;
    }
}
