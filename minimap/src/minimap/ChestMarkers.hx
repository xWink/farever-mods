package minimap;

import minimap.GameAccess as G;

private typedef WorldChest = {
    var id:String;
    var point:MapPoint;
    var states:Map<String, Int>;
    var resetTimer:Int;
    var personal:Bool;
    var heroic:Dynamic;
}

/** Match the native map's chest families, including inherited world variants. */
class ChestMarkers {
    var kinds:Map<String, String> = [];

    var world:Map<String, WorldChest> = [];

    public function new() {}

    public function clearWorld():Void world = [];

    public function addDefinition(definition:Dynamic):Void {
        var inf = G.field(definition, "inf");
        if (!available(inf)) return;
        var prefab = G.field(definition, "prefab");
        if (prefab == null) return;
        // Activity rewards depend on live encounter/script state. A prefab
        // alone must not advertise them before the activity has spawned them.
        var parent = G.field(prefab, "parent");
        while (parent != null) {
            if (G.text(G.call("hrt.prefab.Prefab", "getCdbType", parent)) == "activity") return;
            parent = G.field(parent, "parent");
        }
        var matrix = G.call("hrt.prefab.Object3D", "getAbsPos", prefab, [true]);
        if (matrix == null) return;
        add(inf, G.number(G.field(matrix, "_41"), Math.NaN), G.number(G.field(matrix, "_42"), Math.NaN),
            G.number(G.field(matrix, "_43"), Math.NaN));
    }

    public function observe(element:Dynamic):Void {
        var inf = G.field(element, "inf"), id = G.text(G.field(inf, "id"));
        if (world.exists(id) || !available(inf)) return;
        // Native HElement clears a prefab after spawning it. Retain positions
        // of those already-loaded world chests before they leave streaming range.
        if (G.call("st.State", "getActivity", element) != null) return;
        add(inf, G.number(G.field(element, "posx"), Math.NaN), G.number(G.field(element, "posy"), Math.NaN),
            G.number(G.field(element, "posz"), Math.NaN));
    }

    static function available(inf:Dynamic):Bool {
        // Native Element.create constructs Chest only for Data.Element_type.Chest (2).
        return inf != null && G.integer(G.field(inf, "type"), -1) == 2
            && NpcMarkers.availableDefinition(inf);
    }

    function add(inf:Dynamic, x:Float, y:Float, z:Float):Void {
        var id = G.text(G.field(inf, "id"));
        if (id == "" || !Math.isFinite(x) || !Math.isFinite(y)) return;
        var props = G.field(inf, "props"), states:Map<String, Int> = [];
        for (state in G.array(G.field(inf, "states")))
            states[G.text(G.field(state, "state"))] = G.integer(G.field(state, "flags"));
        world[id] = {id:id, point:{kind:kind(inf), inf:inf, x:x, y:y, z:z}, states:states,
            resetTimer:G.integer(G.field(props, "resetTimer")),
            personal:(G.integer(G.field(props, "flags")) & 2) != 0, heroic:G.field(props, "heroic")};
    }

    public function append(points:Array<MapPoint>, live:Map<String, Bool>, player:Dynamic, layer:Dynamic,
        x:Float, y:Float, radius:Float, events:WorldEventAccess):Void {
        var progress = G.field(player, "progress");
        if (progress == null) return;
        var now = Math.NaN, timeRead = false;
        var personalStates = G.field(G.field(player, "playerContext"), "elements");
        var heroic = G.integer(G.field(G.field(layer, "config"), "difficulty")) == 2;
        for (chest in world) {
            var point = chest.point, dx = point.x - x, dy = point.y - y;
            if (live.exists(chest.id) || dx * dx + dy * dy > radius * radius) continue;
            if (chest.heroic != null && chest.heroic != heroic) continue;
            if (!NpcMarkers.eventVisible(point.inf, G.field(layer, "worldEvents"), events)) continue;
            var state = chest.personal && personalStates != null
                ? G.text(G.call("haxe.ds.StringMap", "get", personalStates, [chest.id])) : "";
            var flags = 0;
            if (state == "") {
                // Mirror Element.getPlayerState's read-only completion test:
                // resetTimer None/0 is permanent; other timers reset after 7h.
                var saved = G.call("st.player.Progress", "getElementState", progress, [chest.id, null]);
                var completed = G.number(G.field(saved, "completed"), -1);
                if (completed > 0) {
                    if (chest.resetTimer != 0 && !timeRead) {
                        now = G.number(G.field(G.call("st.GameLayer", "get_time", layer), "serverNow"), Math.NaN);
                        timeRead = true;
                    }
                    if (chest.resetTimer == 0 || !Math.isFinite(now) || now - completed < 25200) continue;
                }
                state = "None"; // Element's native initial state.
            }
            if (chest.states.exists(state)) flags = chest.states[state];
            if ((flags & 0x29) == 0) points.push(point);
        }
    }

    public function kind(inf:Dynamic):String {
        if (inf == null) return "chest";
        var id = G.text(G.field(inf, "id"));
        if (id != "" && kinds.exists(id)) return kinds[id];
        var kind = if (G.staticCall("HElement", "isOfType", [inf, "Recipe_Chest_Root"]) == true) "recipeChest"
            else if (G.staticCall("HElement", "isOfType", [inf, "VaultChest"]) == true) "vaultChest"
            else "chest";
        if (id != "") kinds[id] = kind;
        return kind;
    }
}
