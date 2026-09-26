package minimap;

import minimap.GameAccess as G;
import minimap.MinimapMod.MinimapSettings;
import minimap.MarkerDetails.MarkerHover;
import minimap.RiftMarkers.RiftPoint;

private typedef MapPoint = {
    var x:Float;
    var y:Float;
    var z:Float;
    var kind:String;
    var ?elevation:Int;
    var ?heading:Float;
    var ?sparkling:Bool;
    var ?eventElement:String;
    var ?entity:Dynamic;
    var ?inf:Dynamic;
    var ?name:String;
    var ?hasMarker:Bool;
}

private typedef ElevationMarker = {
    var root:Dynamic;
    var arrow:Dynamic;
}

private typedef IconMarker = {
    var icon:Dynamic;
    var key:String;
    var directional:Bool;
}

/** Read-only map markers. Live entities are sampled five times a second. */
class MinimapMarkers {
    var graphics:Dynamic;
    var playerIcons:Dynamic;
    var playerElevations:Dynamic;
    var playerIconMarkers:Array<IconMarker> = [];
    var playerElevationMarkers:Array<ElevationMarker> = [];
    var mapIcons:Dynamic;
    var npcIcons:Dynamic;
    var mapIconMarkers:Array<IconMarker> = [];
    var npcIconMarkers:Array<IconMarker> = [];
    var mapElevations:Dynamic;
    var npcElevations:Dynamic;
    var mapElevationMarkers:Array<ElevationMarker> = [];
    var npcElevationMarkers:Array<ElevationMarker> = [];
    var mapRotation:Float = 0;
    var markerScale:Float = 1;
    var heroHeight:Float = Math.NaN;
    var alertLayer:Dynamic;
    var alertTargets:Array<MapPoint> = [];
    var alertArrows:Array<Dynamic> = [];
    var alertPositions:Array<{x:Float, y:Float, point:MapPoint}> = [];
    var rifts:RiftMarkers;
    var riftArrow:Dynamic;
    var riftAlertPosition:Null<{x:Float, y:Float, point:RiftPoint}>;
    var level:String;
    var layer:Dynamic;
    var lastHero:Dynamic;
    var previousConfig:MinimapSettings;
    var nextRefresh:Float = 0;
    var previousScale:Float = 0;
    var previousRadius:Float = 0;
    var classes:Map<String, String> = [];
    var gatherKinds:Map<String, String> = [];
    var gatherFilters:Map<String, String> = [];
    var enemies = new EnemyMarkers();
    var chests = new ChestMarkers();
    var worldEvents = new WorldEventAccess();
    var npcKinds:Map<String, String> = [];
    var npcDefinitions:Map<String, Dynamic> = [];
    var landmarks:Map<String, MapPoint> = [];
    var stationSource:Dynamic;
    var stationDefinitions:Array<Dynamic> = [];
    var soulstoneDefinitions:Array<Dynamic> = [];
    var secretOrbs:Map<String, MapPoint> = [];
    var activitySource:Dynamic;
    var activityOrbSource:Dynamic;
    var activityOrbCount:Int = 0;
    var activities:Array<MapPoint> = [];
    var hitPoints:Array<MapPoint> = [];
    var landmarkSources:Map<String, Dynamic> = [];
    var landmarkCounts:Map<String, Int> = [];
    static var reportedError:Bool = false;

    public function new(parent:Dynamic, foreground:Dynamic, overlay:Dynamic, level:String) {
        this.level = level;
        // Players and their height arrows sit below the local cursor. All other
        // markers sit above it, with NPCs retaining the highest normal priority.
        playerIcons = G.create("h2d.Object", [parent]);
        playerElevations = G.create("h2d.Object", [parent]);
        mapIcons = G.create("h2d.Object", [foreground]);
        mapElevations = G.create("h2d.Object", [foreground]);
        npcIcons = G.create("h2d.Object", [foreground]);
        npcElevations = G.create("h2d.Object", [foreground]);
        alertLayer = G.create("h2d.Object", [overlay]);
    }

    public function update(hero:Dynamic, config:MinimapSettings, x:Float, y:Float, radius:Float, scale:Float, rotation:Float, rifts:RiftMarkers):Void {
        this.rifts = rifts;
        if (mapRotation != rotation) {
            mapRotation = rotation;
            for (marker in mapIconMarkers) if (!marker.directional)
                G.call("h2d.Object", "set_rotation", marker.icon, [-rotation]);
            for (marker in npcIconMarkers) G.call("h2d.Object", "set_rotation", marker.icon, [-rotation]);
            for (marker in playerElevationMarkers) G.call("h2d.Object", "set_rotation", marker.root, [-rotation]);
            for (marker in mapElevationMarkers) G.call("h2d.Object", "set_rotation", marker.root, [-rotation]);
            for (marker in npcElevationMarkers) G.call("h2d.Object", "set_rotation", marker.root, [-rotation]);
        }
        var now = haxe.Timer.stamp();
        var nextLayer = G.field(hero, "layer");
        var nextMarkerScale = config.markerScale / 100;
        var changed = previousConfig != config || previousScale != scale || previousRadius != radius
            || lastHero != hero || layer != nextLayer || markerScale != nextMarkerScale;
        if (!changed && now < nextRefresh) return;
        previousConfig = config; previousScale = scale; previousRadius = radius;
        markerScale = nextMarkerScale;
        lastHero = hero; layer = nextLayer;
        nextRefresh = now + 0.2;
        heroHeight = G.number(G.field(hero, "posz"), Math.NaN);
        try {
            refreshLandmarks();
            var points = collect(hero, config, x, y, radius + 12 * markerScale / scale);
            draw(points, scale);
        } catch (error:Dynamic) {
            hitPoints = [];
            alertTargets = [];
            // An optional marker source must not take down the working map.
            trimIcons(playerIconMarkers, 0);
            trimElevations(playerElevationMarkers, 0);
            trimIcons(mapIconMarkers, 0);
            trimIcons(npcIconMarkers, 0);
            trimElevations(mapElevationMarkers, 0);
            trimElevations(npcElevationMarkers, 0);
            nextRefresh = now + 5;
            if (!reportedError) {
                reportedError = true;
                trace("[Minimap] Markers: " + Std.string(error));
            }
        }
    }

