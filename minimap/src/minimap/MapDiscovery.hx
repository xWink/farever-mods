package minimap;

import minimap.GameAccess as G;

/** Region visibility follows character obelisk completion, not mere discovery. */
class MapDiscovery {
    var hero:Dynamic;
    var progress:Dynamic;
    var world:Dynamic;
    var visible:Map<String, Bool> = [];
    var regions:Map<String, Dynamic> = [];
    var position:Dynamic;
    var regionCount:Int = 0;
    public var window:Dynamic;

    public function new() {}

    public function sample(nextHero:Dynamic):Void {
        var nextWorld = G.field(G.field(nextHero, "layer"), "world");
        if (hero != nextHero || world != nextWorld) { regions = []; regionCount = 0; }
        hero = nextHero; world = nextWorld;
        progress = G.field(G.field(hero, "player"), "progress");
        // Unlocks can change on the same progress object. Cache only this sample.
        visible = [];
    }

    public function accepts(point:MapPoint):Bool {
        if (progress == null || world == null) return false;
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
