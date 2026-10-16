package minimap;

import minimap.GameAccess as G;

/** The minimap's read-only markers, projected into the native overworld map. */
class BigMapView {
    static inline var LEVEL = "World/W1_Siagarta";
    static inline var MARKER_SIZE = 1.5;
    var window:Dynamic;
    var world:Dynamic;
    var hero:Dynamic;
    var scroll:Dynamic;
    var container:Dynamic;
    var markerViewport:Dynamic;
    var priorityViewport:Dynamic;
    var priorityRoot:Dynamic;
    var root:Dynamic;
    var filters:MainMapFilters;
    var filterBar:MainMapFilterBar;
    var bonusDungeon:MainMapBonusDungeon;
    var arrow:Dynamic;
    var iconCache:MainMapIconCache;
    var projection:Null<{x:Float, y:Float, width:Int, height:Int, zoom:Float, scale:Float}>;
    var hoverState:Null<{x:Float, y:Float, hx:Float, hy:Float, hz:Float, revision:Int, bonusWidth:Float, bonusVisible:Bool}>;
    var markers:MinimapMarkers;
    var rifts:RiftMarkers;
    var nativeMarkers:BigMapNativeMarkers;
    var revision:Int = -1;
    var nativeCount:Int = -1;
    var tileScale:Float = 0;
    var scale:Float = 0;
    var ownScale:Float = 0;
    var overlay:Dynamic;
    var input:Dynamic;
    var width:Float = 0;
    var height:Float = 0;
    var hovered:Bool = false;
    var mouseX:Float = 0;
    var mouseY:Float = 0;
    var caption:Dynamic;
    var measurements:HoverMeasurements;
    var captionScale:Float = 1;
    var captionKey:String = "";
    var captionVisible:Bool = false;
    var retryAt:Float = 0;
    var reportedError:Bool = false;

    public function new(?save:Void->Void) filters = new MainMapFilters(save);

    public function update(nextWindow:Dynamic, config:MinimapSettings):Void {
        if (haxe.Timer.stamp() < retryAt) return;
        try updateView(nextWindow, config) catch (error:Dynamic) {
            dispose();
            retryAt = haxe.Timer.stamp() + 10;
            if (!reportedError) {
                reportedError = true;
                trace("[Minimap] Big map: " + Std.string(error));
            }
        }
    }

    function updateView(nextWindow:Dynamic, config:MinimapSettings):Void {
        var nextHero = G.call("ui.BaseElement", "get_myHero", nextWindow);
        var nextWorld = G.field(G.field(nextHero, "layer"), "world");
        // Instance coordinates must not be projected onto the overworld.
        if (!config.enabled || !config.overrideBigMapMarkers || nextHero == null
            || G.field(nextHero, "removed") == true || G.text(G.field(nextWorld, "level")) != LEVEL
            || G.field(nextWindow, "removed") == true) {
            dispose();
            return;
        }
        filters.bind(config);
        var nextScroll = G.field(nextWindow, "scroll");
        var nextContainer = G.field(nextWindow, "scrollContainer");
        if (nextScroll == null || nextContainer == null) { dispose(); return; }
        if (window != nextWindow || scroll != nextScroll || container != nextContainer || hero != nextHero || world != nextWorld) {
            dispose();
            window = nextWindow; scroll = nextScroll; container = nextContainer; hero = nextHero; world = nextWorld;
            create();
        }
        var nextTileScale = G.number(G.call("ui.win.MapWindow", "get_tileScale", window));
        var zoom = G.number(G.field(window, "zoom"));
        var nextScale = nextTileScale * zoom;
        if (!Math.isFinite(nextScale) || nextScale <= 0) throw "Invalid map projection";
        tileScale = nextTileScale;
        scale = nextScale;
        updateProjection(zoom);
        rifts.update(G.field(hero, "layer"), haxe.Timer.stamp());
        // The entire map can be panned, not just the minimap's area around the
        // hero. Static locations remain cached; live data still samples at 5 Hz.
        markers.setViewport(projection.x, projection.y, projection.width, projection.height);
        markers.update(hero, filters.settings(), 0, 0, Math.POSITIVE_INFINITY, scale, 0, rifts);
        if (!markers.healthy) throw "Marker refresh failed";
        var count = G.integer(G.field(G.field(window, "markers"), "length"));
        if (revision != markers.revision || nativeCount != count) {
            nativeMarkers.sample(window, markers.points, hero);
            revision = markers.revision; nativeCount = count;
        }
        nativeMarkers.apply(window, tileScale, hero);
        var newOwnScale = filters.settings().markerScale / 100 * MARKER_SIZE / scale;
        if (ownScale != newOwnScale) {
            ownScale = newOwnScale;
            G.call("h2d.Object", "setScale", arrow, [ownScale]);
        }
        var hx = G.number(G.field(hero, "posx")), hy = G.number(G.field(hero, "posy"));
        if (G.field(arrow, "x") != hx || G.field(arrow, "y") != hy)
            G.call("h2d.Object", "setPosition", arrow, [hx, hy]);
        var heading = G.number(G.field(hero, "rotationZ"));
        if (G.field(arrow, "rotation") != heading) G.call("h2d.Object", "set_rotation", arrow, [heading]);
        var mapWidth = G.number(G.field(container, "calculatedWidth")), mapHeight = G.number(G.field(container, "calculatedHeight"));
        bonusDungeon.update(hero, mapWidth, mapHeight);
        filterBar.update(window, mapWidth, mapHeight, bonusDungeon.visible ? 76 : 0);
        updateHover();
    }

