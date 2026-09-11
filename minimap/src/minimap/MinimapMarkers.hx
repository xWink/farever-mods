package minimap;

import minimap.GameAccess as G;
import minimap.MinimapMod.MinimapSettings;

private typedef MapPoint = {var x:Float; var y:Float; var kind:String;}

/** Read-only map markers. Live entities are sampled five times a second. */
class MinimapMarkers {
    var graphics:Dynamic;
    var level:String;
    var layer:Dynamic;
    var lastHero:Dynamic;
    var previousConfig:MinimapSettings;
    var nextRefresh:Float = 0;
    var previousScale:Float = 0;
    var previousRadius:Float = 0;
    var classes:Map<String, String> = [];
    var gatherKinds:Map<String, String> = [];
    var codexGoals:Map<String, Int> = [];
    var landmarks:Map<String, MapPoint> = [];
    var landmarkSources:Map<String, Dynamic> = [];
    var landmarkCounts:Map<String, Int> = [];
    static var reportedError:Bool = false;

    public function new(parent:Dynamic, level:String) {
        this.level = level;
        graphics = G.create("h2d.Graphics", [parent]);
    }

    public function update(hero:Dynamic, config:MinimapSettings, x:Float, y:Float, radius:Float, scale:Float):Void {
        var now = haxe.Timer.stamp();
        var nextLayer = G.field(hero, "layer");
        var changed = previousConfig != config || previousScale != scale || previousRadius != radius
            || lastHero != hero || layer != nextLayer;
        if (!changed && now < nextRefresh) return;
        previousConfig = config; previousScale = scale; previousRadius = radius;
        lastHero = hero; layer = nextLayer;
        nextRefresh = now + 0.2;
        try {
            refreshLandmarks();
            var points = collect(hero, config, x, y, radius + 8 / scale);
            draw(points, scale);
        } catch (error:Dynamic) {
            // An optional marker source must not take down the working map.
            G.call("h2d.Graphics", "clear", graphics);
            nextRefresh = now + 5;
            if (!reportedError) {
                reportedError = true;
                trace("[Minimap] Markers: " + Std.string(error));
            }
        }
    }

    function refreshLandmarks():Void {
        // HElement is also the native MapWindow's landmark source. Rebuild only
        // if those lists change; never traverse level prefabs on every refresh.
        var changed = false;
        for (name in ["obelisks", "respawnPoints", "npcs"]) {
            var source = G.current("HElement", name);
            var count = G.integer(G.field(source, "length"));
            if (landmarkSources[name] != source || landmarkCounts[name] != count) changed = true;
            landmarkSources[name] = source; landmarkCounts[name] = count;
        }
        if (!changed) return;
        landmarks = [];
        for (name in ["obelisks", "respawnPoints", "npcs"]) {
            var kind = name == "obelisks" ? "obelisk" : name == "respawnPoints" ? "respawn" : "npc";
            for (definition in G.array(landmarkSources[name])) {
                if (G.text(G.field(definition, "mapId")) != level) continue;
                var inf = G.field(definition, "inf");
                // Obelisks are also in respawnPoints; draw each location once.
                if (kind == "respawn" && G.integer(G.field(inf, "type")) == 13) continue;
                var prefab = G.field(definition, "prefab");
                if (prefab == null) continue;
                var matrix = G.call("hrt.prefab.Object3D", "getAbsPos", prefab, [true]);
                if (matrix == null) continue;
                var id = G.text(G.field(inf, "id"));
                landmarks[kind + ":" + id] = {kind: kind,
                    x: G.number(G.field(matrix, "_41")), y: G.number(G.field(matrix, "_42"))};
            }
        }
    }

