package minimap;

import minimap.GameAccess as G;

private typedef NativeMarker = {
    marker:Dynamic, alpha:Float, visible:Bool, point:Null<MapPoint>
};

/** Keep the game's existing click/tooltip targets under the replacement artwork. */
class BigMapNativeMarkers {
    var originals:haxe.ds.ObjectMap<Dynamic, NativeMarker> = new haxe.ds.ObjectMap();

    var corrections:Array<NativeMarker> = [];
    var dirty:Bool = true;
    public function new() {}
    public function invalidate():Void dirty = true;

    public function sample(window:Dynamic, points:Array<MapPoint>, hero:Dynamic):Void {
        var byId:Map<String, MapPoint> = [];
        var byEntity:haxe.ds.ObjectMap<Dynamic, MapPoint> = new haxe.ds.ObjectMap();
        var respawns:haxe.ds.ObjectMap<Dynamic, MapPoint> = new haxe.ds.ObjectMap();
        for (point in points) {
            var inf = point.inf != null ? point.inf : G.field(point.entity, "inf");
            var id = G.text(G.field(inf, "id"));
            if (id != "") byId[id] = point;
            if (point.entity != null) byEntity.set(point.entity, point);
            if (point.kind == "respawn" && id != "") {
                var marker = G.call("haxe.ds.StringMap", "get", G.field(window, "respawnPoints"), [id]);
                if (marker != null) respawns.set(marker, point);
            }
        }
        byEntity.set(hero, {kind: "player", entity: hero,
            x: G.number(G.field(hero, "posx")), y: G.number(G.field(hero, "posy")),
            z: G.number(G.field(hero, "posz"), Math.NaN)});

        var current:haxe.ds.ObjectMap<Dynamic, NativeMarker> = new haxe.ds.ObjectMap();
        for (marker in G.array(G.field(window, "markers"))) {
            if (G.field(marker, "removed") == true || G.field(marker, "parent") != G.field(window, "scroll")) continue;
            var layer = G.integer(G.call("h2d.Layers", "getChildLayer", G.field(window, "scroll"), [marker]));
            var point:MapPoint = null;
            var activity = G.field(marker, "activity"), element = G.field(marker, "element"), player = G.field(marker, "hero");
            // These are MapWindow's dedicated activity, respawn, obelisk and
            // player layers. Pins, zone labels, death markers and routes stay native.
            if (layer == 13 && activity != null)
                point = byId[G.text(G.staticCall("HMapActivity", "getKind", [activity]))];
            else if (layer == 14) point = respawns.get(marker);
            else if (layer == 15 && element != null) point = byId[G.text(G.field(element, "id"))];
            else if (layer == 20 && player != null) point = byEntity.get(player);
            else continue;
            var record = originals.get(marker);
            if (record == null) record = {marker: marker, alpha: G.number(G.field(marker, "alpha"), 1),
                visible: G.field(marker, "visible") == true, point: null};
            record.point = point;
            current.set(marker, record);
        }
        for (marker => record in originals) if (!current.exists(marker)) restore(record);
        originals = current;
        corrections = [];
        for (record in originals) {
            var point = record.point;
            if (point == null) continue;
            var position = G.field(record.marker, "worldPos");
            // Native offscreen cursors can be clamped to the viewport edge.
            // Keep those and relocated targets aligned with our world artwork.
            if (point.kind == "player" || G.field(position, "x") != point.x || G.field(position, "y") != point.y
                || G.call("ui.win.map.MapMarker", "get_showOffscreen", record.marker) == true)
                corrections.push(record);
        }
        dirty = true;
    }

    public function apply(window:Dynamic, tileScale:Float, hero:Dynamic):Void {
        if (dirty) {
            dirty = false;
            for (record in originals) {
                var marker = record.marker, point = record.point;
                if (G.field(marker, "removed") == true) continue;
                // Preserve the native action; invisible filtered markers cannot be clicked.
                if (G.field(marker, "alpha") != 0.) G.set(marker, "alpha", 0.);
                if (G.field(marker, "visible") != (point != null))
                    G.call("ui.UIElement", "set_visible", marker, [point != null]);
                if (point == null && G.field(window, "nearClickableMarker") == marker) {
                    G.call("ui.UIElement", "hideTip", G.field(marker, "content"));
                    G.set(window, "nearClickableMarker", null);
                }
            }
        }
        for (record in corrections) {
            var marker = record.marker, point = record.point;
            if (G.field(marker, "removed") == true) continue;
            var own = point.entity == hero;
            var x = (own ? G.number(G.field(hero, "posx")) : point.x) * tileScale;
            var y = (own ? G.number(G.field(hero, "posy")) : point.y) * tileScale;
            if (G.field(marker, "x") != x || G.field(marker, "y") != y)
                G.call("h2d.Object", "setPosition", marker, [x, y]);
        }
    }

    function restore(record:NativeMarker):Void {
        if (G.field(record.marker, "removed") == true) return;
        G.set(record.marker, "alpha", record.alpha);
        G.call("ui.UIElement", "set_visible", record.marker, [record.visible]);
    }

    public function dispose():Void {
        for (record in originals) restore(record);
        originals = new haxe.ds.ObjectMap();
        corrections = []; dirty = true;
    }
}
