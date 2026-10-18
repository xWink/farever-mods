package minimap;

import minimap.GameAccess as G;
import minimap.MinimapSettings;
import minimap.MarkerDetails.MarkerHover;
import minimap.RiftMarkers.RiftPoint;

private typedef MarkerTransform = {
    var ?lastX:Float;
    var ?lastY:Float;
    var ?lastScale:Float;
    var ?lastAngle:Float;
}

private typedef ElevationMarker = { > MarkerTransform,
    var root:Dynamic;
    var arrow:Dynamic;
}

private typedef IconMarker = { > MarkerTransform,
    var icon:Dynamic;
    var key:String;
    var directional:Bool;
}

/** Read-only map markers. Live entities are sampled five times a second. */
class MinimapMarkers {
    public var healthy(default, null):Bool = false;
    public var revision(default, null):Int = 0;
    public var points(get, never):Array<MapPoint>;
    function get_points():Array<MapPoint> return sampledPoints;
    public var viewRevision(default, null):Int = 0;
    var sampledPoints:Array<MapPoint> = [];
    var iconCache:MainMapIconCache;
    var viewport:Null<{x:Float, y:Float, width:Float, height:Float}>;
    var viewportDirty:Bool = false;

    public function setViewport(x:Float, y:Float, width:Float, height:Float):Void {
        if (viewport != null && viewport.x == x && viewport.y == y && viewport.width == width && viewport.height == height) return;
        viewport = {x:x, y:y, width:width, height:height};
        viewportDirty = true;
    }
    public var pointFilter:MapPoint->Bool;
    public var ownFirst:Bool = false;
    public var showOwn:Bool = true;
    public var obeliskScale:Float = 1;
    public var highlightObelisks:Bool = false;
    public var ignoreHeightFilter:Bool = false;
    var partyIcons:Dynamic;
    var partyElevations:Dynamic;
    var partyIconMarkers:Array<IconMarker> = [];
    var partyElevationMarkers:Array<ElevationMarker> = [];
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
    final sizeMultiplier:Float;
    var heroHeight:Float = Math.NaN;
    var alertLayer:Dynamic;
    var partyAlertLayer:Dynamic;
    var alertTargets:Array<MapPoint> = [];
    var alertArrows:Array<IconMarker> = [];
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
    static final DRAW_ORDER = ["player", "activity", "ascension", "dungeon", "plant", "ore", "secretOrb", "chest", "vaultChest", "recipeChest", "companion", "enemy", "boss", "targetDummy", "respawn", "obelisk", "soulstone", "inactiveRift", "nextRift", "upcomingRift", "riftPortal"].concat(NpcMarkers.KINDS);

    public function new(parent:Dynamic, foreground:Dynamic, overlay:Dynamic, level:String, sizeMultiplier:Float = 1, ?priorityParent:Dynamic, ?iconCache:MainMapIconCache) {
        this.level = level;
        this.sizeMultiplier = sizeMultiplier;
        this.iconCache = iconCache;
        // Ordinary players stay below landmarks. Party members get a separate
        // foreground layer on both maps, above services and other markers.
        playerIcons = G.create("h2d.Object", [parent]);
        playerElevations = G.create("h2d.Object", [parent]);
        mapIcons = G.create("h2d.Object", [foreground]);
        mapElevations = G.create("h2d.Object", [foreground]);
        npcIcons = G.create("h2d.Object", [foreground]);
        npcElevations = G.create("h2d.Object", [foreground]);
        partyIcons = G.create("h2d.Object", [priorityParent == null ? foreground : priorityParent]);
        partyElevations = G.create("h2d.Object", [priorityParent == null ? foreground : priorityParent]);
        alertLayer = G.create("h2d.Object", [overlay]);
        partyAlertLayer = G.create("h2d.Object", [overlay]);
    }

    public function setPartyParent(parent:Dynamic):Void {
        G.call("h2d.Object", "addChild", parent, [partyIcons]);
        G.call("h2d.Object", "addChild", parent, [partyElevations]);
    }

