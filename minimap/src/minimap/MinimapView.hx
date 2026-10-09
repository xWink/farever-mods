package minimap;

import minimap.GameAccess as G;
import minimap.MinimapMod.MinimapSettings;
import minimap.PinPlacement.PinClick;

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
    static inline var WATER = 0x0B1B3C;
    static inline var WATER_EDGE = 0x061428;
    /** Parchment frame sampled from the DPS meter window. The map itself stays water blue. */
    static inline var PARCHMENT = 0xD0BBB2;
    static inline var PARCHMENT_EDGE = 0x7A512F;
    static inline var PARCHMENT_LINE = 0xA78474;
    static inline var INK = 0x5B4334;
    static inline var HOVER_INK = 0x24160C;
    static inline var DIALOG_PAD = 18;
    static inline var DIALOG_HEADER = 36;
    static inline var DIALOG_FOOTER = 52;
    static inline var DIALOG_TOGGLE = 46;

    var world:Dynamic;
    var game:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var panel:Dynamic;
    var frame:Dynamic;
    var ocean:Dynamic;
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
    var partyPivot:Dynamic;
    var partyTerrain:Dynamic;
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
    var controls:MinimapControls;
    var hovered:Bool = false;
    var mouseX:Float = 0;
    var mouseY:Float = 0;
    var heroX:Float = 0;
    var heroY:Float = 0;
    var mapScale:Float = 1;
    var mapRotation:Float = 0;
    var lastClick:PinClick;
    var ignoreClicksUntil:Float = 0;
    var expanded:Bool = false;
    var panX:Float = 0;
    var panY:Float = 0;
    var dragging:Bool = false;
    var dragMoved:Bool = false;
    var dragX:Float = 0;
    var dragY:Float = 0;
    var mapHeight:Int = 0;
    var shield:Dynamic;
    var scrim:Dynamic;
    var scrimWidth:Float = -1;
    var scrimHeight:Float = -1;
    var dialogW:Float = 0;
    var dialogH:Float = 0;
    var mapWindow:MapWindow;
    var usingWindow:Bool = false;
    var contentX:Float = BORDER;
    var contentY:Float = BORDER;
    var stacked:Bool = false;
    /** Heaps drops Graphics contents when an object leaves the scene. */
    var graphicsCleared:Bool = false;
    var viewX:Float = 0;
    var viewY:Float = 0;
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
        game = app;
        var nextWorld = G.field(app, "world");
        var ui = G.current("ui.BaseUI", "current");
        if (nextWorld != world || ui != owner) dispose();
        var hero = G.field(app, "hero");
        if (!config.enabled || hero == null || G.field(hero, "removed") == true
            || G.text(G.field(nextWorld, "level")) != LEVEL || ui == null) {
            closeExpanded();
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

        if (markerScale != config.markerScale) {
            markerScale = config.markerScale;
            G.call("h2d.Object", "setScale", arrow, [markerScale / 100]);
        }
        if (transparency != config.transparency) {
            transparency = config.transparency;
            var alpha = 1 - transparency / 100;
            G.set(panel, "alpha", alpha);
            if (mapWindow != null) mapWindow.setAlpha(alpha);
            // A fully invisible map must not consume wheel input.
            G.call("h2d.Object", "set_visible", input, [transparency < 100]);
            if (transparency == 100) { hovered = false; setHoverCaption(""); }
        }
        var newScale = config.zoom / 100 * 2; // Two UI pixels per world unit at 100%.
        if (newScale != scale) {
            scale = newScale;
            G.call("h2d.Object", "setScale", terrain, [scale]);
            G.call("h2d.Object", "setScale", npcTerrain, [scale]);
            G.call("h2d.Object", "setScale", partyTerrain, [scale]);
            bounds = "";
        }
        var x = G.number(G.field(hero, "posx"));
        var y = G.number(G.field(hero, "posy"));
        heroX = x;
        heroY = y;
        mapScale = scale;
        var heading = G.number(G.field(hero, "rotationZ"));
        var orientation = config.rotateMap && config.followCamera ? cameraHeading(app, heading) : heading;
        var rotation = config.rotateMap ? -Math.PI / 2 - orientation : 0.0;
        mapRotation = rotation;
        var viewCenterX = x + (expanded ? panX : 0);
        var viewCenterY = y + (expanded ? panY : 0);
        viewX = viewCenterX;
        viewY = viewCenterY;
        // Native facing is (cos(heading), sin(heading)); screen-up is -PI/2.
        G.call("h2d.Object", "set_rotation", pivot, [rotation]);
        G.call("h2d.Object", "set_rotation", npcPivot, [rotation]);
        G.call("h2d.Object", "set_rotation", partyPivot, [rotation]);
        position(terrain, -viewCenterX * scale, -viewCenterY * scale);
        position(npcTerrain, -viewCenterX * scale, -viewCenterY * scale);
        position(partyTerrain, -viewCenterX * scale, -viewCenterY * scale);
        var screenWidth = G.number(G.call("h2d.Flow", "get_innerWidth", root));
        var screenHeight = G.number(G.call("h2d.Flow", "get_innerHeight", root));
        var viewW = config.size;
        var viewH = config.size;
        var round = config.circular;
        if (expanded) {
            var outer = MinimapPosition.overview(screenWidth, screenHeight);
            dialogW = outer.width;
            dialogH = outer.height;
            if (mapWindow == null) mapWindow = new MapWindow();
            usingWindow = mapWindow.ensure(owner);
            if (usingWindow) {
                // Body sits under the native header. The map, hover footer, and toggles share it.
                var bodyW = dialogW - MapWindow.INSET * 2;
                var bodyH = dialogH - MapWindow.HEADER - MapWindow.INSET;
                viewW = Std.int(Math.max(1, bodyW - DIALOG_PAD * 2 - DIALOG_TOGGLE - 8));
                viewH = Std.int(Math.max(1, bodyH - DIALOG_PAD * 2 - DIALOG_FOOTER));
            } else {
                viewW = Std.int(Math.max(1, dialogW - DIALOG_PAD * 2 - DIALOG_TOGGLE - 8));
                viewH = Std.int(Math.max(1, dialogH - DIALOG_PAD * 2 - DIALOG_HEADER - DIALOG_FOOTER));
            }
            round = false;
        } else usingWindow = false;
        if (size != viewW || mapHeight != viewH || circular != round) layout(viewW, viewH, round);
        var heroOnMap = PinPlacement.screen(x, y, viewCenterX, viewCenterY, scale, rotation);
        position(arrow, size / 2 + heroOnMap.x, mapHeight / 2 + heroOnMap.y);
        G.call("h2d.Object", "set_rotation", arrow, [heading + rotation]);
        var outerW = expanded ? dialogW : size + BORDER * 2;
        var outerH = expanded ? dialogH : mapHeight + BORDER * 2;
        // Keep the category column inside the same screen margin as the card.
        var buttons = !expanded && config.showCategoryButtons ? MinimapControls.columnExtra(size, circular) : 0;
        var nextX = expanded ? (screenWidth - outerW) / 2 : MinimapPosition.axis(screenWidth, outerW + buttons, config.xOffset, !config.leftCorner);
        var nextY = expanded ? (screenHeight - outerH) / 2 : MinimapPosition.axis(screenHeight, outerH, config.yOffset);
        if (panelX != nextX || panelY != nextY) {
            panelX = nextX; panelY = nextY;
            hovered = false;
            setHoverCaption("");
        }
        // A native Flow reflow can move absolute children; reapply after measuring it.
        if (usingWindow) {
            mapWindow.layout(panelX, panelY, dialogW, dialogH);
            mapWindow.setAlpha(1 - transparency / 100);
            // The panel covers only the window body, so the native header stays visible.
            position(panel, panelX + MapWindow.INSET, panelY + MapWindow.HEADER);
        } else position(panel, panelX, panelY);
        raiseExpanded(screenWidth, screenHeight);
        // A rotating square needs enough tiles/markers to cover its diagonal.
        var halfW = size / (2 * scale);
        var halfH = mapHeight / (2 * scale);
        var radius = expanded || mapHeight != size
            ? Math.sqrt(halfW * halfW + halfH * halfH)
            : size / (2 * scale) * (config.rotateMap && !circular ? Math.sqrt(2) : 1);
        selectTiles(viewCenterX, viewCenterY, radius);
        loadNextTile();
        rifts.update(G.field(hero, "layer"), haxe.Timer.stamp());
        markers.update(hero, config, viewCenterX, viewCenterY, radius, scale, rotation, rifts);
        markers.updateAlerts(config, viewCenterX, viewCenterY, size, scale, rotation, rifts, circular, mapHeight);
        compass.update(size, circular, rotation, markerScale / 100, config.showNorthIndicator, mapHeight);
        updateClockTimer(config);
        show(true);
        var toggleLabel = "";
        if (controls != null) {
            if (expanded) {
                controls.show(true);
                controls.layoutDock(contentX + size + 10, contentY, mapHeight);
                var dockX = usingWindow ? panelX + MapWindow.INSET : panelX;
                var dockY = usingWindow ? panelY + MapWindow.HEADER : panelY;
                controls.place(dockX, dockY, screenWidth, screenHeight);
                controls.sync(config);
                raiseExpanded(screenWidth, screenHeight);
                toggleLabel = controls.caption();
            } else if (config.showCategoryButtons) {
                controls.show(true);
                controls.sync(config);
                controls.place(panelX, panelY, screenWidth, screenHeight);
                toggleLabel = controls.caption();
            } else {
                controls.show(false);
            }
        }
        if (toggleLabel != "") setHoverCaption(toggleLabel);
        else updateHover(hero, viewCenterX, viewCenterY, x, y, rotation);
        placeHoverText();
        // Reparenting the window clears Heaps graphics. Repaint after the last move.
        if (graphicsCleared) {
            graphicsCleared = false;
            paintChrome();
            paintOcean();
            repaintPlayerArrow();
            if (compass != null) compass.repaint();
            if (markers != null) markers.restoreGraphics();
            if (controls != null) controls.redrawIcons();
            scrimWidth = -1;
            paintScrim(screenWidth, screenHeight);
        }
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
        ocean = G.create("h2d.Graphics", [mask]);
        squareFilter = G.create("h2d.filter.Nothing", []);
        circleFilter = G.create("h2d.filter.Mask", [circleMask, false, true]);
        configureFilter(squareFilter, "h2d.filter.Filter");
        configureFilter(circleFilter, "h2d.filter.AbstractMask");
        pivot = G.create("h2d.Object", [mask]);
        terrain = G.create("h2d.Object", [pivot]);
        tileLayer = G.create("h2d.Object", [terrain]);
        // Map markers cover other players. Party members and the local arrow are added last.
        npcPivot = G.create("h2d.Object", [mask]);
        npcTerrain = G.create("h2d.Object", [npcPivot]);
        markers = new MinimapMarkers(terrain, npcTerrain, mask, LEVEL);
        compass = new MinimapCompass(mask);
        partyPivot = G.create("h2d.Object", [mask]);
        partyTerrain = G.create("h2d.Object", [partyPivot]);
        markers.attachPartyLayer(partyTerrain);
        arrow = G.create("h2d.Graphics", [mask]);
        MinimapMarkers.drawPlayerArrow(arrow, 10, 0xfff3d6);
        rifts = new RiftMarkers(LEVEL);
        input = G.create("h2d.Interactive", [1.0, 1.0, panel, null]);
        position(input, BORDER, BORDER);
        G.call("h2d.Interactive", "set_cursor", input, [G.current("hxd.Cursor", "Default")]);
        G.set(input, "propagateEvents", true);
        G.set(input, "enableRightButton", true);
        G.set(input, "onClick", (event:Dynamic) -> onMapClick(event));
        G.set(input, "onPush", (event:Dynamic) -> onMapPush(event));
        G.set(input, "onRelease", (_:Dynamic) -> dragging = false);
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
        controls = new MinimapControls();
        controls.bindFont(() -> findFont(G.field(owner, "gameRoot"), 6));
        controls.bindIcons((graphics, id) -> markers.drawCategory(graphics, id));
        attachAbsolute(controls.root);
    }

    function attachAbsolute(object:Dynamic):Void {
        var layer = G.integer(G.call("h2d.Object", "getChildIndex", root, [G.field(owner, "gameRoot")]));
        G.call("h2d.Flow", "addChildAt", root, [object, layer]);
        absolute(object);
    }

    function raiseExpanded(screenWidth:Float, screenHeight:Float):Void {
        if (panel == null || root == null) return;
        if (!expanded) {
            if (shield != null) {
                G.call("h2d.Object", "set_visible", shield, [false]);
                G.set(shield, "width", 0);
                G.set(shield, "height", 0);
            }
            if (stacked) {
                placeWithHud(panel);
                if (controls != null) placeWithHud(controls.root);
                if (markers != null) markers.invalidatePin();
                stacked = false;
            }
            if (mapWindow != null) mapWindow.show(false);
            G.set(input, "propagateEvents", true);
            return;
        }
        if (shield == null) {
            shield = G.create("h2d.Interactive", [1.0, 1.0, null, null]);
            scrim = G.create("h2d.Graphics", [shield]);
            G.set(shield, "propagateEvents", false);
            G.set(shield, "onPush", (event:Dynamic) -> G.set(event, "propagate", false));
            G.set(shield, "onClick", (event:Dynamic) -> G.set(event, "propagate", false));
            G.set(shield, "onWheel", (event:Dynamic) -> G.set(event, "propagate", false));
        }
        G.call("h2d.Object", "set_visible", shield, [true]);
        G.set(shield, "width", screenWidth);
        G.set(shield, "height", screenHeight);
        position(shield, 0, 0);
        paintScrim(screenWidth, screenHeight);
        var controlsRoot = controls != null && controls.root != null && G.field(controls.root, "visible") == true ? controls.root : null;
        var window = usingWindow && mapWindow != null ? mapWindow.window : null;
        var order:Array<Dynamic> = [shield];
        if (window != null) order.push(window);
        order.push(panel);
        if (controlsRoot != null) order.push(controlsRoot);
        var count = G.integer(G.call("h2d.Object", "get_numChildren", root));
        var start = count - order.length;
        var aligned = start >= 0;
        if (aligned) for (i in 0...order.length) if (childIndex(order[i]) != start + i) aligned = false;
        if (!aligned) {
            for (object in order) toFront(object);
            if (markers != null) markers.invalidatePin();
        }
        stacked = true;
        G.set(input, "propagateEvents", false);
    }

    function paintScrim(screenWidth:Float, screenHeight:Float):Void {
        if (scrim == null || (scrimWidth == screenWidth && scrimHeight == screenHeight)) return;
        scrimWidth = screenWidth;
        scrimHeight = screenHeight;
        G.call("h2d.Graphics", "clear", scrim);
        G.call("h2d.Graphics", "beginFill", scrim, [0x02060f, 0.62]);
        G.call("h2d.Graphics", "drawRect", scrim, [0.0, 0.0, screenWidth, screenHeight]);
        G.call("h2d.Graphics", "endFill", scrim);
    }

    function toFront(object:Dynamic):Void {
        if (object == null || root == null) return;
        var count = G.integer(G.call("h2d.Object", "get_numChildren", root));
        moveChild(object, count);
    }

    function placeWithHud(object:Dynamic):Void {
        var layer = childIndex(G.field(owner, "gameRoot"));
        if (layer < 0) layer = 0;
        moveChild(object, layer);
    }

    /** Move without Object.remove. remove() erases every Graphics shape under the window. */
    function moveChild(object:Dynamic, index:Int):Void {
        G.call("h2d.Flow", "addChildAt", root, [object, index]);
        absolute(object);
        graphicsCleared = true;
    }

    function absolute(object:Dynamic):Void {
        var properties = G.call("h2d.Flow", "getProperties", root, [object]);
        G.call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
        G.set(properties, "horizontalAlign", null);
        G.set(properties, "verticalAlign", null);
        G.set(properties, "offsetX", 0);
        G.set(properties, "offsetY", 0);
    }

    function childIndex(object:Dynamic):Int {
        if (object == null || root == null) return -1;
        try return G.integer(G.call("h2d.Object", "getChildIndex", root, [object])) catch (_:Dynamic) return -1;
    }

    /** Escape and leaving the overworld use this. The expand hotkey still toggles. */
    public function dismissExpanded():Bool {
        if (!expanded) return false;
        closeExpanded();
        return true;
    }

    public function toggleExpanded(app:Dynamic):Void {
        if (panel == null || G.field(panel, "visible") != true) return;
        expanded = !expanded;
        panX = 0;
        panY = 0;
        dragging = false;
        dragMoved = false;
        bounds = "";
        // Resizing the window can deliver a leftover click on the pin.
        ignoreClicksUntil = haxe.Timer.stamp() + 0.3;
        if (markers != null) markers.invalidatePin();
        if (expanded) CursorMode.engage(app) else CursorMode.restore();
    }

    function closeExpanded():Void {
        if (!expanded && panX == 0 && panY == 0) {
            CursorMode.restore();
            return;
        }
        expanded = false;
        panX = 0;
        panY = 0;
        dragging = false;
        dragMoved = false;
        ignoreClicksUntil = haxe.Timer.stamp() + 0.3;
        if (markers != null) markers.invalidatePin();
        CursorMode.restore();
    }

    function onMapPush(event:Dynamic):Void {
        trackMouse(event);
        dragMoved = false;
        if (!expanded || G.integer(G.field(event, "button")) != 0) return;
        dragging = true;
        dragX = mouseX;
        dragY = mouseY;
    }

    function onMapClick(event:Dynamic):Void {
        if (markers == null || haxe.Timer.stamp() < ignoreClicksUntil) return;
        var rawX = G.field(event, "relX");
        var rawY = G.field(event, "relY");
        var x = rawX == null ? mouseX : G.number(rawX);
        var y = rawY == null ? mouseY : G.number(rawY);
        if (x < 0 || y < 0 || x > size || y > mapHeight) return;
        var button = G.integer(G.field(event, "button"));
        if (button != 0 || controls != null && controls.caption() != "") return;
        var now = haxe.Timer.stamp();
        var second = PinPlacement.doubleClick(lastClick, x, y, now);
        if (dragMoved && !second) {
            dragMoved = false;
            G.set(event, "propagate", false);
            return;
        }
        dragMoved = false;
        lastClick = second ? null : {x: x, y: y, time: now};
    }

    function trackMouse(event:Dynamic):Void {
        // Interactive supplies local coordinates, including the game's UI scale.
        mouseX = G.number(G.field(event, "relX"));
        mouseY = G.number(G.field(event, "relY"));
        var dx = mouseX - size / 2, dy = mouseY - mapHeight / 2;
        hovered = mouseX >= 0 && mouseY >= 0 && mouseX <= size && mouseY <= mapHeight
            && (!circular || dx * dx + dy * dy <= size * size / 4);
        if (!dragging || !expanded) return;
        var movedX = mouseX - dragX;
        var movedY = mouseY - dragY;
        if (movedX * movedX + movedY * movedY <= PinPlacement.SLOP * PinPlacement.SLOP) return;
        dragMoved = true;
        var next = PinPlacement.drag(panX, panY, movedX, movedY, mapRotation, mapScale);
        panX = next.x;
        panY = next.y;
        dragX = mouseX;
        dragY = mouseY;
    }

    function updateHover(hero:Dynamic, centerX:Float, centerY:Float, heroX:Float, heroY:Float, rotation:Float):Void {
        if (!hovered || G.call("h2d.Interactive", "isOver", input) != true) {
            setHoverCaption("");
            return;
        }
        var dx = mouseX - size / 2, dy = mouseY - mapHeight / 2;
        var c = Math.cos(rotation), s = Math.sin(rotation);
        // Undo the displayed map rotation and zoom before picking a marker.
        var px = centerX + (dx * c + dy * s) / scale;
        var py = centerY + (dy * c - dx * s) / scale;
        var target = markers.alertHoverAt(mouseX, mouseY);
        if (target == null) target = markers.hoverAt(px, py, scale, heroX, heroY, hero);
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
            {x: heroX, y: heroY, z: G.number(G.field(hero, "posz"), Math.NaN)});
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
        applyDialogInk();
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
        var footer = expanded ? contentY + mapHeight + 8 : BORDER + mapHeight + 4;
        var bottom = placeHoverLine(hoverText, hoverShadow, hoverFontScale, footer);
        hoverMeasurements.place(contentX + size / 2, bottom + 2, size - 12);
    }

    function placeHoverLine(text:Dynamic, shadow:Dynamic, desiredScale:Float, y:Float):Float {
        var width = G.number(G.call("h2d.Text", "get_textWidth", text));
        // Fit lines independently: a long name must not shrink the measurements.
        var textScale = Math.min(desiredScale, (size - 12) / Math.max(1, width));
        for (object in [shadow, text]) G.call("h2d.Object", "setScale", object, [textScale]);
        var x = contentX + (size - width * textScale) / 2;
        position(shadow, x + 1, y + 1);
        position(text, x, y);
        return y + G.number(G.call("h2d.Text", "get_textHeight", text)) * textScale;
    }

    function updateClockTimer(config:MinimapSettings):Void {
        var caption = ClockTimer.caption(config.clockTimerMode, rifts.remaining);
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
        // Both the clock and countdown use the same native Rift alert state.
        var color = config.riftAlerts && rifts.alertActive() ? LandmarkIcons.RIFT_ALERT_COLOR : (expanded ? INK : 0xfff3d6);
        if (color != riftColor) {
            riftColor = color;
            G.call("h2d.Text", "set_textColor", riftText, [color]);
        }
        if (caption == "") return;
        var x:Float;
        var y:Float;
        if (usingWindow) {
            // Right side of the native header, which sits above this panel.
            x = dialogW - 32 - MapWindow.INSET - riftWidth;
            y = (MapWindow.HEADER - riftHeight) / 2 - MapWindow.HEADER;
        } else if (expanded) {
            x = contentX + (size - riftWidth) / 2;
            var top = 8.0;
            var bottom = contentY - 4;
            y = top + Math.max(0, (bottom - top - riftHeight) / 2);
        } else {
            x = Math.round(contentX + (size - riftWidth) / 2);
            y = Math.ceil(Math.max(2 - panelY, -riftHeight - 7));
        }
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

    function layout(value:Int, height:Int, round:Bool):Void {
        size = value;
        mapHeight = height;
        circular = round;
        bounds = "";
        contentX = expanded ? DIALOG_PAD : BORDER;
        contentY = expanded ? (usingWindow ? DIALOG_PAD : DIALOG_PAD + DIALOG_HEADER) : BORDER;
        G.set(mask, "width", size);
        G.set(mask, "height", mapHeight);
        G.set(input, "width", size * 1.0);
        G.set(input, "height", mapHeight * 1.0);
        G.set(input, "isEllipse", round);
        position(circleMask, contentX, contentY);
        position(mask, contentX, contentY);
        position(input, contentX, contentY);
        hovered = false;
        setHoverCaption("");
        position(arrow, size / 2, mapHeight / 2);
        position(pivot, size / 2, mapHeight / 2);
        position(npcPivot, size / 2, mapHeight / 2);
        position(partyPivot, size / 2, mapHeight / 2);
        G.call("h2d.Object", "set_filter", mask, [round ? circleFilter : squareFilter]);
        G.call("h2d.Object", "set_visible", circleMask, [round]);
        if (controls != null && !expanded) controls.layout(size, circular);
        paintChrome();
        paintOcean();
        applyDialogInk();
    }

    function applyDialogInk():Void {
        var text = expanded ? HOVER_INK : 0xfff3d6;
        var shade = expanded ? 0x120C08 : 0x171b24;
        if (hoverText != null) {
            G.call("h2d.Text", "set_textColor", hoverText, [text]);
            G.call("h2d.Text", "set_textColor", hoverShadow, [shade]);
        }
        if (hoverMeasurements != null) hoverMeasurements.setInk(text, shade);
    }

    function paintChrome():Void {
        if (frame == null) return;
        G.call("h2d.Graphics", "clear", frame);
        G.call("h2d.Graphics", "clear", circleMask);
        if (circular) {
            circle(frame, size / 2 + BORDER, size / 2 + BORDER, size / 2 + BORDER, 0xb39888);
            circle(frame, size / 2 + BORDER, size / 2 + BORDER, size / 2, 0x17202b);
            circle(circleMask, size / 2, size / 2, size / 2, 0xffffff);
        } else if (expanded && usingWindow) {
            rectangle(contentX - 4, contentY - 4, size + 8, mapHeight + 8, PARCHMENT_EDGE);
            rectangle(contentX - 2, contentY - 2, size + 4, mapHeight + 4, PARCHMENT_LINE);
        } else if (expanded) {
            var w = dialogW > 0 ? dialogW : size + DIALOG_PAD * 2;
            var h = dialogH > 0 ? dialogH : mapHeight + DIALOG_PAD * 2 + DIALOG_FOOTER;
            rectangle(0, 0, w, h, PARCHMENT_EDGE);
            rectangle(5, 5, w - 10, h - 10, PARCHMENT);
            rectangle(contentX - 4, contentY - 4, size + 8, mapHeight + 8, PARCHMENT_EDGE);
            rectangle(contentX - 2, contentY - 2, size + 4, mapHeight + 4, PARCHMENT_LINE);
        } else {
            rectangle(0, 0, size + BORDER * 2, mapHeight + BORDER * 2, 0xb39888);
            rectangle(BORDER, BORDER, size, mapHeight, 0x17202b);
        }
    }

    function repaintPlayerArrow():Void {
        if (arrow == null) return;
        G.call("h2d.Graphics", "clear", arrow);
        MinimapMarkers.drawPlayerArrow(arrow, 10, 0xfff3d6);
    }

    function paintOcean():Void {
        if (ocean == null) return;
        G.call("h2d.Graphics", "clear", ocean);
        if (!expanded) return;
        G.call("h2d.Graphics", "beginFill", ocean, [WATER, 1.0]);
        G.call("h2d.Graphics", "drawRect", ocean, [0.0, 0.0, size * 1.0, mapHeight * 1.0]);
        G.call("h2d.Graphics", "endFill", ocean);
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
        // The HUD stays on a small budget. The expanded map should fill on open,
        // including tiles that were already decoded for the minimap.
        var finishBudget = expanded ? 32 : 1;
        var attachBudget = expanded ? 48 : 1;
        var startBudget = expanded ? 8 : 1;
        var inFlight = expanded ? 16 : 2;
        var finished = 0;
        var index = 0;
        while (index < pending.length && finished < finishBudget) {
            var entry = pending[index];
            var tile = entry.loading == null ? null : entry.loading.take();
            if (tile == null) { index++; continue; }
            entry.tile = tile; entry.loading = null;
            cached.push(entry);
            pending.remove(entry);
            finished++;
        }
        if (finished > 0) trimCache();
        var started = 0;
        var attached = 0;
        for (entry in wanted) {
            var key = tileKey(entry.x, entry.y);
            if (sprites.exists(key)) continue;
            if (entry.tile == null) {
                if (entry.loading == null && pending.length < inFlight && started < startBudget) {
                    requestTile(entry);
                    started++;
                }
                continue;
            }
            if (attached >= attachBudget) continue;
            var bitmap = G.create("h2d.Bitmap", [entry.tile, tileLayer]);
            G.call("h2d.Bitmap", "set_width", bitmap, [tileWorldWidth]);
            G.call("h2d.Bitmap", "set_height", bitmap, [tileWorldWidth]);
            position(bitmap, entry.x * tileWorldWidth, entry.y * tileWorldWidth);
            sprites[key] = bitmap;
            attached++;
        }
        if (attached > 0) trimCache();
        if (started > 0 || pending.length >= inFlight) return;
        for (entry in prefetch) if (entry.tile == null && entry.loading == null) {
            requestTile(entry);
            return;
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
        if (mapWindow != null) mapWindow.show(visible && usingWindow);
        if (!visible && controls != null) controls.show(false);
        if (!visible) { hovered = false; setHoverCaption(""); }
    }

    public function dispose():Void {
        closeExpanded();
        // The hidden font source belongs to gameRoot's DOM, outside our panel.
        if (riftFontSource != null) G.call("h2d.Object", "remove", riftFontSource);
        if (controls != null) {
            controls.dispose();
            controls = null;
        }
        if (shield != null) {
            try G.call("h2d.Object", "remove", shield) catch (_:Dynamic) {}
            shield = null;
        }
        if (mapWindow != null) {
            mapWindow.dispose();
            mapWindow = null;
        }
        if (panel != null) {
            var old = panel;
            panel = null;
            G.call("h2d.Object", "remove", old);
        }
        owner = null; world = null; root = null; loader = null;
        frame = null; ocean = null; mask = null; circleMask = null; squareFilter = null; circleFilter = null;
        pivot = null; terrain = null; tileLayer = null; arrow = null; markers = null; compass = null;
        rifts = null; riftText = null; riftShadow = null; riftCaption = ""; riftColor = -1;
        riftFontSource = null; riftFont = null;
        riftX = Math.NaN; riftY = Math.NaN;
        npcPivot = null; npcTerrain = null;
        partyPivot = null; partyTerrain = null;
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
