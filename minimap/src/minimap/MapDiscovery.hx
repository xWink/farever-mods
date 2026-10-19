package minimap;

import minimap.GameAccess as G;

/** Region visibility follows character obelisk completion, not mere discovery. */
class MapDiscovery {
    var hero:Dynamic;
    var progress:Dynamic;
    var world:Dynamic;
    var visible:Map<String, Bool> = [];
    var regions:Map<String, Dynamic> = [];
    var bakedRegions:Map<String, Dynamic> = [];
    var position:Dynamic;
    var regionCount:Int = 0;
    public var window:Dynamic;

    public function new() {}

    public function sample(nextHero:Dynamic):Void {
        var nextWorld = G.field(G.field(nextHero, "layer"), "world");
        if (hero != nextHero || world != nextWorld) { regions = []; bakedRegions = []; regionCount = 0; }
        hero = nextHero; world = nextWorld;
        progress = G.field(G.field(hero, "player"), "progress");
        // Unlocks can change on the same progress object. Cache only this sample.
        visible = [];
    }

    public function accepts(point:MapPoint):Bool {
        if (progress == null || world == null) return false;
        // Definitions already identify their region. Do not wait for the terrain
        // chunk at a distant marker to stream in just to check its obelisk.
        var bakedId = point.zoneBaked;
        if (bakedId == null) {
            var inf = point.inf != null ? point.inf : G.field(point.entity, "inf");
            bakedId = G.text(G.field(inf, "zoneBaked"));
            if (bakedId == "") bakedId = G.text(G.field(G.field(G.field(point.entity, "spawner"), "inf"), "zoneBaked"));
        }
        if (bakedId != "") {
            var baked = bakedRegions[bakedId];
            if (baked == null) {
                baked = G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "zone"), "byId"), [bakedId]);
                if (baked != null) bakedRegions[bakedId] = baked;
            }
            if (baked != null) return regionVisible(baked);
        }
        var key = point.x + ":" + point.y + ":" + point.z;
        var zone = regions[key];
        if (zone == null) {
            if (window != null) {
                if (position == null) position = G.create("h3d.VectorImpl", [0., 0., 0.]);
                G.set(position, "x", point.x); G.set(position, "y", point.y);
                G.set(position, "z", Math.isFinite(point.z) ? point.z : 1000000.);
                zone = G.call("ui.win.MapWindow", "getLocation", window, [position]);
            } else {
                zone = G.call("world.World", "getZoneType", world,
                    [point.x, point.y, Math.isFinite(point.z) ? point.z : 1000000., 1]);
            }
            if (zone != null && point.entity == null) {
                if (regionCount >= 8192) { regions = []; regionCount = 0; }
                regionCount++;
                regions[key] = zone;
            }
        }
        return regionVisible(zone);
    }

    public function regionVisible(zone:Dynamic):Bool {
        if (zone == null || progress == null) return false;
        var id = G.text(G.field(zone, "id"));
        if (!visible.exists(id)) visible[id] = G.call("st.player.Progress", "hasZoneDiscovered", progress, [zone]) == true;
        return visible[id];
    }

    public function fogVisible(zone:Dynamic):Bool {
        if (zone == null || !regionVisible(zone)) return false;
        // Native cave fog additionally requires exploring the cave itself.
        return G.integer(G.field(zone, "type")) != 2
            || G.call("st.player.Progress", "hasZoneExplored", progress, [G.text(G.field(zone, "id"))]) == true;
    }

    public static function travelUnlocked(point:MapPoint, hero:Dynamic):Bool
        return point.kind == "obelisk" && RespawnMarkers.unlocked(
            point.inf != null ? point.inf : G.field(point.entity, "inf"), G.field(G.field(hero, "player"), "progress"));
}