    public function update(hero:Dynamic, config:MinimapSettings, x:Float, y:Float, radius:Float, scale:Float, rotation:Float, rifts:RiftMarkers):Void {
        this.rifts = rifts;
        if (mapRotation != rotation) {
            mapRotation = rotation;
            for (pool in [mapIconMarkers, npcIconMarkers]) for (marker in pool) if (!marker.directional) {
                G.call("h2d.Object", "set_rotation", marker.icon, [-rotation]);
                marker.lastAngle = -rotation;
            }
            for (pool in [partyElevationMarkers, playerElevationMarkers, mapElevationMarkers, npcElevationMarkers]) for (marker in pool) {
                G.call("h2d.Object", "set_rotation", marker.root, [-rotation]);
                marker.lastAngle = -rotation;
            }
        }
        var now = haxe.Timer.stamp();
        var nextLayer = G.field(hero, "layer");
        var nextMarkerScale = config.markerScale / 100 * sizeMultiplier;
        var changed = previousConfig != config || previousRadius != radius
            || lastHero != hero || layer != nextLayer || markerScale != nextMarkerScale;
        if (!changed && now < nextRefresh) {
            // Smooth big-map zoom changes transforms, not the 5 Hz world scan.
            if (viewport != null && (viewportDirty || previousScale != scale)) {
                draw(sampledPoints, scale);
                previousScale = scale;
            } else if (previousScale != scale) rescale(scale);
            return;
        }
        previousConfig = config; previousScale = scale; previousRadius = radius;
        markerScale = nextMarkerScale;
        lastHero = hero; layer = nextLayer;
        nextRefresh = now + 0.2;
        heroHeight = G.number(G.field(hero, "posz"), Math.NaN);
        try {
            refreshLandmarks();
            var points = collect(hero, config, x, y, radius + 12 * markerScale / scale);
            if (pointFilter != null) {
                points = points.filter(pointFilter);
                // Companion alerts intentionally bypass marker filters. Party alerts do not.
                alertTargets = alertTargets.filter(point -> point.kind != "player" || pointFilter(point));
            }
            sampledPoints = points;
            draw(points, scale);
            healthy = true;
            revision++;
        } catch (error:Dynamic) {
            healthy = false;
            sampledPoints = [];
            hitPoints = [];
            alertTargets = [];
            // An optional marker source must not take down the working map.
            trimIcons(partyIconMarkers, 0);
            trimElevations(partyElevationMarkers, 0);
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

    function rescale(scale:Float):Void {
        previousScale = scale;
        for (pool in [playerIconMarkers, partyIconMarkers, mapIconMarkers, npcIconMarkers])
            for (marker in pool) {
                G.call("h2d.Object", "setScale", marker.icon, [markerScale / scale]);
                marker.lastScale = markerScale / scale;
            }
        for (pool in [playerElevationMarkers, partyElevationMarkers, mapElevationMarkers, npcElevationMarkers])
            for (marker in pool) {
                G.call("h2d.Object", "setScale", marker.root, [markerScale / scale]);
                marker.lastScale = markerScale / scale;
            }
    }

    public function updateAlerts(config:MinimapSettings, x:Float, y:Float, size:Int, scale:Float, rotation:Float, rifts:RiftMarkers):Void {
        updateRiftAlert(config, x, y, size, scale, rotation, rifts);
        var count = alertTargets.length;
        while (alertArrows.length > count) {
            G.call("h2d.Object", "remove", alertArrows.pop().icon);
        }
        while (alertArrows.length < count) {
            var arrow = G.create("h2d.Graphics", [alertLayer]);
            alertArrows.push({icon: arrow, key: "", directional: true});
        }
        alertPositions = [];
        if (count == 0) return;
        // Keep geometry cached; only position and rotate the few active arrows
        // each frame so they follow movement and camera rotation smoothly.
        var c = Math.cos(rotation), s = Math.sin(rotation);
        var north = config.showNorthIndicator ? MinimapGeometry.north(size, config.circular, rotation, markerScale) : null;
        for (i in 0...count) {
            var point = alertTargets[i];
            var party = point.partyMember == true;
            var marker = alertArrows[i], arrow = marker.icon;
            var key = party ? "party" : "companion";
            if (marker.key != key) {
                G.call("h2d.Object", "addChild", party ? partyAlertLayer : alertLayer, [arrow]);
                G.call("h2d.Graphics", "clear", arrow);
                if (party) LandmarkIcons.alertArrow(arrow, 9, LandmarkIcons.PLAYER_COLOR, LandmarkIcons.PARTY_COLOR);
                else drawAlertArrow(arrow);
                marker.key = key;
            }
            var dx = (point.x - x) * scale, dy = (point.y - y) * scale;
            var sx = dx * c - dy * s, sy = dx * s + dy * c;
            // Height filtering affects the map icon, never its guidance arrow.
            var hasMarker = point.hasMarker == true && !MarkerDetails.hidden(point.z, heroHeight,
                config.hideVerticallyDistantMarkers, config.verticallyDistantThreshold);
            var visible = (party ? config.showPlayers : config.sparklingCompanionAlerts)
                && G.field(point.entity, "removed") != true && MinimapGeometry.showAlert(hasMarker,
                    sx, sy, size, config.circular, (markerRadius(point.kind) + (party ? 4.5 : 3.5)) * markerScale);
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
        var i = alertPositions.length;
        while (i > 0) {
            var alert = alertPositions[--i];
            if (alert.point.partyMember == true && nearCursor(x, y, alert.x, alert.y, 12 * markerScale)
                && G.field(alert.point.entity, "removed") != true)
                return MarkerDetails.hover(markerName(alert.point), alert.point);
        }
        if (riftAlertPosition != null && nearCursor(x, y, riftAlertPosition.x, riftAlertPosition.y, 12 * markerScale))
            return MarkerDetails.hover(RiftMarkers.name(riftAlertPosition.point.kind), riftAlertPosition.point);
        i = alertPositions.length;
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
            var hasMarker = !MarkerDetails.hidden(target.z, heroHeight,
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
                if (kind == "npc" && !NpcMarkers.availableDefinition(inf)) continue;
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
            var partyMember = kind == "player" && PlayerMarkers.isPartyMember(hero, unit);
            if (!nearby && (kind == "player" ? !partyMember : !config.sparklingCompanionAlerts)) continue;
            var inf = kind == "enemy" ? G.field(unit, "inf") : null;
            var flags = G.integer(G.field(inf, "flags"));
            var sparkling = (flags & (1 << 22)) != 0;
            var companion = G.text(G.field(inf, "type")) == "Critter";
            var alert = partyMember || (config.sparklingCompanionAlerts && companion && sparkling);
            var point:MapPoint = null;
            // Alerts scan every replicated unit, with no minimap-distance cutoff.
            if (!nearby && !alert) continue;
            if (G.field(unit, "dying") == true || G.call("ent.GameObject", "isDead", unit) == true) continue;
            if (partyMember) {
                point = {kind: kind, x: px, y: py, z: G.number(G.field(unit, "posz"), Math.NaN),
                    entity: unit, partyMember: true, heading: G.number(G.field(unit, "rotationZ"))};
                alertTargets.push(point);
                if (!nearby) continue;
            }
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
                friend: kind == "player" && PlayerMarkers.isFriend(hero, unit),
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
                var inf = G.field(element, "inf");
                liveNpcs[key] = active ? {kind: NpcMarkers.forProgress(npcKind(inf), inf, progress, !config.hideCompletedActivities), x: px, y: py,
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
            if (show && near(point.x, point.y, x, y, radius)) {
                if (isNpc(point.kind) && !NpcMarkers.eventVisible(point.inf, G.field(layer, "worldEvents"), worldEvents)) continue;
                if (isNpc(point.kind)) point.kind = NpcMarkers.forProgress(npcKind(point.inf), point.inf, progress, !config.hideCompletedActivities);
                // Definitions are cached, but unlocks belong to the current
                // character and must refresh after activating a respawn point.
                if (point.kind == "respawn") point.respawnUnlocked = RespawnMarkers.unlocked(point.inf, progress);
                points.push(point);
            }
        }
        for (point in liveNpcs) if (point != null && near(point.x, point.y, x, y, radius)) points.push(point);
        if (config.showSecretOrbs && progress != null) for (id => point in secretOrbs) {
            if (!near(point.x, point.y, x, y, radius)) continue;
            // Discovery can precede collection. Keep the marker until the
            // character has actually completed this orb's interaction.
            if (!SecretOrbMarkers.collected(progress, id)) points.push(point);
        }
        {
            // Dungeons and rifts remain available even with Activities off.
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
            !ignoreHeightFilter && config.hideVerticallyDistantMarkers, config.verticallyDistantThreshold);
    }

    function refreshActivities():Void {
        var source = G.current("HActivity", "allActivities");
        var orbs = G.current("HElement", "instanceOrbs");
        var count = G.integer(G.field(orbs, "length"));
        if (source == activitySource && orbs == activityOrbSource && count == activityOrbCount) return;
        activitySource = source; activityOrbSource = orbs; activityOrbCount = count;
        activities = [];
        if (source == null) return;
        ActivityMarkers.prepareIcons();
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
            activities.push({kind: kind, inf: inf, activityIcon: ActivityMarkers.icon(inf),
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
            activities.push({kind: ActivityMarkers.kind(activityInf), inf: activityInf, activityIcon: ActivityMarkers.icon(activityInf),
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

    static inline function family(object:Dynamic):String return G.family(object);

    static function near(px:Float, py:Float, x:Float, y:Float, radius:Float):Bool
        return Math.abs(px - x) <= radius && Math.abs(py - y) <= radius;

    static function markerRadius(kind:String):Float return switch kind {
        case "bank", "player", "activity", "ascension", "companion", "quest": 7;
        case "plant", "ore", "boss": 5;
        case "obelisk", "dungeon", "soulstone", "secretOrb", "glory", "chest", "vaultChest", "recipeChest": 8;
        case "targetDummy", "upcomingRift", "infusion", "craft", "recycler", "respawn", "demon": 9;
        case "riftPortal": 11;
        case "inactiveRift", "nextRift", "upgrade", "soulWell": 10;
        default: 3.5;
    };

    static function elevationDirection(z:Float, heroZ:Float):Int {
        var difference = z - heroZ;
        // Missing height data stays unknown rather than becoming sea level.
        if (!Math.isFinite(difference)) return 0;
        return difference > 15 ? 1 : difference < -15 ? -1 : 0;
    }

    static function outlinedPlayer(point:MapPoint):Bool
        return point.kind == "player" && (point.partyMember == true || point.friend == true);

    static function elevationOffset(point:MapPoint):Float
        return markerRadius(point.kind) + (outlinedPlayer(point) ? 4.5 : point.sparkling == true ? 3.5 : 1) + 3;

    function updateElevations(points:Array<MapPoint>, pool:Array<ElevationMarker>, parent:Dynamic, scale:Float):Void {
        trimElevations(pool, points.length);
        while (pool.length < points.length) {
            var root = G.create("h2d.Object", [parent]);
            var arrow = iconCache == null ? G.create("h2d.Graphics", [root])
                : iconCache.bitmap(root, "height", g -> drawPlayerArrow(g, 4, 0xfff3d6));
            if (iconCache == null) drawPlayerArrow(arrow, 4, 0xfff3d6);
            pool.push({root: root, arrow: arrow});
        }
        for (i in 0...points.length) {
            var point = points[i], marker = pool[i];
            transform(marker, marker.root, point.x, point.y, markerScale / scale, -mapRotation);
            var offset = elevationOffset(point), angle = -point.elevation * Math.PI / 2;
            if (G.field(marker.arrow, "x") != offset) G.call("h2d.Object", "setPosition", marker.arrow, [offset, 0.]);
            if (G.field(marker.arrow, "rotation") != angle) G.call("h2d.Object", "set_rotation", marker.arrow, [angle]);
        }
    }

    function trimElevations(pool:Array<ElevationMarker>, count:Int):Void {
        while (pool.length > count) G.call("h2d.Object", "remove", pool.pop().root);
    }

    public function hoverAt(x:Float, y:Float, scale:Float, heroX:Float, heroY:Float, hero:Dynamic, partyOnly:Bool = false):Null<MarkerHover> {
        if (showOwn && ownFirst && !partyOnly && nearCursor(x, y, heroX, heroY, 11 * markerScale / scale)) return heroHover(hero, heroX, heroY);
        var checkHero = showOwn && !ownFirst;
        var i = hitPoints.length;
        // Reverse visual priority, including the separate party layer.
        while (i > 0) {
            var point = hitPoints[--i];
            if (partyOnly && point.partyMember != true) return null;
            if (checkHero && point.kind == "player" && point.partyMember != true) {
                checkHero = false;
                if (nearCursor(x, y, heroX, heroY, 11 * markerScale / scale)) return heroHover(hero, heroX, heroY);
            }
            var r = (markerRadius(point.kind) * (point.kind == "obelisk" ? obeliskScale : 1) + (outlinedPlayer(point) ? 4.5 : point.sparkling == true ? 2.5 : 0) + 2) * markerScale / scale;
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
        return !partyOnly && checkHero && nearCursor(x, y, heroX, heroY, 11 * markerScale / scale) ? heroHover(hero, heroX, heroY) : null;
    }

    function heroHover(hero:Dynamic, x:Float, y:Float):MarkerHover
        return {name: G.text(G.field(hero, "name")), x: x, y: y, z: G.number(G.field(hero, "posz"), Math.NaN)};

    static function nearCursor(x:Float, y:Float, px:Float, py:Float, radius:Float):Bool {
        var dx = x - px, dy = y - py;
        return dx * dx + dy * dy <= radius * radius;
    }

    function markerName(point:MapPoint):String {
        if (point.kind == "soulstone") {
            if (point.name == null) point.name = SoulstoneMarkers.name(point.inf);
            return point.name;
        }
        if (point.kind == "secretOrb") return "Secret Orb";
        if (point.kind == "recipeChest") return "Recipe Chest";
        if (point.kind == "respawn") return RespawnMarkers.name(point.respawnUnlocked == true);
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
            case "obelisk": "Obelisk";
            case "soulstone": "Soulstone";
            case "bank": "Guild Merchant";
            case "demon": "Demon Huntress";
            case "recycler": "Spark Recycler";
            case "upgrade": "Weapon Upgrade";
            case "craft": "Crafting Station";
            case "glory": "Glory Merchant";
            case "infusion": "Infusion Crucible";
            case "soulWell": "Soul Well";
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
        viewportDirty = false;
        viewRevision++;
        hitPoints = [];
        // Cull before sorting or touching native artwork. The complete sample
        // remains available for panning and native click-target reconciliation.
        var groups:Map<String, Array<MapPoint>> = [];
        var partyPoints:Array<MapPoint> = [];
        var padding = 32 * markerScale; // Includes outlines and height arrows.
        for (point in points) {
            if (viewport != null) {
                var px = point.x * scale + viewport.x, py = point.y * scale + viewport.y;
                if (px < -padding || py < -padding || px > viewport.width + padding || py > viewport.height + padding) continue;
            }
            point.elevation = elevationDirection(point.z, heroHeight);
            if (point.partyMember == true) partyPoints.push(point);
            else {
                var group = groups[point.kind];
                if (group == null) { group = []; groups[point.kind] = group; }
                group.push(point);
            }
        }
        for (kind in DRAW_ORDER) {
            var group = groups[kind];
            if (group != null) for (point in group) hitPoints.push(point);
        }
        for (point in partyPoints) hitPoints.push(point);
        var playerPoints = [for (point in hitPoints) if (point.kind == "player" && point.partyMember != true) point];
        var mapPoints = [for (point in hitPoints) if (point.kind != "player" && !isNpc(point.kind)) point];
        var npcPoints = [for (point in hitPoints) if (isNpc(point.kind)) point];
        updateIcons(partyPoints, partyIconMarkers, partyIcons, scale);
        updateElevations([for (point in partyPoints) if (point.elevation != 0) point], partyElevationMarkers, partyElevations, scale);
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
            pool.push({icon: G.create(iconCache == null ? "h2d.Graphics" : "h2d.Bitmap",
                iconCache == null ? [parent] : [null, parent]), key: "", directional: false});
        for (i in 0...points.length) {
            var point = points[i], marker = pool[i];
            var key = point.kind + (point.sparkling == true ? ":spark" : "") + (point.partyMember == true ? ":party" : "")
                + (point.activityIcon == null ? "" : ":" + point.activityIcon)
                + (point.kind == "obelisk" && highlightObelisks ? ":travel" : "")
                + (point.friend == true ? ":friend" : "")
                + (point.respawnUnlocked == true ? ":unlocked" : "");
            // Draw in local pixels once per appearance, then reuse the geometry
            // as the marker moves, zooms or counter-rotates with the map.
            if (marker.key != key) {
                var paint = (target:Dynamic) -> {
                    graphics = target;
                    drawIcon({kind: point.kind, sparkling: point.sparkling, partyMember: point.partyMember, friend: point.friend,
                        respawnUnlocked: point.respawnUnlocked, activityIcon: point.activityIcon, heading: 0, x: 0, y: 0, z: 0});
                };
                if (iconCache == null) {
                    G.call("h2d.Graphics", "clear", marker.icon);
                    paint(marker.icon);
                } else {
                    iconCache.apply(marker.icon, key, paint);
                }
                marker.key = key;
            }
            marker.directional = point.kind == "player";
            transform(marker, marker.icon, point.x, point.y, markerScale * (point.kind == "obelisk" ? obeliskScale : 1) / scale, marker.directional ? point.heading : -mapRotation);
        }
    }

    static function transform(state:MarkerTransform, object:Dynamic, x:Float, y:Float, scale:Float, angle:Float):Void {
        if (state.lastX != x || state.lastY != y) {
            G.call("h2d.Object", "setPosition", object, [x, y]);
            state.lastX = x; state.lastY = y;
        }
        if (state.lastScale != scale) {
            G.call("h2d.Object", "setScale", object, [scale]);
            state.lastScale = scale;
        }
        if (state.lastAngle != angle) {
            G.call("h2d.Object", "set_rotation", object, [angle]);
            state.lastAngle = angle;
        }
    }

    function trimIcons(pool:Array<IconMarker>, count:Int):Void {
        while (pool.length > count) G.call("h2d.Object", "remove", pool.pop().icon);
    }

    public function createFilterIcon(parent:Dynamic, kind:String):Dynamic {
        return iconCache.bitmap(parent, kind, target -> drawFilterIcon(target, kind), 4);
    }

    public function drawFilterIcon(target:Dynamic, kind:String):Void {
        var previous = graphics;
        graphics = target;
        drawIcon({kind:kind, x:0, y:0, z:0, heading:0});
        graphics = previous;
    }

    function drawIcon(point:MapPoint):Void {
        var kind = point.kind;
        if (kind == "obelisk" && highlightObelisks) {
            G.call("h2d.Graphics", "lineStyle", graphics, [2.8, 0x62472a, 1.]);
            G.call("h2d.Graphics", "drawCircle", graphics, [0., 0., 11.5, 48]);
            G.call("h2d.Graphics", "lineStyle", graphics, [1.6, 0xffdc42, 1.]);
            G.call("h2d.Graphics", "drawCircle", graphics, [0., 0., 11.5, 48]);
            G.call("h2d.Graphics", "lineStyle", graphics, [0., 0, 0.]);
        }
        if (kind == "quest" || kind == "activity" && point.activityIcon != null && point.activityIcon != "activity") {
            ActivityIcons.draw(graphics, kind == "quest" ? "quest" : point.activityIcon, markerRadius(kind));
            return;
        }
        if (kind == "respawn") {
            LandmarkIcons.respawnPoint(graphics, markerRadius(kind), point.respawnUnlocked == true);
            return;
        }
        if (outlinedPlayer(point)) {
            LandmarkIcons.outlinedPlayer(graphics, markerRadius(kind),
                point.partyMember == true ? LandmarkIcons.PARTY_COLOR : LandmarkIcons.SPARKLING_COLOR);
            return;
        }
        if (kind == "chest" || kind == "vaultChest" || kind == "recipeChest") {
            ChestIcons.draw(graphics, kind, markerRadius(kind));
            return;
        }
        if (kind == "obelisk" || kind == "dungeon" || kind == "soulstone" || kind == "secretOrb" || kind == "targetDummy"
            || kind == "riftPortal" || kind == "upcomingRift" || kind == "inactiveRift" || kind == "nextRift"
            || kind == "glory" || kind == "infusion" || kind == "craft" || kind == "upgrade" || kind == "recycler"
            || kind == "soulWell" || kind == "demon") {
            LandmarkIcons.draw(graphics, kind, markerRadius(kind));
            return;
        }
        var color = switch kind {
            case "plant", "companion": 0x77df81;
            case "ore": 0xb7bcc7;
            case "activity": 0x7f3e91;
            case "ascension": 0xffc45a;
            case "enemy", "boss": 0xff6860;
            case "npc": 0xffdf78;
            case "bank": 0xffdc42;
            default: LandmarkIcons.PLAYER_COLOR;
        };
        var sparkling = point.sparkling == true;
        var radius = markerRadius(kind);
        if (kind == "companion" && sparkling) LandmarkIcons.sparklingRing(graphics, radius + 3.5);
        G.call("h2d.Graphics", "beginFill", graphics, [0x201b1b, 0.95]);
        shape(point, radius + (sparkling && kind != "companion" ? 3.5 : 1));
        G.call("h2d.Graphics", "endFill", graphics);
        if (sparkling && (kind == "enemy" || kind == "boss")) {
            G.call("h2d.Graphics", "beginFill", graphics, [LandmarkIcons.SPARKLING_COLOR, 1.0]);
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
        LandmarkIcons.alertArrow(graphics, 7.7, LandmarkIcons.SPARKLING_COLOR);
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
            var j = (i * 2) % vertices.length;
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
            default:
        }
    }
}
