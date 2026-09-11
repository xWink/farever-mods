package minimap;

import minimap.GameAccess as G;
import minimap.MinimapMod.MinimapSettings;

private typedef MapPoint = {var x:Float; var y:Float; var kind:String; var ?heading:Float;}

/** Read-only map markers. Live entities are sampled five times a second. */
class MinimapMarkers {
    var graphics:Dynamic;
    var mapGraphics:Dynamic;
    var npcGraphics:Dynamic;
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
    var npcKinds:Map<String, String> = [];
    var landmarks:Map<String, MapPoint> = [];
    var stationSource:Dynamic;
    var stationDefinitions:Array<Dynamic> = [];
    var secretOrbs:Map<String, MapPoint> = [];
    var landmarkSources:Map<String, Dynamic> = [];
    var landmarkCounts:Map<String, Int> = [];
    static var reportedError:Bool = false;

    public function new(parent:Dynamic, foreground:Dynamic, level:String) {
        this.level = level;
        mapGraphics = G.create("h2d.Graphics", [parent]);
        npcGraphics = G.create("h2d.Graphics", [foreground]);
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
            var points = collect(hero, config, x, y, radius + 10 / scale);
            draw(points, scale);
        } catch (error:Dynamic) {
            // An optional marker source must not take down the working map.
            G.call("h2d.Graphics", "clear", mapGraphics);
            G.call("h2d.Graphics", "clear", npcGraphics);
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
        var allElements = G.current("HElement", "allElements");
        if (stationSource != allElements) {
            stationSource = allElements;
            stationDefinitions = [];
            // Stations have no dedicated HElement list. Index the loaded
            // definitions once, not on each marker refresh or from disk.
            if (allElements != null) for (definition in G.array(G.staticCall("HElement", "all", []))) {
                if (G.text(G.field(definition, "mapId")) != level) continue;
                if (stationKind(G.integer(G.field(G.field(definition, "inf"), "type"))) != "")
                    stationDefinitions.push(definition);
            }
            secretOrbs = [];
            if (allElements != null) {
                // Use the same objective targets as the native zone's secret
                // orb count. This excludes puzzle orbs and instance entrances.
                for (target in G.array(G.staticCall("ui.win.MapWindow", "getZoneRedOrbs", [null]))) {
                    if (Type.enumConstructor(target) != "Element") continue;
                    var id = G.text(Type.enumParameters(target)[0]);
                    var definition = G.call("haxe.ds.StringMap", "get", allElements, [id]);
                    if (G.text(G.field(definition, "mapId")) != level) continue;
                    var prefab = G.field(definition, "prefab");
                    if (prefab == null) continue;
                    var matrix = G.call("hrt.prefab.Object3D", "getAbsPos", prefab, [true]);
                    secretOrbs[id] = {kind: "secretOrb", x: G.number(G.field(matrix, "_41")), y: G.number(G.field(matrix, "_42"))};
                }
            }
            changed = true;
        }
        for (name in ["obelisks", "respawnPoints", "npcs"]) {
            var source = G.current("HElement", name);
            var count = G.integer(G.field(source, "length"));
            if (landmarkSources[name] != source || landmarkCounts[name] != count) changed = true;
            landmarkSources[name] = source; landmarkCounts[name] = count;
        }
        if (!changed) return;
        landmarks = [];
        for (name in ["obelisks", "respawnPoints", "npcs", "stations"]) {
            var kind = name == "obelisks" ? "obelisk" : name == "respawnPoints" ? "respawn" : "npc";
            var definitions = name == "stations" ? stationDefinitions : G.array(landmarkSources[name]);
            for (definition in definitions) {
                if (G.text(G.field(definition, "mapId")) != level) continue;
                var inf = G.field(definition, "inf");
                // Obelisks are also in respawnPoints; draw each location once.
                if (kind == "respawn" && G.integer(G.field(inf, "type")) == 13) continue;
                var prefab = G.field(definition, "prefab");
                if (prefab == null) continue;
                var matrix = G.call("hrt.prefab.Object3D", "getAbsPos", prefab, [true]);
                if (matrix == null) continue;
                var id = G.text(G.field(inf, "id"));
                landmarks[kind + ":" + id] = {kind: kind == "npc" ? npcKind(inf) : kind,
                    x: G.number(G.field(matrix, "_41")), y: G.number(G.field(matrix, "_42"))};
            }
        }
    }