    public function updateAlerts(config:MinimapSettings, x:Float, y:Float, size:Int, scale:Float, rotation:Float, rifts:RiftMarkers):Void {
        updateRiftAlert(config, x, y, size, scale, rotation, rifts);
        var count = config.sparklingCompanionAlerts ? alertTargets.length : 0;
        while (alertArrows.length > count) {
            G.call("h2d.Object", "remove", alertArrows.pop());
        }
        while (alertArrows.length < count) {
            var arrow = G.create("h2d.Graphics", [alertLayer]);
            drawAlertArrow(arrow);
            alertArrows.push(arrow);
        }
        alertPositions = [];
        if (count == 0) return;
        // Keep geometry cached; only position and rotate the few active arrows
        // each frame so they follow movement and camera rotation smoothly.
        var c = Math.cos(rotation), s = Math.sin(rotation);
        var north = config.showNorthIndicator ? MinimapGeometry.north(size, config.circular, rotation, markerScale) : null;
        for (i in 0...count) {
            var point = alertTargets[i];
            var dx = (point.x - x) * scale, dy = (point.y - y) * scale;
            var sx = dx * c - dy * s, sy = dx * s + dy * c;
            // Height filtering affects the map icon, never its guidance arrow.
            var hasMarker = point.hasMarker == true && !MarkerDetails.hidden(point.z, heroHeight,
                config.hideVerticallyDistantMarkers, config.verticallyDistantThreshold);
            var visible = G.field(point.entity, "removed") != true && MinimapGeometry.showAlert(hasMarker,
                sx, sy, size, config.circular, (markerRadius("companion") + 3.5) * markerScale);
            var arrow = alertArrows[i];
            G.call("h2d.Object", "setScale", arrow, [markerScale]);
            G.call("h2d.Object", "set_visible", arrow, [visible]);
            if (!visible) continue;
            var pos = MinimapGeometry.alert(sx, sy, size, config.circular, markerScale, north);
            G.call("h2d.Object", "setPosition", arrow, [pos.x, pos.y]);
            G.call("h2d.Object", "set_rotation", arrow, [Math.atan2(sy, sx)]);
            alertPositions.push({x: pos.x, y: pos.y, point: point});
        }
    }

    public function alertHoverAt(x:Float, y:Float):Null<MarkerHover> {
        if (riftAlertPosition != null && nearCursor(x, y, riftAlertPosition.x, riftAlertPosition.y, 12 * markerScale))
            return MarkerDetails.hover(RiftMarkers.name(riftAlertPosition.point.kind), riftAlertPosition.point);
        var i = alertPositions.length;
        while (i > 0) {
            var alert = alertPositions[--i];
            if (nearCursor(x, y, alert.x, alert.y, 12 * markerScale) && G.field(alert.point.entity, "removed") != true)
                return MarkerDetails.hover(markerName(alert.point), alert.point);
        }
        return null;
    }

    function updateRiftAlert(config:MinimapSettings, x:Float, y:Float, size:Int, scale:Float, rotation:Float, rifts:RiftMarkers):Void {
        riftAlertPosition = null;
        var target = config.riftAlerts ? rifts.alertTarget() : null;
        var visible = false;
        if (target != null) {
            var dx = (target.x - x) * scale, dy = (target.y - y) * scale;
            var c = Math.cos(rotation), s = Math.sin(rotation);
            var sx = dx * c - dy * s, sy = dx * s + dy * c;
            var hasMarker = config.showActivities && !MarkerDetails.hidden(target.z, heroHeight,
                config.hideVerticallyDistantMarkers, config.verticallyDistantThreshold);
            visible = MinimapGeometry.showAlert(hasMarker, sx, sy, size, config.circular,
                (markerRadius(target.kind) + 1) * markerScale);
            if (visible) {
                if (riftArrow == null) {
                    riftArrow = G.create("h2d.Graphics", [alertLayer]);
                    LandmarkIcons.alertArrow(riftArrow, 11, LandmarkIcons.RIFT_ALERT_COLOR);
                }
                var north = config.showNorthIndicator ? MinimapGeometry.north(size, config.circular, rotation, markerScale) : null;
                var pos = MinimapGeometry.alert(sx, sy, size, config.circular, markerScale, north);
                G.call("h2d.Object", "setScale", riftArrow, [markerScale]);
                G.call("h2d.Object", "setPosition", riftArrow, [pos.x, pos.y]);
                G.call("h2d.Object", "set_rotation", riftArrow, [Math.atan2(sy, sx)]);
                riftAlertPosition = {x: pos.x, y: pos.y, point: target};
            }
        }
        if (riftArrow != null) G.call("h2d.Object", "set_visible", riftArrow, [visible]);
    }

