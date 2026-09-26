package minimap;

import minimap.GameAccess as G;
import minimap.MinimapMod.MinimapSettings;

private typedef MapTile = {
    var x:Int;
    var y:Int;
    var resolution:Int;
    var path:String;
    var tile:Dynamic;
    var loading:MapTileLoad;
    var lastUsed:Int;
}

/** Native map resources in a small HUD, without constructing a MapWindow. */
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
    var compass:MinimapCompass;
    var rifts:RiftMarkers;
    var riftText:Dynamic;
    var riftShadow:Dynamic;
    var riftFontSource:Dynamic;
    var riftFont:Dynamic;
    var riftCaption:String = "";
    var riftColor:Int = -1;
    var riftFontScale:Float = 1;
    var riftWidth:Float = 0;
    var riftHeight:Float = 0;
    var riftX:Float = Math.NaN;
    var riftY:Float = Math.NaN;
    var arrow:Dynamic;
    var input:Dynamic;
    var hovered:Bool = false;
    var mouseX:Float = 0;
    var mouseY:Float = 0;
    var hoverText:Dynamic;
    var hoverShadow:Dynamic;
    var hoverMeasurements:HoverMeasurements;
    var hoverCaption:String = "";
    var hoverDetails:String = "";
    var hoverFontScale:Float = 1;
    var nextHoverRefresh:Float = 0;
    var hoverMouseX:Float = Math.NaN;
    var hoverMouseY:Float = Math.NaN;
    var transparency:Int = -1;
    var markerScale:Float = 0;
    var loader:Dynamic;
    var tileWorldWidth:Float = 0;
    var size:Int = 0;
    var panelX:Float = Math.NaN;
    var panelY:Float = Math.NaN;
    var scale:Float = 0;
    var bounds:String = "";
    var index:Map<String, MapTile> = [];
    var sprites:Map<String, Dynamic> = [];
    var wanted:Array<MapTile> = [];
    var prefetch:Array<MapTile> = [];
    var pending:Array<MapTile> = [];
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
        if (markerScale != config.markerScale) {
            markerScale = config.markerScale;
            G.call("h2d.Object", "setScale", arrow, [markerScale / 100]);
        }
        if (transparency != config.transparency) {
            transparency = config.transparency;
            G.set(panel, "alpha", 1 - transparency / 100);
            // A fully invisible map must not consume wheel input.
            G.call("h2d.Object", "set_visible", input, [transparency < 100]);
            if (transparency == 100) { hovered = false; setHoverCaption(""); }
        }
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
        var outerSize = size + BORDER * 2;
        var screenWidth = G.number(G.call("h2d.Flow", "get_innerWidth", root));
        var screenHeight = G.number(G.call("h2d.Flow", "get_innerHeight", root));
        var nextX = MinimapPosition.axis(screenWidth, outerSize, config.xOffset, !config.leftCorner);
        var nextY = MinimapPosition.axis(screenHeight, outerSize, config.yOffset);
        if (panelX != nextX || panelY != nextY) {
            panelX = nextX; panelY = nextY;
            hovered = false;
            setHoverCaption("");
        }
        // A native Flow reflow can move absolute children; reapply after measuring it.
        position(panel, panelX, panelY);
        // A rotating square needs enough tiles/markers to cover its diagonal.
        var radius = size / (2 * scale) * (config.rotateMap && !circular ? Math.sqrt(2) : 1);
        selectTiles(x, y, radius);
        loadNextTile();
        rifts.update(G.field(hero, "layer"), haxe.Timer.stamp());
        markers.update(hero, config, x, y, radius, scale, rotation, rifts);
        markers.updateAlerts(config, x, y, size, scale, rotation, rifts);
        compass.update(size, circular, rotation, markerScale / 100, config.showNorthIndicator);
        updateRiftTimer(config);
        show(true);
        updateHover(hero, x, y, rotation);
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
            index[key] = {x: x, y: y, resolution: resolution, path: DIRECTORY + "/" + name, tile: null, loading: null, lastUsed: 0};
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
        // Non-player markers overlay both player layers. Only the minimap's
        // outer boundary clips them; NPCs retain priority within this overlay.
        npcPivot = G.create("h2d.Object", [mask]);
        npcTerrain = G.create("h2d.Object", [npcPivot]);
        markers = new MinimapMarkers(terrain, npcTerrain, mask, LEVEL);
        compass = new MinimapCompass(mask);
        rifts = new RiftMarkers(LEVEL);
        input = G.create("h2d.Interactive", [1.0, 1.0, panel, null]);
        position(input, BORDER, BORDER);
        G.call("h2d.Interactive", "set_cursor", input, [G.current("hxd.Cursor", "Default")]);
        G.set(input, "propagateEvents", true);
        G.set(input, "onMove", (event:Dynamic) -> trackMouse(event));
        G.set(input, "onCheck", (event:Dynamic) -> trackMouse(event));
        G.set(input, "onOver", (event:Dynamic) -> trackMouse(event));
        G.set(input, "onOut", (_:Dynamic) -> { hovered = false; setHoverCaption(""); });
        G.set(input, "onWheel", (event:Dynamic) -> {
            trackMouse(event);
            if (!hovered || G.field(panel, "visible") != true) return;
            G.set(event, "propagate", false);
            MinimapMod.adjustZoom(G.number(G.field(event, "wheelDelta")));
        });
    }

    function trackMouse(event:Dynamic):Void {
        // Interactive supplies local coordinates, including the game's UI scale.
        mouseX = G.number(G.field(event, "relX"));
        mouseY = G.number(G.field(event, "relY"));
        var dx = mouseX - size / 2, dy = mouseY - size / 2;
        hovered = mouseX >= 0 && mouseY >= 0 && mouseX <= size && mouseY <= size
            && (!circular || dx * dx + dy * dy <= size * size / 4);
    }

    function updateHover(hero:Dynamic, x:Float, y:Float, rotation:Float):Void {
        if (!hovered || G.call("h2d.Interactive", "isOver", input) != true) {
            setHoverCaption("");
            return;
        }
        var dx = mouseX - size / 2, dy = mouseY - size / 2;
        var c = Math.cos(rotation), s = Math.sin(rotation);
        // Undo the displayed map rotation and zoom before picking a marker.
        var px = x + (dx * c + dy * s) / scale;
        var py = y + (dy * c - dx * s) / scale;
        var target = markers.alertHoverAt(mouseX, mouseY);
        if (target == null) target = markers.hoverAt(px, py, scale, x, y, hero);
        if (target == null) {
            setHoverCaption("");
            return;
        }
        var now = haxe.Timer.stamp();
        // Mouse selection is immediate; stationary hover measurements update
        // at the same 5 Hz as markers, rather than changing numbers every frame.
        if (target.name == hoverCaption && mouseX == hoverMouseX && mouseY == hoverMouseY && now < nextHoverRefresh) return;
        ensureHoverText();
        var details = MarkerDetails.measurements(target,
            {x: x, y: y, z: G.number(G.field(hero, "posz"), Math.NaN)});
        setHoverCaption(target.name, details);
        hoverMouseX = mouseX; hoverMouseY = mouseY;
        nextHoverRefresh = now + 0.2;
    }

    function ensureHoverText():Void {
        if (hoverText != null) return;
        // Reuse a native HUD font after its UI has finished loading.
        var font = findFont(G.field(owner, "gameRoot"), 6);
        if (font == null) font = G.staticCall("hxd.res.DefaultFont", "get", []);
        hoverFontScale = 14 / Math.max(1, G.number(G.field(font, "size"), 14));
        hoverShadow = G.create("h2d.Text", [font, panel]);
        hoverText = G.create("h2d.Text", [font, panel]);
        hoverMeasurements = new HoverMeasurements(panel, font);
        G.call("h2d.Text", "set_textColor", hoverShadow, [0x171b24]);
        G.call("h2d.Text", "set_textColor", hoverText, [0xfff3d6]);
    }

    function setHoverCaption(value:String, ?details:Array<minimap.MarkerDetails.MarkerMeasurement>):Void {
        if (value == "") { details = null; nextHoverRefresh = 0; }
        if (details == null) details = [];
        var detailKey = [for (part in details) part.direction + ":" + part.metres].join("|");
        if (value == hoverCaption && detailKey == hoverDetails) return;
        hoverCaption = value;
        hoverDetails = detailKey;
        if (value != "") ensureHoverText();
        if (hoverText == null) return;
        for (text in [hoverShadow, hoverText]) {
            G.call("h2d.Text", "set_text", text, [value]);
            G.call("h2d.Object", "set_visible", text, [value != ""]);
        }
        hoverMeasurements.setValues(details);
        placeHoverText();
    }

    function placeHoverText():Void {
        if (hoverText == null || hoverCaption == "") return;
        // A footer outside the clipping mask stays whole in circular mode too.
        var bottom = placeHoverLine(hoverText, hoverShadow, hoverFontScale, BORDER + size + 4);
        hoverMeasurements.place(BORDER + size / 2, bottom + 2, size - 12);
    }

    function placeHoverLine(text:Dynamic, shadow:Dynamic, desiredScale:Float, y:Float):Float {
        var width = G.number(G.call("h2d.Text", "get_textWidth", text));
        // Fit lines independently: a long name must not shrink the measurements.
        var textScale = Math.min(desiredScale, (size - 12) / Math.max(1, width));
        for (object in [shadow, text]) G.call("h2d.Object", "setScale", object, [textScale]);
        var x = BORDER + (size - width * textScale) / 2;
        position(shadow, x + 1, y + 1);
        position(text, x, y);
        return y + G.number(G.call("h2d.Text", "get_textHeight", text)) * textScale;
    }

    function updateRiftTimer(config:MinimapSettings):Void {
        var caption = config.showRiftTimer ? RiftTiming.caption(rifts.remaining) : "";
        if (caption != "" && riftFontSource == null) {
            var dom = G.field(G.field(owner, "gameRoot"), "dom");
            if (dom == null) return;
            // Ask the game's stylesheet for a specific bold face. Picking the
            // first HUD font depended on loading order and could stay on a fallback.
            var style = G.staticCall("domkit.Properties", "createNew",
                ["text", dom, [""], {id: "minimapRiftFont", "class": "bold-16"}]);
            riftFontSource = G.field(style, "obj");
            if (riftFontSource == null) return;
            G.call("h2d.Object", "set_visible", riftFontSource, [false]);
        }
        var font = G.field(riftFontSource, "font");
        if (caption != "" && riftText == null) {
            if (font == null) return;
            riftShadow = G.create("h2d.Text", [font, panel]);
            riftText = G.create("h2d.Text", [font, panel]);
            G.call("h2d.Text", "set_textColor", riftShadow, [0x171b24]);
        }
        if (riftText == null) return;
        // Native styles can settle a frame later or change with the UI locale.
        // Refresh the font and metrics only when the actual font changes.
        var fontChanged = font != null && font != riftFont;
        if (fontChanged) {
            riftFont = font;
            riftFontScale = 16 / Math.max(1, G.number(G.field(font, "size"), 16));
            for (text in [riftShadow, riftText]) {
                G.call("h2d.Text", "set_font", text, [font]);
                G.call("h2d.Object", "setScale", text, [riftFontScale]);
            }
        }
        if (caption != riftCaption || fontChanged) {
            riftCaption = caption;
            for (text in [riftShadow, riftText]) {
                G.call("h2d.Text", "set_text", text, [caption]);
                G.call("h2d.Object", "set_visible", text, [caption != ""]);
            }
            if (caption != "") {
                riftWidth = G.number(G.call("h2d.Text", "get_textWidth", riftText)) * riftFontScale;
                riftHeight = G.number(G.call("h2d.Text", "get_textHeight", riftText)) * riftFontScale;
            }
        }
        var color = config.riftAlerts && rifts.alertActive() ? LandmarkIcons.RIFT_ALERT_COLOR : 0xfff3d6;
        if (color != riftColor) {
            riftColor = color;
            G.call("h2d.Text", "set_textColor", riftText, [color]);
        }
        if (caption == "") return;
        var x = Math.round(BORDER + (size - riftWidth) / 2);
        // Seven pixels above the frame, versus four below it for hover text.
        // Keep the caption on-screen even with a very small viewport.
        var y = Math.ceil(Math.max(2 - panelY, -riftHeight - 7));
        if (x != riftX || y != riftY) {
            riftX = x; riftY = y;
            position(riftShadow, x + 1, y + 1);
            position(riftText, x, y);
        }
    }

    function findFont(object:Dynamic, depth:Int):Dynamic {
        if (object == null || depth < 0) return null;
        var font = G.field(object, "font");
        if (font != null) return font;
        var count = G.integer(G.call("h2d.Object", "get_numChildren", object));
        for (i in 0...count) {
            font = findFont(G.call("h2d.Object", "getChildAt", object, [i]), depth - 1);
            if (font != null) return font;
        }
        return null;
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
        G.set(input, "width", size * 1.0);
        G.set(input, "height", size * 1.0);
        G.set(input, "isEllipse", round);
        hovered = false;
        setHoverCaption("");
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
        // A small adjacent ring prepares likely next tiles before they enter
        // view. Visible requests always take priority over speculative work.
        prefetch = [];
        for (tx in minX - 1...maxX + 2) for (ty in minY - 1...maxY + 2) {
            var key = tileKey(tx, ty);
            var entry = index[key];
            if (entry != null && !keep.exists(key)) prefetch.push(entry);
        }
        prefetch.sort((a, b) -> {
            var ax = (a.x + 0.5) * tileWorldWidth - x, ay = (a.y + 0.5) * tileWorldWidth - y;
            var bx = (b.x + 0.5) * tileWorldWidth - x, by = (b.y + 0.5) * tileWorldWidth - y;
            var delta = ax * ax + ay * ay - bx * bx - by * by;
            return delta < 0 ? -1 : delta > 0 ? 1 : 0;
        });
        var ahead = Std.int(Math.max(0, Math.min(4, CACHE_LIMIT - wanted.length)));
        if (prefetch.length > ahead) prefetch.resize(ahead);
        // Protect selected prefetches from immediate eviction behind older
        // visible tiles; otherwise a full cache would repeatedly request them.
        for (entry in prefetch) entry.lastUsed = generation;
    }

    function loadNextTile():Void {
        for (entry in pending) {
            var tile = entry.loading.take();
            if (tile == null) continue;
            entry.tile = tile; entry.loading = null;
            cached.push(entry); pending.remove(entry);
            trimCache();
            break; // Bound foreground finalization too.
        }
        for (entry in wanted) {
            var key = tileKey(entry.x, entry.y);
            if (sprites.exists(key)) continue;
            if (entry.tile == null) {
                if (entry.loading == null && pending.length < 2) { requestTile(entry); return; }
                continue;
            }
            var bitmap = G.create("h2d.Bitmap", [entry.tile, tileLayer]);
            G.call("h2d.Bitmap", "set_width", bitmap, [tileWorldWidth]);
            G.call("h2d.Bitmap", "set_height", bitmap, [tileWorldWidth]);
            position(bitmap, entry.x * tileWorldWidth, entry.y * tileWorldWidth);
            sprites[key] = bitmap;
            trimCache();
            return; // At most one bitmap attachment per game update.
        }
        if (pending.length < 2) for (entry in prefetch) if (entry.tile == null && entry.loading == null) {
            requestTile(entry); return;
        }
    }

    function requestTile(entry:MapTile):Void {
        var resource = G.call("hxd.res.Loader", "load", loader, [entry.path]);
        entry.loading = new MapTileLoad(resource);
        pending.push(entry);
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
        if (!visible) { hovered = false; setHoverCaption(""); }
    }

    public function dispose():Void {
        // The hidden font source belongs to gameRoot's DOM, outside our panel.
        if (riftFontSource != null) G.call("h2d.Object", "remove", riftFontSource);
        if (panel != null) {
            var old = panel;
            panel = null;
            G.call("h2d.Object", "remove", old);
        }
        owner = null; world = null; root = null; loader = null;
        frame = null; mask = null; circleMask = null; squareFilter = null; circleFilter = null;
        pivot = null; terrain = null; tileLayer = null; arrow = null; markers = null; compass = null;
        rifts = null; riftText = null; riftShadow = null; riftCaption = ""; riftColor = -1;
        riftFontSource = null; riftFont = null;
        riftX = Math.NaN; riftY = Math.NaN;
        npcPivot = null; npcTerrain = null;
        input = null; hovered = false; hoverText = null; hoverShadow = null; hoverCaption = "";
        hoverMeasurements = null; hoverDetails = "";
        nextHoverRefresh = 0; hoverMouseX = Math.NaN; hoverMouseY = Math.NaN;
        transparency = -1;
        markerScale = 0;
        index = []; sprites = []; wanted = []; cached = []; prefetch = []; pending = [];
        size = 0; scale = 0; bounds = ""; generation = 0; circular = false;
        panelX = Math.NaN; panelY = Math.NaN;
    }
}
