package minimap;

import minimap.GameAccess as G;
import minimap.MinimapMod.MinimapSettings;

private typedef MapTile = {
    var x:Int;
    var y:Int;
    var resolution:Int;
    var path:String;
    var tile:Dynamic;
    var lastUsed:Int;
}

/** A passive HUD: native map resources, with no MapWindow or input handlers. */
class MinimapView {
    static inline var LEVEL = "World/W1_Siagarta";
    static inline var DIRECTORY = "Level/" + LEVEL + ".dat/minimap";
    static inline var BORDER = 3;
    static inline var CACHE_LIMIT = 24;

    var world:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var panel:Dynamic;
    var frame:Dynamic;
    var mask:Dynamic;
    var circleMask:Dynamic;
    var squareFilter:Dynamic;
    var circleFilter:Dynamic;
    var circular:Bool = false;
    var pivot:Dynamic;
    var terrain:Dynamic;
    var tileLayer:Dynamic;
    var npcPivot:Dynamic;
    var npcTerrain:Dynamic;
    var markers:MinimapMarkers;
    var arrow:Dynamic;
    var loader:Dynamic;
    var tileWorldWidth:Float = 0;
    var size:Int = 0;
    var scale:Float = 0;
    var bounds:String = "";
    var index:Map<String, MapTile> = [];
    var sprites:Map<String, Dynamic> = [];
    var wanted:Array<MapTile> = [];
    var cached:Array<MapTile> = [];
    var generation:Int = 0;

    public function new() {}

    public function update(app:Dynamic, config:MinimapSettings):Void {
        var nextWorld = G.field(app, "world");
        var ui = G.current("ui.BaseUI", "current");
        if (nextWorld != world || ui != owner) dispose();
        var hero = G.field(app, "hero");
        if (!config.enabled || hero == null || G.field(hero, "removed") == true
            || G.text(G.field(nextWorld, "level")) != LEVEL || ui == null) {
            show(false);
            return;
        }
        if (panel == null) {
            var uiRoot = G.field(ui, "root");
            if (uiRoot == null || G.field(ui, "gameRoot") == null) return;
            var data = G.field(G.field(nextWorld, "terrain"), "data");
            var settings = G.current("Const", "UI");
            var width = G.number(G.field(data, "chunkWidth")) * G.integer(G.field(settings, "MapTileChunksPerSide"));
            if (width <= 0) return;
            world = nextWorld;
            owner = ui;
            root = uiRoot;
            tileWorldWidth = width;
            loader = G.current("hxd.res.Loader", "currentInstance");
            if (loader == null) return;
            indexTiles(settings);
            create();
        }

        if (size != config.size || circular != config.circular) layout(config.size, config.circular);
        var newScale = config.zoom / 100 * 2; // Two UI pixels per world unit at 100%.
        if (newScale != scale) {
            scale = newScale;
            G.call("h2d.Object", "setScale", terrain, [scale]);
            G.call("h2d.Object", "setScale", npcTerrain, [scale]);
            bounds = "";
        }
        var x = G.number(G.field(hero, "posx"));
        var y = G.number(G.field(hero, "posy"));
        var heading = G.number(G.field(hero, "rotationZ"));
        var orientation = config.rotateMap && config.followCamera ? cameraHeading(app, heading) : heading;
        var rotation = config.rotateMap ? -Math.PI / 2 - orientation : 0.0;
        // Native facing is (cos(heading), sin(heading)); screen-up is -PI/2.
        G.call("h2d.Object", "set_rotation", pivot, [rotation]);
        G.call("h2d.Object", "set_rotation", npcPivot, [rotation]);
        position(terrain, -x * scale, -y * scale);
        position(npcTerrain, -x * scale, -y * scale);
        G.call("h2d.Object", "set_rotation", arrow, [heading + rotation]);
        position(panel, config.leftCorner ? 24 : Math.max(0, G.number(G.call("h2d.Flow", "get_innerWidth", root)) - size - BORDER * 2 - 24), 24);
        // A rotating square needs enough tiles/markers to cover its diagonal.
        var radius = size / (2 * scale) * (config.rotateMap && !circular ? Math.sqrt(2) : 1);
        selectTiles(x, y, radius);
        loadNextTile();
        markers.update(hero, config, x, y, radius, scale);
        show(true);
    }

    function cameraHeading(app:Dynamic, fallback:Float):Float {
        // The rendered camera includes smoothing and target-lock movement.
        // Read its horizontal viewing vector without allocating a native ray.
        var camera = G.field(G.field(app, "s3d"), "camera");
        var eye = G.field(camera, "pos"), target = G.field(camera, "target");
        if (eye == null || target == null) return fallback;
        var dx = G.number(G.field(target, "x")) - G.number(G.field(eye, "x"));
        var dy = G.number(G.field(target, "y")) - G.number(G.field(eye, "y"));
        return dx * dx + dy * dy > 0.000001 ? Math.atan2(dy, dx) : fallback;
    }