    function collect(hero:Dynamic, config:MinimapSettings, x:Float, y:Float, radius:Float):Array<MapPoint> {
        var points:Array<MapPoint> = [];
        var liveNpcs:Map<String, MapPoint> = [];
        var unitsProgress = G.field(G.field(G.field(G.field(hero, "player"), "progress"), "unitsProgress"), "map");
        var completed:Map<String, Bool> = [];
        if (config.showPlayers || config.showEnemies) for (unit in G.array(G.field(layer, "units"))) {
            if (unit == hero || G.field(unit, "removed") == true) continue;
            var kind = family(unit);
            if (kind != "player" && kind != "enemy") continue;
            if (kind == "player" ? !config.showPlayers : !config.showEnemies) continue;
            var px = G.number(G.field(unit, "posx")), py = G.number(G.field(unit, "posy"));
            if (!near(px, py, x, y, radius)) continue;
            if (G.field(unit, "dying") == true || G.call("ent.GameObject", "isDead", unit) == true) continue;
            if (kind == "enemy") {
                // Player-owned summons are allies, including nested summons.
                var source = unit;
                var summoner = G.field(source, "summonOwner");
                while (summoner != null) { source = summoner; summoner = G.field(source, "summonOwner"); }
                if (family(source) == "player" || G.call("ent.Foe", "isEnemyWith", unit, [hero]) != true) continue;
                var inf = G.field(unit, "inf");
                if (inf == null) continue;
                var id = G.text(G.field(inf, "id"));
                var goal = codexGoal(id, inf);
                if (goal <= 0) {
                    if (!config.showNonCodexEnemies) continue;
                } else {
                    if (!completed.exists(id)) {
                        var progress = unitsProgress == null ? null : G.call("haxe.ds.StringMap", "get", unitsProgress, [id]);
                        completed[id] = G.integer(G.field(progress, "killCount")) >= goal;
                    }
                    if (completed[id] ? !config.showCompletedCodexEnemies : !config.showIncompleteCodexEnemies) continue;
                }
                if ((G.integer(G.field(inf, "flags")) & 0x38) != 0) kind = "boss";
            }
            points.push({kind: kind, x: px, y: py});
        }

        if (config.showPlants || config.showOre || config.showNpcs) for (element in G.array(G.field(layer, "interactibles"))) {
            if (G.field(element, "removed") == true) continue;
            var category = family(element);
            if (category != "gatherable" && category != "npc") continue;
            if (category == "npc" ? !config.showNpcs : (!config.showPlants && !config.showOre)) continue;
            var px = G.number(G.field(element, "posx")), py = G.number(G.field(element, "posy"));
            if (category == "gatherable" && !near(px, py, x, y, radius)) continue;
            var active = G.field(element, "enabled") == true && G.call("ent.Element", "isHidden", element) != true;
            if (category == "npc") {
                var key = "npc:" + G.text(G.field(element, "kind"));
                // Prefer a loaded NPC's actual position (or hidden state) over its prefab.
                liveNpcs[key] = active ? {kind: "npc", x: px, y: py} : null;
            } else if (active) {
                // Gatherable.consume disables the entity until its next respawn.
                // Hit points alone are unsuitable: plants don't need mining hits.
                var kind = gatherKind(G.field(element, "gatherInf"));
                if (kind == "plant" ? config.showPlants : kind == "ore" && config.showOre)
                    points.push({kind: kind, x: px, y: py});
            }
        }

        for (key => point in landmarks) {
            if (point.kind == "npc" && liveNpcs.exists(key)) continue;
            var show = switch point.kind {
                case "npc": config.showNpcs;
                case "obelisk": config.showObelisks;
                default: config.showRespawnPoints;
            };
            if (show && near(point.x, point.y, x, y, radius)) points.push(point);
        }
        for (point in liveNpcs) if (point != null && near(point.x, point.y, x, y, radius)) points.push(point);
        return points;
    }

    function codexGoal(id:String, inf:Dynamic):Int {
        if (codexGoals.exists(id)) return codexGoals[id];
        var goal = 0;
        if (G.staticCall("data.CodexData", "isInCodex", [inf]) == true) {
            var thresholds = G.array(G.staticCall("st.player.Progress", "getUnitProgressThreshold", [inf]));
            var reward = G.integer(G.field(G.current("Const", "Codex"), "FoeXPRewardThresholdIndex")) - 1;
            if (reward >= 0 && reward < thresholds.length) goal = G.integer(thresholds[reward]);
        }
        // Completion means earning the Codex XP reward, not the later ranks.
        codexGoals[id] = goal;
        return goal;
    }