    function create():Void {
        // Masks clip the two native layers; sharpness comes from shared small
        // icon textures, without any per-frame offscreen layer rendering.
        if (iconCache == null) iconCache = new MainMapIconCache(G.field(window, "markers"));
        markerViewport = createViewport(15);
        priorityViewport = createViewport(26);
        root = G.create("h2d.Object", [markerViewport]);
        priorityRoot = G.create("h2d.Object", [priorityViewport]);
        var players = G.create("h2d.Object", [root]);
        var foreground = G.create("h2d.Object", [root]);
        markers = new MinimapMarkers(players, foreground, root, LEVEL, MARKER_SIZE, priorityRoot, iconCache);
        markers.ownFirst = true;
        markers.pointFilter = filters.accepts;
        // After the party layer, above every native and replacement marker.
        arrow = iconCache.bitmap(priorityRoot, "own", g -> MinimapMarkers.drawPlayerArrow(g, 10, 0xfff3d6));
        rifts = new RiftMarkers(LEVEL);
        nativeMarkers = new BigMapNativeMarkers();
        overlay = G.create("h2d.Object", [container]);
        var properties = G.call("h2d.Flow", "getProperties", container, [overlay]);
        G.call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
        G.set(properties, "horizontalAlign", null);
        G.set(properties, "verticalAlign", null);
        G.set(properties, "offsetX", 0);
        G.set(properties, "offsetY", 0);
        input = G.create("h2d.Interactive", [1.0, 1.0, overlay, null]);
        G.set(input, "propagateEvents", true);
        G.set(input, "onMove", (event:Dynamic) -> trackMouse(event));
        G.set(input, "onCheck", (event:Dynamic) -> trackMouse(event));
        G.set(input, "onOver", (event:Dynamic) -> trackMouse(event));
        G.set(input, "onOut", (_:Dynamic) -> { hovered = false; hoverState = null; hideCaption(); });
        G.set(input, "onPush", (_:Dynamic) -> { if (filterBar != null) filterBar.closePopup(); });
        bonusDungeon = new MainMapBonusDungeon(overlay, container);
        filterBar = new MainMapFilterBar(container, filters, markers.createFilterIcon);
    }

    function createViewport(layer:Int):Dynamic {
        var viewport = G.create("h2d.Mask", [1, 1, null]);
        try {
            G.call("h2d.Layers", "add", scroll, [viewport, layer, null]);
        } catch (error:Dynamic) {
            G.call("h2d.Object", "remove", viewport);
            throw error;
        }
        return viewport;
    }

    function updateProjection(zoom:Float):Void {
        var w = Std.int(Math.ceil(G.number(G.field(container, "calculatedWidth"))));
        var h = Std.int(Math.ceil(G.number(G.field(container, "calculatedHeight"))));
        var x = G.number(G.field(scroll, "x")), y = G.number(G.field(scroll, "y"));
        if (projection != null && projection.x == x && projection.y == y && projection.width == w
            && projection.height == h && projection.zoom == zoom && projection.scale == scale) return;
        projection = {x:x, y:y, width:w, height:h, zoom:zoom, scale:scale};
        // Both layers stay viewport-sized, regardless of world zoom/panning.
        for (viewport in [markerViewport, priorityViewport]) {
            G.set(viewport, "width", w); G.set(viewport, "height", h);
            G.call("h2d.Object", "setScale", viewport, [1 / zoom]);
            G.call("h2d.Object", "setPosition", viewport, [-x / zoom, -y / zoom]);
        }
        for (object in [root, priorityRoot]) {
            G.call("h2d.Object", "setScale", object, [scale]);
            G.call("h2d.Object", "setPosition", object, [x, y]);
        }
    }

    function trackMouse(event:Dynamic):Void {
        mouseX = G.number(G.field(event, "relX"));
        mouseY = G.number(G.field(event, "relY"));
        hovered = mouseX >= 0 && mouseY >= 0 && mouseX < width && mouseY < height;
    }