    function refreshLandmarks():Void {
        // HElement is also the native MapWindow's landmark source. Rebuild only
        // if those lists change; never traverse level prefabs on every refresh.
        var changed = false;
        var allElements = G.current("HElement", "allElements");
        if (stationSource != allElements) {
            stationSource = allElements;
            stationDefinitions = [];
            soulstoneDefinitions = [];
            // Stations and soulstone circles have no dedicated HElement list.
            // Index loaded definitions once, not on each refresh or from disk.
            if (allElements != null) for (definition in G.array(G.staticCall("HElement", "all", []))) {
                if (G.text(G.field(definition, "mapId")) != level) continue;
                if (stationKind(G.integer(G.field(G.field(definition, "inf"), "type"))) != "")
                    stationDefinitions.push(definition);
                var inf = G.field(definition, "inf");
                if (SoulstoneMarkers.isCircle(inf)
                    && worldEvents.checkStatus(G.field(G.field(inf, "props"), "releaseStatus")))
                    soulstoneDefinitions.push(definition);
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
                    secretOrbs[id] = {kind: "secretOrb", inf: G.field(definition, "inf"),
                        x: G.number(G.field(matrix, "_41")), y: G.number(G.field(matrix, "_42")),
                        z: G.number(G.field(matrix, "_43"), Math.NaN)};
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
        for (name in ["obelisks", "respawnPoints", "npcs", "stations", "soulstoneCircles"]) {
            var kind = switch name {
                case "obelisks": "obelisk";
                case "respawnPoints": "respawn";
                case "soulstoneCircles": "soulstone";
                default: "npc";
            };
            var definitions = switch name {
                case "stations": stationDefinitions;
                case "soulstoneCircles": soulstoneDefinitions;
                default: G.array(landmarkSources[name]);
            };
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
                landmarks[kind + ":" + id] = {kind: kind == "npc" ? npcKind(inf) : kind, inf: inf,
                    x: G.number(G.field(matrix, "_41")), y: G.number(G.field(matrix, "_42")),
                    z: G.number(G.field(matrix, "_43"), Math.NaN)};
            }
        }
    }

    function collect(hero:Dynamic, config:MinimapSettings, x:Float, y:Float, radius:Float):Array<MapPoint> {
        var points:Array<MapPoint> = [];
        alertTargets = [];
        var liveNpcs:Map<String, MapPoint> = [];
        var player = G.field(hero, "player");
        var progress = G.field(player, "progress");
        var unitsProgress = G.field(G.field(progress, "unitsProgress"), "map");
        var collection = G.field(G.field(player, "accountProgress"), "collection");
        var enemyKinds:Map<String, String> = [];
        var collected:Map<String, Bool> = [];
        if (config.showPlayers || config.showEnemies || config.showCompanions || config.sparklingCompanionAlerts)
        for (unit in G.array(G.field(layer, "units"))) {
            if (unit == hero || G.field(unit, "removed") == true) continue;
            var kind = family(unit);
            if (kind != "player" && kind != "enemy") continue;
            if (kind == "player" ? !config.showPlayers : !config.showEnemies && !config.showCompanions && !config.sparklingCompanionAlerts) continue;
            var px = G.number(G.field(unit, "posx")), py = G.number(G.field(unit, "posy"));
            var nearby = near(px, py, x, y, radius);
            if (!nearby && (kind == "player" || !config.sparklingCompanionAlerts)) continue;
            var inf = kind == "enemy" ? G.field(unit, "inf") : null;
            var flags = G.integer(G.field(inf, "flags"));
            var sparkling = (flags & (1 << 22)) != 0;
            var companion = G.text(G.field(inf, "type")) == "Critter";
            var alert = config.sparklingCompanionAlerts && companion && sparkling;
            var point:MapPoint = null;
            // Alerts scan every replicated unit, with no minimap-distance cutoff.
            if (!nearby && !alert) continue;
            if (G.field(unit, "dying") == true || G.call("ent.GameObject", "isDead", unit) == true) continue;
            if (kind == "enemy") {
                // Player-owned summons are allies, including nested summons.
                var source = unit;
                var summoner = G.field(source, "summonOwner");
                while (summoner != null) { source = summoner; summoner = G.field(source, "summonOwner"); }
                if (family(source) == "player") continue;
                if (inf == null) continue;
                var id = G.text(G.field(inf, "id"));
                if (companion) {
                    // Same collectible entries as CollectionUI: exclude
                    // NoCollection (bit 20) and definitions without artwork.
                    if ((!config.showCompanions && !alert) || (flags & (1 << 20)) != 0 || G.field(inf, "gfx") == null) continue;
                    kind = "companion";
                    var owned = false;
                    if ((config.hideCollectedCompanions || alert) && collection != null) {
                        // Capture saves the exact unit kind, including its color
                        // or sparkling variant, in the account-wide collection.
                        var pet = G.text(G.field(unit, "kind"), id);
                        if (!collected.exists(pet))
                            collected[pet] = G.call("st.player.Collection", "hasPet", collection, [pet]) == true;
                        owned = collected[pet];
                    }
                    if (alert && collection != null && !owned) {
                        point = {kind: kind, x: px, y: py, z: G.number(G.field(unit, "posz"), Math.NaN), sparkling: true, entity: unit};
                        alertTargets.push(point);
                    }
                    if (!config.showCompanions || !nearby || (config.hideCollectedCompanions && owned)) continue;
                } else {
                    if (!config.showEnemies || G.call("ent.Foe", "isEnemyWith", unit, [hero]) != true) continue;
                    if (!enemyKinds.exists(id)) {
                        var needsProgress = config.hideCompletedCodexEnemies || config.hideMasteredCodexEnemies;
                        var progress = !needsProgress || unitsProgress == null ? null : G.call("haxe.ds.StringMap", "get", unitsProgress, [id]);
                        enemyKinds[id] = enemies.kind(inf, G.integer(G.field(progress, "killCount")),
                            config.hideCompletedCodexEnemies, config.hideMasteredCodexEnemies, config.hideTargetDummies);
                    }
                    kind = enemyKinds[id];
                    if (kind == "") continue;
                    sparkling = (kind == "enemy" || kind == "boss") && EnemyMarkers.highlighted(inf);
                }
            }
            if (point == null) point = {kind: kind, x: px, y: py, z: G.number(G.field(unit, "posz"), Math.NaN), sparkling: sparkling, entity: unit,
                heading: kind == "player" ? G.number(G.field(unit, "rotationZ")) : 0};
            // Share the exact sampled position with the alert. Settings can
            // hide normal companion markers while leaving alerts enabled.
            point.hasMarker = true;
            points.push(point);
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
                liveNpcs[key] = active ? {kind: npcKind(G.field(element, "inf")), x: px, y: py,
                    z: G.number(G.field(element, "posz"), Math.NaN), entity: element} : null;
            } else if (category == "chest") {
                if (!active || player == null) continue;
                // Player-specific completion and respawn rules are resolved by
                // the game, including activity chests. Locked chests still show.
                var state = G.call("ent.Element", "getElementStateInf", element, [player]);
                var flags = G.integer(G.field(state, "flags"));
                if ((flags & 0x29) == 0) points.push({kind: chests.kind(G.field(element, "inf")), x: px, y: py,
                    z: G.number(G.field(element, "posz"), Math.NaN), entity: element});
            } else if (active) {
                // Gatherable.consume disables the entity until its next respawn.
                // Hit points alone are unsuitable: plants don't need mining hits.
                var inf = G.field(element, "gatherInf");
                var kind = gatherKind(inf);
                if ((kind == "plant" ? config.showPlants : kind == "ore" && config.showOre)
                    && !hiddenResource(gatherFilters[G.text(G.field(inf, "id"))], config))
                    points.push({kind: kind, x: px, y: py, z: G.number(G.field(element, "posz"), Math.NaN), entity: element});
            }
        }

        for (key => point in landmarks) {
            if (isNpc(point.kind) && liveNpcs.exists(key)) continue;
            var show = switch point.kind {
                case "obelisk": config.showObelisks;
                case "respawn": config.showRespawnPoints;
                case "soulstone": config.showSoulstoneCircles;
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
        if (config.showActivities) {
            refreshActivities();
            var events = G.field(layer, "worldEvents");
            for (point in activities) {
                if (!near(point.x, point.y, x, y, radius)) continue;
                if (ActivityMarkers.hidden(point.kind, point.inf, progress, config)) continue;
                if (point.eventElement != null && events != null) {
                    var event = worldEvents.elementStatus(events, point.eventElement);
                    if (G.text(G.field(event, "status")) == "Disabled") continue;
                }
                points.push(point);
            }
            for (point in rifts.displayPoints(config.hideInactiveRifts)) if (near(point.x, point.y, x, y, radius))
                points.push({kind: point.kind, x: point.x, y: point.y, z: point.z,
                    name: RiftMarkers.name(point.kind)});
        }
        // Apply one height rule after collecting every category. Hidden points
        // never reach icon drawing or hover hit-testing. Keep alert targets:
        // the vertical filter must not hide the arrows that guide to them.
        return MarkerDetails.filter(points, heroHeight,
            config.hideVerticallyDistantMarkers, config.verticallyDistantThreshold);
    }

    function refreshActivities():Void {
        var source = G.current("HActivity", "allActivities");
        var orbs = G.current("HElement", "instanceOrbs");
        var count = G.integer(G.field(orbs, "length"));
        if (source == activitySource && orbs == activityOrbSource && count == activityOrbCount) return;
        activitySource = source; activityOrbSource = orbs; activityOrbCount = count;
        activities = [];
        if (source == null) return;
        // Use the native world map's released activity definitions and marker
        // positions. Resolve prefab positions once, not on each marker refresh.
        for (definition in G.array(G.staticCall("HActivity", "allFiltered", [level]))) {
            var prefab = G.field(definition, "prefab");
            if (prefab == null) continue;
            var inf = G.field(definition, "inf");
            if (G.staticCall("HActivity", "isOfType", [inf, "Rift"]) == true) continue;
            var kind = ActivityMarkers.kind(inf);
            var start = kind == "ascension" ? checkpointStart(prefab) : null;
            if (start != null) {
                var matrix = G.call("hrt.prefab.Object3D", "getAbsPos", start, [true]);
                activities.push({kind: "ascension", inf: inf,
                    x: G.number(G.field(matrix, "_41")), y: G.number(G.field(matrix, "_42")),
                    z: G.number(G.field(matrix, "_43"), Math.NaN)});
                continue;
            }
            var position = G.staticCall("HActivity", "getPos", [definition]);
            activities.push({kind: kind, inf: inf,
                x: G.number(G.field(position, "x")), y: G.number(G.field(position, "y")),
                z: G.number(G.field(position, "z"), Math.NaN)});
        }
        // Instanced activities are marked at their overworld entrance, just as
        // MapWindow.addActivities does, rather than at their interior position.
        for (orb in G.array(orbs)) {
            if (G.text(G.field(orb, "mapId")) != level || G.field(orb, "prefab") == null) continue;
            var inf = G.field(orb, "inf");
            var id = G.text(G.field(G.field(inf, "props"), "targetActivity"));
            if (id == "") continue;
            var definition = G.call("haxe.ds.StringMap", "get", source, [id]);
            if (definition == null) continue;
            var activityInf = G.field(definition, "inf");
            if (G.staticCall("HActivity", "isOfType", [activityInf, "Rift"]) == true) continue;
            var props = G.field(activityInf, "props");
            if (!worldEvents.checkStatus(G.field(props, "releaseStatus"))) continue;
            var matrix = G.call("hrt.prefab.Object3D", "getAbsPos", G.field(orb, "prefab"), [true]);
            activities.push({kind: ActivityMarkers.kind(activityInf), inf: activityInf,
                x: G.number(G.field(matrix, "_41")), y: G.number(G.field(matrix, "_42")),
                z: G.number(G.field(matrix, "_43"), Math.NaN),
                eventElement: G.text(G.field(inf, "id"))});
        }
    }

    static function checkpointStart(prefab:Dynamic):Dynamic {
        // Ascension.onElementActivate uses its Start collectible to return to
        // the latest checkpoint. Resolve its prefab once with the activity cache.
        var pending:Array<Dynamic> = [prefab];
        while (pending.length > 0) {
            var node = pending.pop();
            if (G.text(G.field(node, "name")) == "Start"
                && G.call("hrt.prefab.Prefab", "getCdbType", node) == "element") return node;
            for (child in G.array(G.field(node, "children"))) pending.push(child);
        }
        return null;
    }

    static function stationKind(type:Int):String return NpcMarkers.stationKind(type);

    static function isNpc(kind:String):Bool return NpcMarkers.isNpc(kind);

    function npcKind(inf:Dynamic):String {
        var id = G.text(G.field(inf, "id"));
        // The live instance may have a richer definition than the map entry.
        // Do not let a cached generic icon mask its resolved service title.
        if (npcKinds.exists(id) && npcDefinitions[id] == inf) return npcKinds[id];
        var kind = NpcMarkers.kind(inf);
        npcKinds[id] = kind;
        npcDefinitions[id] = inf;
        return kind;
    }

    function gatherKind(inf:Dynamic):String {
        var id = G.text(G.field(inf, "id"));
        if (gatherKinds.exists(id)) return gatherKinds[id];
        var kind = "";
        var filter = "";
        var current = inf;
        var seen:Map<String, Bool> = [];
        while (current != null) {
            var currentId = G.text(G.field(current, "id"));
            if (seen.exists(currentId)) break;
            seen[currentId] = true;
            if (filter == "") filter = switch currentId {
                case "Ore_Copper_Small", "Ore_Copper_Large": "Copper";
                case "Ore_Iron_Small", "Ore_Iron_Big": "Iron";
                case "Ore_Tin_Small", "Ore_Tin_Large": "Tin";
                case "Tungstene": "Tungstene";
                case "Madrigold_Small", "Madrigold_Large": "Madrigold";
                case "Lavendula_Small", "Lavendula_Large": "Lavendula";
                case "AncientThyme_Small", "AncientThyme_Large": "AncientThyme";
                case "Zealotus_Small", "Zealotus_Large": "Zealotus";
                default: "";
            };
            var tool = G.text(G.field(current, "requiredTool"));
            if (currentId == "Ore" || tool == "GearPickaxe") { kind = "ore"; break; }
            if (currentId == "Plant" || tool == "GearSickle") { kind = "plant"; break; }
            var parent = G.text(G.field(current, "inherit"));
            if (parent == "") break;
            current = G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "gatherable"), "byId"), [parent]);
        }
        gatherKinds[id] = kind;
        gatherFilters[id] = filter;
        return kind;
    }

    static function hiddenResource(resource:String, config:MinimapSettings):Bool return switch resource {
        case "Copper": config.hideCopper;
        case "Iron": config.hideIron;
        case "Tin": config.hideTin;
        case "Tungstene": config.hideTungstene;
        case "Madrigold": config.hideMadrigold;
        case "Lavendula": config.hideLavendula;
        case "AncientThyme": config.hideAncientThyme;
        case "Zealotus": config.hideZealotus;
        default: false;
    };

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
                    "ent.interactible.GearUpgradeStation", "ent.interactible.ScrapStation",
                    "ent.interactible.InfusionStation": "npc";
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

    static function markerRadius(kind:String):Float return switch kind {
        case "bank", "demon", "player", "activity", "ascension", "companion": 7;
        case "plant", "ore", "boss": 5;
        case "obelisk", "dungeon", "soulstone", "secretOrb", "glory", "chest", "vaultChest", "recipeChest": 8;
        case "targetDummy", "upcomingRift", "infusion", "craft", "recycler": 9;
        case "riftPortal": 11;
        case "inactiveRift", "nextRift", "upgrade": 10;
        default: 3.5;
    };

    static function elevationDirection(z:Float, heroZ:Float):Int {
        var difference = z - heroZ;
        // Missing height data stays unknown rather than becoming sea level.
        if (!Math.isFinite(difference)) return 0;
        return difference > 15 ? 1 : difference < -15 ? -1 : 0;
    }

    static function elevationOffset(point:MapPoint):Float
        return markerRadius(point.kind) + (point.sparkling == true ? 3.5 : 1) + 3;

    function updateElevations(points:Array<MapPoint>, pool:Array<ElevationMarker>, parent:Dynamic, scale:Float):Void {
        trimElevations(pool, points.length);
        while (pool.length < points.length) {
            var root = G.create("h2d.Object", [parent]);
            var arrow = G.create("h2d.Graphics", [root]);
            drawPlayerArrow(arrow, 4, 0xfff3d6);
            pool.push({root: root, arrow: arrow});
        }
        for (i in 0...points.length) {
            var point = points[i], marker = pool[i];
            G.call("h2d.Object", "setPosition", marker.root, [point.x, point.y]);
            G.call("h2d.Object", "setScale", marker.root, [markerScale / scale]);
            G.call("h2d.Object", "set_rotation", marker.root, [-mapRotation]);
            G.call("h2d.Object", "setPosition", marker.arrow, [elevationOffset(point), 0.0]);
            G.call("h2d.Object", "set_rotation", marker.arrow, [-point.elevation * Math.PI / 2]);
        }
    }

    function trimElevations(pool:Array<ElevationMarker>, count:Int):Void {
        while (pool.length > count) G.call("h2d.Object", "remove", pool.pop().root);
    }

    public function hoverAt(x:Float, y:Float, scale:Float, heroX:Float, heroY:Float, hero:Dynamic):Null<MarkerHover> {
        var checkHero = true;
        var i = hitPoints.length;
        // Reverse draw order: other markers, then our cursor, then other players.
        while (i > 0) {
            var point = hitPoints[--i];
            if (checkHero && point.kind == "player") {
                checkHero = false;
                if (nearCursor(x, y, heroX, heroY, 11 * markerScale / scale)) return heroHover(hero, heroX, heroY);
            }
            var r = (markerRadius(point.kind) + (point.sparkling == true ? 2.5 : 0) + 2) * markerScale / scale;
            var hit = nearCursor(x, y, point.x, point.y, r);
            if (!hit && point.elevation != null && point.elevation != 0) {
                var offset = elevationOffset(point) * markerScale / scale;
                hit = nearCursor(x, y, point.x + Math.cos(mapRotation) * offset,
                    point.y - Math.sin(mapRotation) * offset, 6 * markerScale / scale);
            }
            if (!hit) continue;
            if (point.entity != null && G.field(point.entity, "removed") == true) continue;
            return MarkerDetails.hover(markerName(point), point);
        }
        return checkHero && nearCursor(x, y, heroX, heroY, 11 * markerScale / scale) ? heroHover(hero, heroX, heroY) : null;
    }

    function heroHover(hero:Dynamic, x:Float, y:Float):MarkerHover
        return {name: G.text(G.field(hero, "name")), x: x, y: y, z: G.number(G.field(hero, "posz"), Math.NaN)};

    static function nearCursor(x:Float, y:Float, px:Float, py:Float, radius:Float):Bool {
        var dx = x - px, dy = y - py;
        return dx * dx + dy * dy <= radius * radius;
    }

    function markerName(point:MapPoint):String {
        if (point.kind == "secretOrb") return "Secret Orb";
        if (point.kind == "recipeChest") return "Recipe Chest";
        if (point.name != null) return point.name;
        var name = "";
        try {
            if (point.entity != null) {
                var type = switch point.kind {
                    case "player": "ent.Hero";
                    case "enemy", "boss", "companion", "targetDummy": "ent.Unit";
                    case "plant", "ore": "ent.interactible.Gatherable";
                    default: "ent.Element";
                };
                name = G.text(G.call(type, "getName", point.entity));
            } else if (point.inf != null) {
                name = G.text(G.staticCall("HText", point.kind == "activity" || point.kind == "ascension" || point.kind == "dungeon" ? "activity" : "element",
                    [point.inf, G.current("ETextKind", "Name")]));
            }
            if (name == "" && isNpc(point.kind)) {
                var inf = point.inf != null ? point.inf : G.field(point.entity, "inf");
                var unit = G.text(G.field(G.field(G.field(inf, "props"), "npc"), "unit"));
                var unitInf = G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "unit"), "byId"), [unit]);
                if (unitInf != null) name = G.text(G.staticCall("HText", "unit", [unitInf, G.current("ETextKind", "Name")]));
            }
        } catch (_:Dynamic) {}
        if (name == "") name = switch point.kind {
            case "chest": "Chest";
            case "vaultChest": "Vault Chest";
            case "respawn": "Respawn point";
            case "obelisk": "Obelisk";
            case "soulstone": "Soulstone summoning circle";
            case "bank": "Guild Merchant";
            case "demon": "Demon Huntress";
            case "recycler": "Spark Recycler";
            case "upgrade": "Weapon Upgrade";
            case "craft": "Crafting Station";
            case "glory": "Glory Merchant";
            case "infusion": "Infusion Crucible";
            case "activity": "Activity";
            case "ascension": "Ascension";
            case "dungeon": "Dungeon";
            case "plant": "Plant";
            case "ore": "Ore";
            case "player": "Player";
            case "companion": "Companion";
            case "enemy", "boss": "Enemy";
            case "targetDummy": "Target dummy";
            default: "NPC";
        };
        // Static names are retained; live samples expire at the next refresh.
        point.name = StringTools.replace(StringTools.replace(name, "\n", " "), "\r", "");
        return point.name;
    }

    function draw(points:Array<MapPoint>, scale:Float):Void {
        hitPoints = [];
        // All Rift states draw above enemies; services retain top priority.
        for (kind in ["player", "activity", "ascension", "dungeon", "plant", "ore", "secretOrb", "chest", "vaultChest", "recipeChest", "companion", "enemy", "boss", "targetDummy", "respawn", "obelisk", "soulstone", "inactiveRift", "nextRift", "upcomingRift", "riftPortal", "npc", "bank", "demon", "recycler", "upgrade", "craft", "glory", "infusion"]) {
            for (point in points) if (point.kind == kind) {
                point.elevation = elevationDirection(point.z, heroHeight);
                hitPoints.push(point);
            }
        }
        var playerPoints = [for (point in hitPoints) if (point.kind == "player") point];
        var mapPoints = [for (point in hitPoints) if (point.kind != "player" && !isNpc(point.kind)) point];
        var npcPoints = [for (point in hitPoints) if (isNpc(point.kind)) point];
        updateIcons(playerPoints, playerIconMarkers, playerIcons, scale);
        updateIcons(mapPoints, mapIconMarkers, mapIcons, scale);
        updateIcons(npcPoints, npcIconMarkers, npcIcons, scale);
        updateElevations([for (point in playerPoints) if (point.elevation != 0) point],
            playerElevationMarkers, playerElevations, scale);
        updateElevations([for (point in mapPoints) if (point.elevation != 0) point],
            mapElevationMarkers, mapElevations, scale);
        updateElevations([for (point in npcPoints) if (point.elevation != 0) point],
            npcElevationMarkers, npcElevations, scale);
    }

    function updateIcons(points:Array<MapPoint>, pool:Array<IconMarker>, parent:Dynamic, scale:Float):Void {
        trimIcons(pool, points.length);
        while (pool.length < points.length)
            pool.push({icon: G.create("h2d.Graphics", [parent]), key: "", directional: false});
        for (i in 0...points.length) {
            var point = points[i], marker = pool[i];
            var key = point.kind + (point.sparkling == true ? ":spark" : "");
            // Draw in local pixels once per appearance, then reuse the geometry
            // as the marker moves, zooms or counter-rotates with the map.
            if (marker.key != key) {
                graphics = marker.icon;
                G.call("h2d.Graphics", "clear", graphics);
                drawIcon({kind: point.kind, sparkling: point.sparkling, heading: 0, x: 0, y: 0, z: 0});
                marker.key = key;
            }
            marker.directional = point.kind == "player";
            G.call("h2d.Object", "setPosition", marker.icon, [point.x, point.y]);
            G.call("h2d.Object", "setScale", marker.icon, [markerScale / scale]);
            G.call("h2d.Object", "set_rotation", marker.icon, [marker.directional ? point.heading : -mapRotation]);
        }
    }

    function trimIcons(pool:Array<IconMarker>, count:Int):Void {
        while (pool.length > count) G.call("h2d.Object", "remove", pool.pop().icon);
    }

    function drawIcon(point:MapPoint):Void {
        var kind = point.kind;
        if (kind == "chest" || kind == "vaultChest" || kind == "recipeChest") {
            ChestIcons.draw(graphics, kind, markerRadius(kind));
            return;
        }
        if (kind == "obelisk" || kind == "dungeon" || kind == "soulstone" || kind == "secretOrb" || kind == "targetDummy"
            || kind == "riftPortal" || kind == "upcomingRift" || kind == "inactiveRift" || kind == "nextRift"
            || kind == "glory" || kind == "infusion" || kind == "craft" || kind == "upgrade" || kind == "recycler") {
            LandmarkIcons.draw(graphics, kind, markerRadius(kind));
            return;
        }
        var color = switch kind {
            case "plant", "companion": 0x77df81;
            case "ore": 0xb7bcc7;
            case "activity": 0x7f3e91;
            case "ascension": 0xffc45a;
            case "enemy", "boss": 0xff6860;
            case "respawn": 0xffffff;
            case "npc": 0xffdf78;
            case "bank": 0xffdc42;
            case "demon": 0xe8a1ff;
            default: 0x70d8ff;
        };
        var sparkling = point.sparkling == true;
        var radius = markerRadius(kind);
        if (kind == "companion" && sparkling) LandmarkIcons.sparklingRing(graphics, radius + 3.5);
        G.call("h2d.Graphics", "beginFill", graphics, [0x201b1b, 0.95]);
        shape(point, radius + (sparkling && kind != "companion" ? 3.5 : 1));
        G.call("h2d.Graphics", "endFill", graphics);
        if (sparkling && (kind == "enemy" || kind == "boss")) {
            G.call("h2d.Graphics", "beginFill", graphics, [0xffdc42, 1.0]);
            shape(point, radius + 2.5);
            G.call("h2d.Graphics", "endFill", graphics);
        }
        G.call("h2d.Graphics", "beginFill", graphics, [color, 1.0]);
        shape(point, radius);
        G.call("h2d.Graphics", "endFill", graphics);
        if (kind == "activity") {
            G.call("h2d.Graphics", "beginFill", graphics, [0xffffff, 1.0]);
            for (quarter in 0...4)
                polygon(point, radius, [0, 0, -0.25, -0.25, 0, -0.84, 0.25, -0.25], quarter * Math.PI / 2);
            G.call("h2d.Graphics", "endFill", graphics);
            G.call("h2d.Graphics", "beginFill", graphics, [color, 1.0]);
            polygon(point, radius, [0, -0.19, 0.19, 0, 0, 0.19, -0.19, 0]);
            G.call("h2d.Graphics", "endFill", graphics);
        }
        if (kind == "ascension") {
            G.call("h2d.Graphics", "beginFill", graphics, [0x965321, 1.0]);
            G.call("h2d.Graphics", "drawCircle", graphics, [0.0, 0.0, radius * 0.45, 32]);
            G.call("h2d.Graphics", "endFill", graphics);
            G.call("h2d.Graphics", "beginFill", graphics, [0x31eeff, 1.0]);
            G.call("h2d.Graphics", "drawCircle", graphics, [0.0, 0.0, radius * 0.32, 32]);
            G.call("h2d.Graphics", "endFill", graphics);
            G.call("h2d.Graphics", "beginFill", graphics, [0xd6fcff, 1.0]);
            G.call("h2d.Graphics", "drawCircle", graphics, [-radius * 0.08, -radius * 0.08, radius * 0.13, 24]);
            G.call("h2d.Graphics", "endFill", graphics);
        }
        if ((isNpc(kind) && kind != "npc") || kind == "plant" || kind == "ore") {
            G.call("h2d.Graphics", "beginFill", graphics, [0x201b1b, 1.0]);
            detail(point, radius);
            G.call("h2d.Graphics", "endFill", graphics);
        }
    }

    function shape(point:MapPoint, r:Float):Void {
        var x = point.x, y = point.y;
        switch point.kind {
            case "player":
                arrowShape(graphics, point.x, point.y, r, point.heading);
            case "plant":
                // A pointed leaf with a short stem, readable at minimap scale.
                polygon(point, r, [-0.8, 0.65, -0.85, 0.05, -0.55, -0.55, 0.05, -0.85,
                    0.9, -0.9, 0.85, -0.05, 0.55, 0.55, -0.05, 0.85]);
                polygon(point, r, [-1, 0.85, -0.1, -0.05, 0.05, 0.1, -0.85, 1]);
            case "ore":
                polygon(point, r, [-1, 0.55, -0.9, -0.25, -0.35, -0.85,
                    0.35, -0.75, 0.9, -0.2, 1, 0.55, 0.3, 0.85, -0.55, 0.85]);
            case "activity":
                G.call("h2d.Graphics", "drawRect", graphics, [x - r, y - r, 2 * r, 2 * r]);
            case "ascension":
                // Gold housing and four floating shards around a cyan core.
                polygon(point, r, [-0.55, -0.4, -0.4, -0.55, 0.4, -0.55, 0.55, -0.4,
                    0.55, 0.4, 0.4, 0.55, -0.4, 0.55, -0.55, 0.4]);
                for (quarter in 0...4)
                    polygon(point, r, [-0.28, -0.75, 0, -1, 0.28, -0.75, 0, -0.62], quarter * Math.PI / 2);
            case "companion":
                // Four toes and a rounded triangular pad form a flat pawprint.
                for (side in [-1, 1]) {
                    G.call("h2d.Graphics", "drawCircle", graphics, [x + side * 0.7 * r, y - 0.16 * r, 0.23 * r, 24]);
                    G.call("h2d.Graphics", "drawCircle", graphics, [x + side * 0.29 * r, y - 0.63 * r, 0.23 * r, 24]);
                }
                polygon(point, r, [0, -0.12, 0.24, -0.02, 0.41, 0.2, 0.58, 0.48,
                    0.57, 0.66, 0.44, 0.79, -0.44, 0.79, -0.57, 0.66, -0.58, 0.48,
                    -0.41, 0.2, -0.24, -0.02]);
            case "bank":
                // A bold dollar sign, built as filled geometry at any zoom.
                polygon(point, r, [0.7, -0.8, -0.35, -0.8, -0.7, -0.5, -0.7, -0.1,
                    -0.35, 0.2, 0.35, 0.2, 0.4, 0.3, 0.4, 0.45, 0.3, 0.55,
                    -0.7, 0.55, -0.7, 0.85, 0.4, 0.85, 0.75, 0.55, 0.75, 0.1,
                    0.4, -0.15, -0.3, -0.15, -0.4, -0.25, -0.4, -0.4, -0.3, -0.5, 0.7, -0.5]);
                G.call("h2d.Graphics", "drawRect", graphics, [x - 0.13 * r, y - 1.05 * r, 0.26 * r, 2.15 * r]);
            case "demon":
                // Keep the face and horns convex so both sides triangulate
                // independently at world-map coordinates.
                polygon(point, r, [-0.8, -0.35, 0.8, -0.35, 0.8, 0.25,
                    0.45, 0.75, 0, 1, -0.45, 0.75, -0.8, 0.25]);
                polygon(point, r, [-0.9, -1, -0.2, -0.3, -0.8, 0.05]);
                polygon(point, r, [0.9, -1, 0.8, 0.05, 0.2, -0.3]);
            case "respawn":
                G.call("h2d.Graphics", "drawRect", graphics, [x - r / 3, y - r, r * 2 / 3, r * 2]);
                G.call("h2d.Graphics", "drawRect", graphics, [x - r, y - r / 3, r * 2, r * 2 / 3]);
            case "npc":
                G.call("h2d.Graphics", "drawCircle", graphics, [x, y, r, 32]);
            default:
                G.call("h2d.Graphics", "drawCircle", graphics, [x, y, r, 32]);
        }
    }

    public static function drawPlayerArrow(graphics:Dynamic, radius:Float, color:Int):Void {
        G.call("h2d.Graphics", "beginFill", graphics, [0x201b1b, 1.0]);
        arrowShape(graphics, 0, 0, radius + 1, 0);
        G.call("h2d.Graphics", "endFill", graphics);
        G.call("h2d.Graphics", "beginFill", graphics, [color, 1.0]);
        arrowShape(graphics, 0, 0, radius, 0);
        G.call("h2d.Graphics", "endFill", graphics);
    }

    static function drawAlertArrow(graphics:Dynamic):Void {
        LandmarkIcons.sparklingRing(graphics, 12);
        LandmarkIcons.alertArrow(graphics, 7.7, 0xffdc42);
    }

    static function arrowShape(graphics:Dynamic, x:Float, y:Float, radius:Float, heading:Float):Void {
        // Two solid triangles with one color, pointing along +X like rotationZ.
        var c = Math.cos(heading) * radius, s = Math.sin(heading) * radius;
        for (side in [-1, 1]) {
            G.call("h2d.Graphics", "moveTo", graphics, [x + c, y + s]);
            if (side < 0) G.call("h2d.Graphics", "lineTo", graphics, [x - 0.45 * c, y - 0.45 * s]);
            G.call("h2d.Graphics", "lineTo", graphics, [x - 0.8 * c - side * 0.7 * s, y - 0.8 * s + side * 0.7 * c]);
            if (side > 0) G.call("h2d.Graphics", "lineTo", graphics, [x - 0.45 * c, y - 0.45 * s]);
            G.call("h2d.Graphics", "lineTo", graphics, [x + c, y + s]);
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
            case "plant":
                polygon(point, r, [-0.65, 0.5, 0.5, -0.6, 0.65, -0.5, -0.5, 0.65]);
            case "ore":
                polygon(point, r, [-0.55, -0.5, -0.4, -0.6, -0.1, -0.1, -0.3, 0]);
                polygon(point, r, [-0.3, -0.15, -0.1, -0.1, -0.65, 0.45, -0.8, 0.35]);
                polygon(point, r, [-0.1, -0.1, 0.65, -0.1, 0.7, 0.1, -0.1, 0.1]);
            case "demon":
                polygon(point, r, [-0.6, -0.05, -0.15, 0.1, -0.2, 0.3, -0.5, 0.25]);
                polygon(point, r, [0.6, -0.05, 0.15, 0.1, 0.2, 0.3, 0.5, 0.25]);
            default:
        }
    }
}