    function gatherKind(inf:Dynamic):String {
        var id = G.text(G.field(inf, "id"));
        if (gatherKinds.exists(id)) return gatherKinds[id];
        var kind = "";
        var current = inf;
        var seen:Map<String, Bool> = [];
        while (current != null) {
            var currentId = G.text(G.field(current, "id"));
            if (seen.exists(currentId)) break;
            seen[currentId] = true;
            var tool = G.text(G.field(current, "requiredTool"));
            if (currentId == "Ore" || tool == "GearPickaxe") { kind = "ore"; break; }
            if (currentId == "Plant" || tool == "GearSickle") { kind = "plant"; break; }
            var parent = G.text(G.field(current, "inherit"));
            if (parent == "") break;
            current = G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "gatherable"), "byId"), [parent]);
        }
        gatherKinds[id] = kind;
        return kind;
    }

    function family(object:Dynamic):String {
        var type = hl.Type.getDynamic(object);
        var name = type.getTypeName();
        if (classes.exists(name)) return classes[name];
        var kind = "";
        while (type != null) {
            kind = switch type.getTypeName() {
                case "ent.Hero": "player";
                case "ent.Foe": "enemy";
                case "ent.interactible.Gatherable": "gatherable";
                case "ent.interactible.Npc": "npc";
                default: "";
            };
            if (kind != "") break;
            type = type.getSuper();
        }
        classes[name] = kind;
        return kind;
    }

    static function near(px:Float, py:Float, x:Float, y:Float, radius:Float):Bool
        return Math.abs(px - x) <= radius && Math.abs(py - y) <= radius;

    function draw(points:Array<MapPoint>, scale:Float):Void {
        G.call("h2d.Graphics", "clear", graphics);
        // Group fills to keep native calls and draw batches small. Markers use
        // world positions, so the map can scroll/rotate smoothly between samples.
        for (kind in ["plant", "ore", "enemy", "boss", "respawn", "obelisk", "npc", "player"]) {
            var group = [for (point in points) if (point.kind == kind) point];
            if (group.length == 0) continue;
            var color = switch kind {
                case "plant": 0x77df81;
                case "ore": 0xf0a658;
                case "enemy", "boss": 0xff6860;
                case "respawn": 0xffffff;
                case "obelisk": 0xc599ff;
                case "npc": 0xffdf78;
                default: 0x70d8ff;
            };
            var radius = (kind == "boss" ? 5.0 : kind == "player" ? 4.0 : 3.5) / scale;
            G.call("h2d.Graphics", "beginFill", graphics, [0x201b1b, 0.95]);
            for (point in group) shape(point, radius + 1 / scale);
            G.call("h2d.Graphics", "endFill", graphics);
            G.call("h2d.Graphics", "beginFill", graphics, [color, 1.0]);
            for (point in group) shape(point, radius);
            G.call("h2d.Graphics", "endFill", graphics);
        }
    }

    function shape(point:MapPoint, r:Float):Void {
        var x = point.x, y = point.y;
        switch point.kind {
            case "respawn":
                G.call("h2d.Graphics", "drawRect", graphics, [x - r / 3, y - r, r * 2 / 3, r * 2]);
                G.call("h2d.Graphics", "drawRect", graphics, [x - r, y - r / 3, r * 2, r * 2 / 3]);
            case "obelisk", "ore":
                G.call("h2d.Graphics", "moveTo", graphics, [x, y - r]);
                G.call("h2d.Graphics", "lineTo", graphics, [x + r, y]);
                G.call("h2d.Graphics", "lineTo", graphics, [x, y + r]);
                G.call("h2d.Graphics", "lineTo", graphics, [x - r, y]);
                G.call("h2d.Graphics", "lineTo", graphics, [x, y - r]);
            case "npc":
                G.call("h2d.Graphics", "drawRect", graphics, [x - r, y - r, r * 2, r * 2]);
            default:
                G.call("h2d.Graphics", "drawCircle", graphics, [x, y, r, 12]);
        }
    }
}