    function collect(hero:Dynamic, config:MinimapSettings, x:Float, y:Float, radius:Float):Array<MapPoint> {
        var points:Array<MapPoint> = [];
        var liveNpcs:Map<String, MapPoint> = [];
        var player = G.field(hero, "player");
        var progress = G.field(player, "progress");
        var unitsProgress = G.field(G.field(progress, "unitsProgress"), "map");
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
            points.push({kind: kind, x: px, y: py, heading: kind == "player" ? G.number(G.field(unit, "rotationZ")) : 0});
        }

        if (config.showPlants || config.showOre || config.showNpcs || config.showChests) for (element in G.array(G.field(layer, "interactibles"))) {
            if (G.field(element, "removed") == true) continue;
            var category = family(element);
            if (category != "gatherable" && category != "npc" && category != "chest") continue;
            if (category == "npc" && !config.showNpcs || category == "chest" && !config.showChests
                || category == "gatherable" && !config.showPlants && !config.showOre) continue;
            var px = G.number(G.field(element, "posx")), py = G.number(G.field(element, "posy"));
            if (category != "npc" && !near(px, py, x, y, radius)) continue;
            var active = G.field(element, "enabled") == true && G.call("ent.Element", "isHidden", element) != true;
            if (category == "npc") {
                var key = "npc:" + G.text(G.field(element, "kind"));
                // Prefer a loaded NPC's actual position (or hidden state) over its prefab.
                liveNpcs[key] = active ? {kind: npcKind(G.field(element, "inf")), x: px, y: py} : null;
            } else if (category == "chest") {
                if (!active || player == null) continue;
                // Player-specific completion and respawn rules are resolved by
                // the game, including activity chests. Locked chests still show.
                var state = G.call("ent.Element", "getElementStateInf", element, [player]);
                var flags = G.integer(G.field(state, "flags"));
                if ((flags & 0x29) == 0) points.push({kind: "chest", x: px, y: py});
            } else if (active) {
                // Gatherable.consume disables the entity until its next respawn.
                // Hit points alone are unsuitable: plants don't need mining hits.
                var kind = gatherKind(G.field(element, "gatherInf"));
                if (kind == "plant" ? config.showPlants : kind == "ore" && config.showOre)
                    points.push({kind: kind, x: px, y: py});
            }
        }