    function updateHover():Void {
        if (G.field(overlay, "x") != 0. || G.field(overlay, "y") != 0.)
            G.call("h2d.Object", "setPosition", overlay, [0., 0.]);
        var w = G.number(G.field(container, "calculatedWidth")), h = G.number(G.field(container, "calculatedHeight"));
        if (width != w || height != h) {
            width = w; height = h;
            G.set(input, "width", width);
            G.set(input, "height", height);
            captionKey = ""; hoverState = null;
        }
        if (!hovered || filterBar.contains(mouseX, mouseY) || G.call("h2d.Interactive", "isOver", input) != true) { hoverState = null; hideCaption(); return; }
        // Use the displayed scroll transform, including smooth zoom and pan,
        // rather than targetZoom or the rounded native mouse-world coordinates.
        var x = (mouseX - projection.x) / scale;
        var y = (mouseY - projection.y) / scale;
        var hx = G.number(G.field(hero, "posx")), hy = G.number(G.field(hero, "posy"));
        var hz = G.number(G.field(hero, "posz"), Math.NaN);
        if (hoverState != null && hoverState.x == x && hoverState.y == y && hoverState.hx == hx && hoverState.hy == hy
            && hoverState.hz == hz && hoverState.revision == markers.viewRevision
            && hoverState.bonusWidth == bonusDungeon.width && hoverState.bonusVisible == bonusDungeon.visible) return;
        hoverState = {x:x, y:y, hx:hx, hy:hy, hz:hz, revision:markers.viewRevision,
            bonusWidth:bonusDungeon.width, bonusVisible:bonusDungeon.visible};
        var target = markers.hoverAt(x, y, scale, hx, hy, hero);
        if (target == null) { hideCaption(); return; }
        var details = MarkerDetails.measurements(target, {x: hx, y: hy, z: hz});
        var key = target.name + [for (part in details) part.direction + ":" + part.metres].join("|")
            + "|bonus:" + bonusDungeon.visible + ":" + bonusDungeon.width;
        if (captionKey == key) return;
        ensureCaption();
        captionKey = key;
        captionVisible = true;
        G.call("h2d.Text", "set_text", caption, [target.name]);
        G.call("h2d.Object", "set_visible", caption, [true]);
        var maxWidth = Math.max(1, Math.min(width - 32, 640));
        var footerOffset = 0.;
        if (bonusDungeon.visible) {
            var available = width - 2 * (bonusDungeon.width + 28);
            // Keep the caption centered without covering the bonus card.
            if (available >= 220) maxWidth = Math.min(maxWidth, available);
            else footerOffset = 60;
        }
        var textScale = Math.min(captionScale, maxWidth / Math.max(1, G.number(G.call("h2d.Text", "get_textWidth", caption))));
        var textWidth = G.number(G.call("h2d.Text", "get_textWidth", caption)) * textScale;
        G.call("h2d.Object", "setScale", caption, [textScale]);
        G.call("h2d.Object", "setPosition", caption, [(width - textWidth) / 2, height - 72 - footerOffset]);
        measurements.setValues(details);
        measurements.place(width / 2, height - 40 - footerOffset, maxWidth);
    }

    function ensureCaption():Void {
        if (caption != null) return;
        var font = G.staticCall("hxd.res.DefaultFont", "get", []);
        captionScale = 22 / Math.max(1, G.number(G.field(font, "size"), 14));
        caption = G.create("h2d.Text", [font, overlay]);
        G.call("h2d.Text", "set_textColor", caption, [0xfff3d6]);
        // A tight, solid black border stays legible without an offset shadow.
        MapTextOutline.apply(caption, 1.0);
        measurements = new HoverMeasurements(overlay, font, 1.5, 1.0, false);
    }

    function hideCaption():Void {
        captionKey = "";
        if (!captionVisible) return;
        captionVisible = false;
        G.call("h2d.Object", "set_visible", caption, [false]);
        measurements.setValues([]);
    }

    public function remove(instance:Dynamic):Void {
        if (window == instance) dispose();
        retryAt = 0;
    }

    public function refreshNative(instance:Dynamic):Void {
        if (window == instance && nativeMarkers != null) nativeMarkers.invalidate();
    }

    /** Keep reusable icon textures across map closes, release them with the game. */
    public function release():Void {
        dispose();
        if (iconCache != null) iconCache.dispose();
        iconCache = null;
    }

    public function dispose():Void {
        if (nativeMarkers != null) try nativeMarkers.dispose() catch (_:Dynamic) {}
        if (filterBar != null) try filterBar.dispose() catch (_:Dynamic) {}
        if (bonusDungeon != null) try bonusDungeon.dispose() catch (_:Dynamic) {}
        for (object in [root, markerViewport, priorityRoot, priorityViewport, overlay]) if (object != null) try G.call("h2d.Object", "remove", object) catch (_:Dynamic) {}
        if (window != null && G.field(window, "removed") != true) try {
            // Re-evaluate current native filters instead of restoring stale
            // visibility from when the map was first opened.
            G.call("ui.win.MapWindow", "refreshVisuals", window);
            G.call("ui.win.MapWindow", "updateMapInfos", window);
        } catch (_:Dynamic) {}
        window = null; world = null; hero = null; scroll = null; container = null;
        bonusDungeon = null; filterBar = null; priorityRoot = null; priorityViewport = null;
        markerViewport = null; root = null; arrow = null; markers = null; rifts = null; nativeMarkers = null;
        overlay = null; input = null; caption = null; measurements = null;
        projection = null; hoverState = null;
        revision = -1; nativeCount = -1; tileScale = 0; scale = 0; ownScale = 0;
        width = 0; height = 0; hovered = false; captionKey = ""; captionVisible = false;
    }
}