    function indexTiles(settings:Dynamic):Void {
        if (G.call("hxd.res.Loader", "exists", loader, [DIRECTORY]) != true)
            throw "Overworld map images are unavailable";
        var resolutions = G.array(G.field(settings, "MapTileResolutions"));
        var preferred = resolutions.length == 0 ? 512 : G.integer(resolutions[0], 512);
        // Directory metadata only. Decode images when they reach the viewport.
        for (resource in G.array(G.call("hxd.res.Loader", "dir", loader, [DIRECTORY]))) {
            var name = G.text(G.field(G.field(resource, "entry"), "name"));
            if (!StringTools.endsWith(name, ".png")) continue;
            var parts = name.substr(0, name.length - 4).split("_");
            if (parts.length != 3) continue;
            var x = Std.parseInt(parts[0]);
            var y = Std.parseInt(parts[1]);
            var resolution = Std.parseInt(parts[2]);
            if (x == null || y == null || resolution == null || resolution <= 0) continue;
            var key = tileKey(x, y);
            var previous = index[key];
            if (previous != null && Math.abs(previous.resolution - preferred) <= Math.abs(resolution - preferred)) continue;
            index[key] = {x: x, y: y, resolution: resolution, path: DIRECTORY + "/" + name, tile: null, lastUsed: 0};
        }
        if (!index.iterator().hasNext()) throw "No overworld map tiles were found";
    }

    function create():Void {
        panel = G.create("h2d.Object", [null]);
        show(false);
        var layer = G.integer(G.call("h2d.Object", "getChildIndex", root, [G.field(owner, "gameRoot")]));
        // Flow's override keeps its child/layout arrays synchronized.
        G.call("h2d.Flow", "addChildAt", root, [panel, layer]);
        var properties = G.call("h2d.Flow", "getProperties", root, [panel]);
        G.call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
        G.set(properties, "horizontalAlign", null);
        G.set(properties, "verticalAlign", null);
        G.set(properties, "offsetX", 0);
        G.set(properties, "offsetY", 0);
        frame = G.create("h2d.Graphics", [panel]);
        // Mask filters require a preceding sibling, never an ancestor.
        circleMask = G.create("h2d.Graphics", [panel]);
        position(circleMask, BORDER, BORDER);
        mask = G.create("h2d.Mask", [1, 1, panel]);
        position(mask, BORDER, BORDER);
        squareFilter = G.create("h2d.filter.Nothing", []);
        circleFilter = G.create("h2d.filter.Mask", [circleMask, false, true]);
        configureFilter(squareFilter, "h2d.filter.Filter");
        configureFilter(circleFilter, "h2d.filter.AbstractMask");
        pivot = G.create("h2d.Object", [mask]);
        terrain = G.create("h2d.Object", [pivot]);
        tileLayer = G.create("h2d.Object", [terrain]);
        arrow = G.create("h2d.Graphics", [mask]);
        MinimapMarkers.drawPlayerArrow(arrow, 10, 0xfff3d6);
        // NPCs are a final overlay above terrain, other markers, and the player
        // cursor. Only the minimap's outer boundary clips this layer.
        npcPivot = G.create("h2d.Object", [mask]);
        npcTerrain = G.create("h2d.Object", [npcPivot]);
        markers = new MinimapMarkers(terrain, npcTerrain, LEVEL);
    }

    function configureFilter(filter:Dynamic, type:String):Void {
        // Supersample only the bounded minimap, not the world-sized tile layer.
        // Bilinear downsampling smooths small marker edges at every zoom level.
        G.set(filter, "smooth", true);
        G.call(type, "set_useScreenResolution", filter, [true]);
        G.call(type, "set_resolutionScale", filter, [2.0]);
    }

    function layout(value:Int, round:Bool):Void {
        size = value;
        circular = round;
        bounds = "";
        G.set(mask, "width", size);
        G.set(mask, "height", size);
        position(arrow, size / 2, size / 2);
        position(pivot, size / 2, size / 2);
        position(npcPivot, size / 2, size / 2);
        G.call("h2d.Graphics", "clear", frame);
        G.call("h2d.Graphics", "clear", circleMask);
        G.call("h2d.Object", "set_filter", mask, [round ? circleFilter : squareFilter]);
        G.call("h2d.Object", "set_visible", circleMask, [round]);
        if (round) {
            circle(frame, size / 2 + BORDER, size / 2 + BORDER, size / 2 + BORDER, 0xb39888);
            circle(frame, size / 2 + BORDER, size / 2 + BORDER, size / 2, 0x17202b);
            circle(circleMask, size / 2, size / 2, size / 2, 0xffffff);
        } else {
            rectangle(0, 0, size + BORDER * 2, size + BORDER * 2, 0xb39888);
            rectangle(BORDER, BORDER, size, size, 0x17202b);
        }
    }