        for (key => point in landmarks) {
            if (isNpc(point.kind) && liveNpcs.exists(key)) continue;
            var show = switch point.kind {
                case "obelisk": config.showObelisks;
                case "respawn": config.showRespawnPoints;
                default: config.showNpcs;
            };
            if (show && near(point.x, point.y, x, y, radius)) points.push(point);
        }
        for (point in liveNpcs) if (point != null && near(point.x, point.y, x, y, radius)) points.push(point);
        if (config.showSecretOrbs && progress != null) for (id => point in secretOrbs) {
            if (!near(point.x, point.y, x, y, radius)) continue;
            // Read only: never create a progress entry while displaying it.
            if (G.call("st.player.Progress", "hasElementDiscovered", progress, [id]) != true) points.push(point);
        }
        return points;
    }

    static function stationKind(type:Int):String return switch type {
        // Data.Element_type: CraftStation, GearUpgradeStation, ScrapStation.
        case 23: "craft";
        case 24: "upgrade";
        case 31: "recycler";
        default: "";
    };

    static function isNpc(kind:String):Bool return switch kind {
        case "npc", "bank", "demon", "craft", "upgrade", "recycler": true;
        default: false;
    };

    function npcKind(inf:Dynamic):String {
        var id = G.text(G.field(inf, "id"));
        if (npcKinds.exists(id)) return npcKinds[id];
        var kind = stationKind(G.integer(G.field(inf, "type")));
        if (kind != "") { npcKinds[id] = kind; return kind; }
        // Match Npc.get_uinf: the resolved instance's unit is authoritative.
        // Ancestor templates and inherited dialogue do not identify its role.
        var unit = G.text(G.field(G.field(G.field(inf, "props"), "npc"), "unit"));
        kind = switch unit {
            case "TODO_WanderingMerchant": "bank";
            case "DemonHunterMira", "DemonHunterZoey", "DemonHunterRumi": "demon";
            default: "npc";
        };
        npcKinds[id] = kind;
        return kind;
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
        // HashLink returns HVoid (not null) after the root class. Only walk
        // object types, or unrelated entities loop forever on the void sentinel.
        while (type != null && type.kind == HObj) {
            kind = switch type.getTypeName() {
                case "ent.Hero": "player";
                case "ent.Foe": "enemy";
                case "ent.interactible.Gatherable": "gatherable";
                case "ent.interactible.Chest": "chest";
                case "ent.interactible.Npc", "ent.interactible.CraftStation",
                    "ent.interactible.GearUpgradeStation", "ent.interactible.ScrapStation": "npc";
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
        G.call("h2d.Graphics", "clear", mapGraphics);
        G.call("h2d.Graphics", "clear", npcGraphics);
        // Group fills to keep native calls and draw batches small. Markers use
        // world positions, so the map can scroll/rotate smoothly between samples.
        // Services and obelisks remain readable when players gather around them.
        for (kind in ["plant", "ore", "secretOrb", "chest", "enemy", "boss", "player", "respawn", "obelisk", "npc", "bank", "demon", "recycler", "upgrade", "craft"]) {
            var group = [for (point in points) if (point.kind == kind) point];
            if (group.length == 0) continue;
            graphics = isNpc(kind) ? npcGraphics : mapGraphics;
            var color = switch kind {
                case "plant": 0x77df81;
                case "ore": 0xf0a658;
                case "chest": 0xffa044;
                case "secretOrb": 0x142d78;
                case "enemy", "boss": 0xff6860;
                case "respawn": 0xffffff;
                case "obelisk": 0xc599ff;
                case "npc": 0xffdf78;
                case "bank": 0xffdc42;
                case "demon": 0xe8a1ff;
                case "recycler": 0x86eed4;
                case "upgrade": 0xb4dcff;
                case "craft": 0xffc68a;
                default: 0x70d8ff;
            };
            var service = isNpc(kind) && kind != "npc" || kind == "chest";
            var radius = (service ? 7.0 : kind == "player" ? 7.0 : kind == "boss" ? 5.0 : kind == "obelisk" ? 4.5 : 3.5) / scale;
            G.call("h2d.Graphics", "beginFill", graphics, [0x201b1b, 0.95]);
            for (point in group) shape(point, radius + 1 / scale);
            G.call("h2d.Graphics", "endFill", graphics);
            G.call("h2d.Graphics", "beginFill", graphics, [color, 1.0]);
            for (point in group) shape(point, radius);
            G.call("h2d.Graphics", "endFill", graphics);
            if (service) {
                G.call("h2d.Graphics", "beginFill", graphics, [0x201b1b, 1.0]);
                for (point in group) detail(point, radius);
                G.call("h2d.Graphics", "endFill", graphics);
            }
        }
    }

    function shape(point:MapPoint, r:Float):Void {
        var x = point.x, y = point.y;
        switch point.kind {
            case "player":
                // Arrow geometry points along +X, like Entity.rotationZ.
                polygon(point, r, [1, 0, -0.8, 0.7, -0.45, 0, -0.8, -0.7], point.heading);
            case "bank":
                // A bold dollar sign, built as filled geometry at any zoom.
                polygon(point, r, [0.7, -0.8, -0.35, -0.8, -0.7, -0.5, -0.7, -0.1,
                    -0.35, 0.2, 0.35, 0.2, 0.4, 0.3, 0.4, 0.45, 0.3, 0.55,
                    -0.7, 0.55, -0.7, 0.85, 0.4, 0.85, 0.75, 0.55, 0.75, 0.1,
                    0.4, -0.15, -0.3, -0.15, -0.4, -0.25, -0.4, -0.4, -0.3, -0.5, 0.7, -0.5]);
                G.call("h2d.Graphics", "drawRect", graphics, [x - 0.13 * r, y - 1.05 * r, 0.26 * r, 2.15 * r]);
            case "chest":
                // A chest with an arched lid; seam and lock are drawn below.
                polygon(point, r, [-1, 0.8, -1, -0.35, -0.65, -0.8, 0.65, -0.8, 1, -0.35, 1, 0.8]);
            case "demon":
                // Horned face, distinct from the enemy dots.
                polygon(point, r, [-0.9, -1, -0.35, -0.4, 0.35, -0.4, 0.9, -1,
                    0.8, 0.25, 0.45, 0.75, 0, 1, -0.45, 0.75, -0.8, 0.25]);
            case "recycler":
                // Two chasing arrows.
                polygon(point, r, [-0.95, 0.05, -0.95, -0.55, -0.5, -0.95, 0.45, -0.95,
                    0.45, -1.2, 1, -0.65, 0.45, -0.1, 0.45, -0.4, -0.45, -0.4, -0.45, 0.05]);
                polygon(point, r, [0.95, -0.05, 0.95, 0.55, 0.5, 0.95, -0.45, 0.95,
                    -0.45, 1.2, -1, 0.65, -0.45, 0.1, -0.45, 0.4, 0.45, 0.4, 0.45, -0.05]);
            case "upgrade":
                // Upright sword and an upward upgrade arrow.
                polygon(point, r, [-0.45, -1, -0.15, -0.65, -0.15, 0.2, 0.15, 0.2,
                    0.15, 0.45, -0.3, 0.45, -0.3, 1, -0.6, 1, -0.6, 0.45,
                    -1, 0.45, -1, 0.2, -0.75, 0.2, -0.75, -0.65]);
                polygon(point, r, [0.6, -0.85, 1.15, -0.25, 0.8, -0.25, 0.8, 0.6,
                    0.4, 0.6, 0.4, -0.25, 0.05, -0.25]);
            case "craft":
                // Hammer above a workbench.
                polygon(point, r, [-0.15, -0.85, 0.15, -0.85, 0.15, 0.35, -0.15, 0.35]);
                polygon(point, r, [-0.65, -1, 0.65, -1, 0.65, -0.45, -0.65, -0.45]);
                polygon(point, r, [-1, 0.25, 1, 0.25, 1, 0.55, 0.7, 0.55, 0.7, 1,
                    0.4, 1, 0.4, 0.55, -0.4, 0.55, -0.4, 1, -0.7, 1, -0.7, 0.55, -1, 0.55]);
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
                G.call("h2d.Graphics", "drawCircle", graphics, [x, y, r, 32]);
        }
    }

    function polygon(point:MapPoint, radius:Float, vertices:Array<Float>, angle:Float = 0):Void {
        var c = Math.cos(angle) * radius, s = Math.sin(angle) * radius;
        for (i in 0...Std.int(vertices.length / 2) + 1) {
            var j = i * 2 % vertices.length;
            var x = point.x + vertices[j] * c - vertices[j + 1] * s;
            var y = point.y + vertices[j] * s + vertices[j + 1] * c;
            G.call("h2d.Graphics", i == 0 ? "moveTo" : "lineTo", graphics, [x, y]);
        }
    }

    function detail(point:MapPoint, r:Float):Void {
        switch point.kind {
            case "chest":
                G.call("h2d.Graphics", "drawRect", graphics, [point.x - r, point.y - 0.2 * r, 2 * r, 0.2 * r]);
                G.call("h2d.Graphics", "drawRect", graphics, [point.x - 0.16 * r, point.y - 0.05 * r, 0.32 * r, 0.4 * r]);
            case "demon":
                polygon(point, r, [-0.6, -0.05, -0.15, 0.1, -0.2, 0.3, -0.5, 0.25]);
                polygon(point, r, [0.6, -0.05, 0.15, 0.1, 0.2, 0.3, 0.5, 0.25]);
            default:
        }
    }
}
