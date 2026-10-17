package minimap;

import minimap.GameAccess as G;

private typedef NativeMarker = {
    marker:Dynamic, artwork:Dynamic, alpha:Float, visible:Bool, point:Null<MapPoint>, tip:Null<NativeMarkerTip>
};
private typedef NativeMarkerTip = {
    content:Dynamic, getTip:Dynamic, showTipOnOver:Bool
};

/** Keep native click targets, with selected tooltips replaced by our hover text. */
class BigMapNativeMarkers {
    var originals:haxe.ds.ObjectMap<Dynamic, NativeMarker> = new haxe.ds.ObjectMap();

    var corrections:Array<NativeMarker> = [];
    var dirty:Bool = true;
    public function new() {}
    public function invalidate():Void dirty = true;

    public function sample(window:Dynamic, points:Array<MapPoint>, hero:Dynamic, fastTravel:Bool = false):Void {
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
            else if (fastTravel && (layer == 16 || layer == 22)) point = null; // Pins and death markers.
            else continue;
            // The native camera cone is a sibling of the player's content icon.
            // Keep its parent visible so native camera rotation/zoom still apply.
            var content = G.field(marker, "content");
            var artwork = player == hero && G.field(marker, "camera") != null && content != null ? content : marker;
            var record = originals.get(marker);
            if (record == null) record = {marker: marker, artwork: artwork, alpha: G.number(G.field(artwork, "alpha"), 1),
                visible: G.field(marker, "visible") == true, point: null, tip: null};
            else if (record.artwork != artwork) {
                G.set(record.artwork, "alpha", record.alpha);
                record.artwork = artwork;
                record.alpha = G.number(G.field(artwork, "alpha"), 1);
            }
            record.point = point;
            current.set(marker, record);
            // The native providers live on content, not on the marker itself.
            // Keep the interactive and click callbacks intact for obelisk travel.
            suppressTip(record, layer == 15 || (layer == 20 && player == hero));
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
                if (G.field(record.artwork, "alpha") != 0.) G.set(record.artwork, "alpha", 0.);
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

    function suppressTip(record:NativeMarker, suppress:Bool):Void {
        var content = G.field(record.marker, "content");
        if (record.tip != null && (!suppress || record.tip.content != content)) restoreTip(record);
        if (!suppress || content == null) return;
        var provider = G.field(content, "getTip");
        var onOver = G.field(content, "showTipOnOver") == true;
        var changed = record.tip == null || provider != null || onOver;
        if (record.tip == null) record.tip = {content:content, getTip:provider, showTipOnOver:onOver};
        else if (provider != null) record.tip.getTip = provider;
        if (provider != null) G.set(content, "getTip", null);
        if (onOver) G.set(content, "showTipOnOver", false);
        if (changed) G.call("ui.UIElement", "hideTip", content);
    }

    function restoreTip(record:NativeMarker):Void {
        var tip = record.tip;
        if (tip == null) return;
        if (G.field(tip.content, "removed") != true) {
            G.set(tip.content, "getTip", tip.getTip);
            G.set(tip.content, "showTipOnOver", tip.showTipOnOver);
        }
        record.tip = null;
    }

    function restore(record:NativeMarker):Void {
        restoreTip(record);
        if (G.field(record.marker, "removed") == true) return;
        G.set(record.artwork, "alpha", record.alpha);
        G.call("ui.UIElement", "set_visible", record.marker, [record.visible]);
    }

    public function dispose():Void {
        for (record in originals) restore(record);
        originals = new haxe.ds.ObjectMap();
        corrections = []; dirty = true;
    }
}