    function circle(graphics:Dynamic, x:Float, y:Float, radius:Float, color:Int):Void {
        G.call("h2d.Graphics", "beginFill", graphics, [color, 1.0]);
        G.call("h2d.Graphics", "drawCircle", graphics, [x, y, radius, 128]);
        G.call("h2d.Graphics", "endFill", graphics);
    }

    function rectangle(x:Float, y:Float, w:Float, h:Float, color:Int):Void {
        G.call("h2d.Graphics", "beginFill", frame, [color, 1.0]);
        G.call("h2d.Graphics", "drawRect", frame, [x, y, w, h]);
        G.call("h2d.Graphics", "endFill", frame);
    }

    function selectTiles(x:Float, y:Float, radius:Float):Void {
        var minX = Math.floor((x - radius) / tileWorldWidth);
        var maxX = Math.floor((x + radius) / tileWorldWidth);
        var minY = Math.floor((y - radius) / tileWorldWidth);
        var maxY = Math.floor((y + radius) / tileWorldWidth);
        var next = minX + ":" + maxX + ":" + minY + ":" + maxY;
        if (bounds == next) return;
        bounds = next;
        generation++;
        wanted = [];
        var keep:Map<String, Bool> = [];
        for (tx in minX...maxX + 1) for (ty in minY...maxY + 1) {
            var key = tileKey(tx, ty);
            var entry = index[key];
            if (entry == null) continue;
            keep[key] = true;
            entry.lastUsed = generation;
            wanted.push(entry);
        }
        for (key in [for (key in sprites.keys()) key]) if (!keep.exists(key)) {
            G.call("h2d.Object", "remove", sprites[key]);
            sprites.remove(key);
        }
        // Fill the player's tile first, then the surrounding terrain.
        wanted.sort((a, b) -> {
            var ax = (a.x + 0.5) * tileWorldWidth - x, ay = (a.y + 0.5) * tileWorldWidth - y;
            var bx = (b.x + 0.5) * tileWorldWidth - x, by = (b.y + 0.5) * tileWorldWidth - y;
            var delta = ax * ax + ay * ay - bx * bx - by * by;
            return delta < 0 ? -1 : delta > 0 ? 1 : 0;
        });
    }

    function loadNextTile():Void {
        for (entry in wanted) {
            var key = tileKey(entry.x, entry.y);
            if (sprites.exists(key)) continue;
            if (entry.tile == null) {
                var resource = G.call("hxd.res.Loader", "load", loader, [entry.path]);
                entry.tile = G.call("h2d.Tile", "clone", G.call("hxd.res.Any", "toTile", resource));
                // Opening the native map can center its cached tiles. Keep our copy independent.
                G.set(entry.tile, "dx", 0.0);
                G.set(entry.tile, "dy", 0.0);
                cached.push(entry);
            }
            var bitmap = G.create("h2d.Bitmap", [entry.tile, tileLayer]);
            G.call("h2d.Bitmap", "set_width", bitmap, [tileWorldWidth]);
            G.call("h2d.Bitmap", "set_height", bitmap, [tileWorldWidth]);
            position(bitmap, entry.x * tileWorldWidth, entry.y * tileWorldWidth);
            sprites[key] = bitmap;
            trimCache();
            return; // At most one image load per game update.
        }
    }

    function trimCache():Void {
        if (cached.length <= CACHE_LIMIT) return;
        cached.sort((a, b) -> a.lastUsed - b.lastUsed);
        while (cached.length > CACHE_LIMIT && cached[0].lastUsed < generation) {
            // Textures belong to the native resource loader; never dispose a shared texture.
            cached.shift().tile = null;
        }
    }

    static inline function tileKey(x:Int, y:Int):String return x + ":" + y;
    static function position(object:Dynamic, x:Float, y:Float):Void
        G.call("h2d.Object", "setPosition", object, [x, y]);
    function show(visible:Bool):Void {
        if (panel != null) G.call("h2d.Object", "set_visible", panel, [visible]);
    }

    public function dispose():Void {
        if (panel != null) {
            var old = panel;
            panel = null;
            G.call("h2d.Object", "remove", old);
        }
        owner = null; world = null; root = null; loader = null;
        frame = null; mask = null; circleMask = null; squareFilter = null; circleFilter = null;
        pivot = null; terrain = null; tileLayer = null; arrow = null; markers = null;
        npcPivot = null; npcTerrain = null;
        index = []; sprites = []; wanted = []; cached = [];
        size = 0; scale = 0; bounds = ""; generation = 0; circular = false;
    }
}
