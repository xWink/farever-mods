import minimap.BigMapView;
import minimap.MinimapMarkers;
import minimap.MinimapSettings;
import minimap.GameAccess as G;

@:access(minimap.BigMapView)
@:access(minimap.MinimapMarkers)
class BigMapTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, message:String):Void {
        checks++;
        if (a != b) throw message + ': expected ' + b + ', got ' + a;
    }
    static function config():MinimapSettings return cast {
        enabled: true, overrideBigMapMarkers: true, markerScale: 100.,
        showPlayers: true, showPlants: true, showOre: true, showEnemies: false,
        showNpcs: true, showChests: true, showCompanions: true, hideCollectedCompanions: true,
        sparklingCompanionAlerts: false, showRespawnPoints: true, showObelisks: true,
        showSoulstoneCircles: true, showSecretOrbs: true, showActivities: true,
        hideInactiveRifts: false, hideCompletedActivities: true, hideAscensions: false, hideDungeons: false,
        hideVerticallyDistantMarkers: false, verticallyDistantThreshold: 15.,
        hideCopper: false, hideIron: false, hideTin: false, hideTungstene: false,
        hideMadrigold: false, hideLavendula: false, hideAncientThyme: false, hideZealotus: false
    };
    static function change(c:MinimapSettings, key:String, value:Dynamic):MinimapSettings {
        var next = Reflect.copy(c);
        Reflect.setField(next, key, value);
        return next;
    }
    static function definition(id:String, x:Float, y:Float, z:Float, type:Int = 0):Dynamic
        return {mapId: 'World/W1_Siagarta', inf: {id: id, type: type, props: {}}, prefab: {_41: x, _42: y, _43: z}};
    static function nativeMarker(window:Dynamic, layer:Int, x:Float, y:Float):Dynamic {
        var m:Dynamic = {layer: layer, parent: window.scroll, alpha: 0.8, visible: true, nativeVisible: true,
            worldPos: {x: x, y: y}, x: x, y: y, content: {}, removed: false};
        (cast window.markers:Array<Dynamic>).push(m);
        return m;
    }
    static function kinds(view:BigMapView):String {
        var values = [for (p in view.markers.points) p.kind]; values.sort(Reflect.compare); return values.join(',');
    }
    static function main():Void {
        G.globals['HElement.obelisks'] = [definition('tower', 9000, 7000, 5, 13)];
        G.globals['HElement.respawnPoints'] = [definition('spawn', 8000, 6000, 5)];
        G.globals['HElement.npcs'] = [definition('npc', 7500, 6000, 5)];
        G.globals['HActivity.allActivities'] = new Map<String, Dynamic>();
        G.globals['activities'] = [{inf: {id: 'task'}, prefab: {}, position: {x: 7000., y: 5000., z: 5.}},
            {inf: {id: 'done'}, prefab: {}, position: {x: 6000., y: 4000., z: 5.}}];
        var world:Dynamic = {level: 'World/W1_Siagarta'};
        var layer:Dynamic = {world: world, units: [], interactibles: []};
        var hero:Dynamic = {family: 'player', layer: layer, posx: 100., posy: 200., posz: 5., rotationZ: 0.5,
            player: {progress: {completed: 'done'}, accountProgress: {collection: {owned: 'OwnedPet'}}}};
        var friend:Dynamic = {family: 'player', posx: 6000., posy: 3000., posz: 5., rotationZ: 0., player: {}};
        var pet:Dynamic = {family: 'enemy', name: 'Pet', kind: 'NewPet', posx: 6000., posy: 3000., posz: 5.,
            inf: {id: 'NewPet', type: 'Critter', flags: 0, gfx: 'pet'}};
        layer.units = [hero, friend, pet];
        layer.interactibles = [{family: 'gatherable', enabled: true, posx: 10000., posy: 5000., posz: 5., name: 'Copper',
            gatherInf: {id: 'Ore_Copper_Small', requiredTool: 'GearPickaxe'}},
            {family: 'npc', enabled: true, kind: 'npc', posx: 7700., posy: 6000., posz: 25., inf: {id: 'npc', props: {}}}];
        var window:Dynamic = {hero: hero, scroll: {x: 13., y: 27.}, scrollContainer: {calculatedWidth: 1000., calculatedHeight: 800.},
            markers: [], respawnPoints: new Map<String, Dynamic>(), tileScale: 2., zoom: 0.5, removed: false};
        var obelisk = nativeMarker(window, 15, 9000, 7000); obelisk.element = {id: 'tower'};
        var click = () -> {}; obelisk.content.onClick = click;
        var respawn = nativeMarker(window, 14, 8000, 6000); window.respawnPoints.set('spawn', respawn);
        var activity = nativeMarker(window, 13, 7000, 5000); activity.activity = {id: 'task'};
        var completed = nativeMarker(window, 13, 6000, 4000); completed.activity = {id: 'done'};
        var npc = nativeMarker(window, 13, 7500, 6000); npc.activity = {id: 'npc'};
        var own = nativeMarker(window, 20, 0, 0); own.hero = hero;
        var other = nativeMarker(window, 20, 6000, 3000); other.hero = friend;
        var pin = nativeMarker(window, 16, 0, 0);
        var label = nativeMarker(window, 10, 0, 0);
        var death = nativeMarker(window, 22, 0, 0);
        var view = new BigMapView(), c = config();
        view.update(window, c);
        eq(view.root != null, true, 'Overlay created with real shared marker collector');
        eq(kinds(view), 'activity,companion,npc,obelisk,ore,player,respawn', 'All enabled marker categories, including far-away locations');
        eq(view.markerViewport.parent, window.scroll, 'Smoothing retains native marker layer order');
        eq(view.markerViewport.layer, 15, 'Custom pins and crosshair still draw above markers');
        eq(view.root.parent, view.markerViewport, 'World artwork is inside bounded smoothing viewport');
        eq(view.root.scale, 1., 'World coordinates include current map tile scale and zoom');
        eq(view.markerViewport.width, 1000, 'Smoothing bounds use visible map width');
        eq(view.markerViewport.height, 800, 'Smoothing bounds use visible map height');
        eq(view.markerViewport.filter.smooth, true, 'Supersampled artwork is smoothly downsampled');
        eq(view.markerViewport.filter.useScreenResolution, true, 'Sampling follows actual display resolution');
        eq(view.markerViewport.filter.resolutionScale, 2., 'Twice the resolution on each axis');
        eq(G.field(view.root, 'filter'), null, 'Never filter the unbounded world root');
        eq(G.field(window.scroll, 'filter'), null, 'Map terrain is not supersampled');
        eq(view.markers.markerScale, 2., 'Main-map marker size is doubled');
        eq(view.input.propagateEvents, true, 'Drag/zoom/click events continue to native map');
        eq(view.input.width, 1000., 'Input uses map viewport, not sidebar');
        eq(obelisk.alpha, 0., 'No duplicate original icon');
        eq(obelisk.visible, true, 'Visible obelisk retains hit target');
        eq(obelisk.content.onClick, click, 'Native travel action untouched');
        eq(completed.visible, false, 'Completed activity cannot be clicked through an invisible marker');
        eq(npc.x, 15400., 'NPC click target follows loaded position instead of prefab');
        for (m in [pin, label, death]) { eq(m.alpha, 0.8, 'Map-only artwork preserved'); eq(m.visible, true, 'Map-only target preserved'); }
        var baseline = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta');
        baseline.update(hero, c, 100, 200, 30, 1, 0, view.rifts);
        eq(baseline.points.length, 0, 'Minimap still limits nearby markers');
        eq(baseline.markerScale, 1., 'Minimap retains its normal marker size');
        var before = view.markers.revision;
        view.markers.nextRefresh = haxe.Timer.stamp() + 100;
        var arrays = G.arraysRead;
        window.zoom = 2.; window.scroll.x = -800.; window.scroll.y = 100.;
        view.update(window, c);
        eq(view.markers.revision, before, 'Smooth zoom does not rescan world entities');
        eq(G.arraysRead, arrays, 'Smooth zoom does not allocate source arrays');
        eq(view.markers.mapIconMarkers[0].icon.scale, 0.5, 'Icons keep constant display size while zooming');
        eq(view.arrow.scale, 0.5, 'Own arrow uses same scale');
        eq(view.markers.npcElevationMarkers[0].root.scale, 0.5, 'Height indicators use the same larger size');
        for (zoom in [0.125, 0.5, 1., 2., 8.]) {
            window.zoom = zoom;
            window.scroll.x = -90000. * zoom; window.scroll.y = 25000. * zoom;
            view.update(window, c);
            var viewport = view.markerViewport, root = view.root;
            var sx = G.number(window.scroll.x), sy = G.number(window.scroll.y);
            var vx = G.number(viewport.x), vy = G.number(viewport.y), vs = G.number(viewport.scale);
            var rx = G.number(root.x), ry = G.number(root.y), rs = G.number(root.scale);
            eq(sx + zoom * vx, 0., 'Viewport remains anchored during pan/zoom');
            eq(zoom * vs, 1., 'Viewport bounds never expand with world zoom');
            eq(sx + zoom * (vx + vs * (rx + rs * 91234.)),
                sx + view.scale * 91234., 'World X projection matches native map');
            eq(sy + zoom * (vy + vs * (ry + rs * -15678.)),
                sy + view.scale * -15678., 'World Y projection matches native map');
            eq(viewport.width, 1000, 'Distant panning cannot enlarge smoothing target');
            eq(viewport.height, 800, 'Zoom cannot enlarge smoothing target');
            eq(zoom * vs * rs * G.number(view.markers.mapIconMarkers[0].icon.scale), 2.,
                'Marker display size stays constant throughout zoom');
        }
        window.scrollContainer.calculatedWidth = 757.5;
        window.scrollContainer.calculatedHeight = 603.5;
        view.update(window, c);
        eq(view.markerViewport.width, 758, 'Fractional resized viewport rounds up for complete coverage');
        eq(view.markerViewport.height, 604, 'Resized height updates smoothing bounds');
        var ore = view.markers.points.filter(p -> p.kind == 'ore')[0];
        var edge = view.markers.hoverAt(ore.x + 12 / view.scale, ore.y, view.scale, 100, 200, hero);
        eq(edge != null, true, 'Hover area reaches the enlarged marker edge');
        eq(edge.name, 'Copper', 'Enlarged hover selects the right marker');
        c = change(c, 'markerScale', 150.); view.update(window, c);
        eq(view.markers.markerScale, 3., 'Existing marker-size setting applies to larger main-map baseline');
        eq(view.arrow.scale * view.scale, 3., 'Own arrow follows marker-size setting');
        // Hover uses displayed pan/zoom, not the minimap centre or target zoom.
        window.scroll.x = 500 - ore.x * view.scale; window.scroll.y = 400 - ore.y * view.scale;
        view.trackMouse({relX: window.scroll.x + ore.x * view.scale, relY: window.scroll.y + ore.y * view.scale});
        view.update(window, c);
        eq(view.caption.text, 'Copper', 'Big-map hover resolves shared marker name');
        c = change(c, 'hideCopper', true); view.update(window, c);
        eq(kinds(view).indexOf('ore'), -1, 'Per-resource filter shared');
        c = change(c, 'showPlayers', false); view.update(window, c);
        eq(other.visible, false, 'Other-player filter also removes native hit target');
        eq(own.visible, true, 'Own cursor remains enabled');
        c = change(c, 'hideVerticallyDistantMarkers', true); view.update(window, c);
        eq(npc.visible, false, 'Height filter also removes native NPC target');
        c = change(c, 'showObelisks', false); view.update(window, c);
        eq(obelisk.visible, false, 'Obelisk filter shared');
        c = change(c, 'showActivities', false); view.update(window, c);
        eq(activity.visible, false, 'Activity filter shared');
        c = change(c, 'showCompanions', false); view.update(window, c);
        eq(kinds(view), 'respawn', 'All shared filters combined');
        var oldRoot = view.root;
        var oldViewport = view.markerViewport;
        c = change(c, 'overrideBigMapMarkers', false); view.update(window, c);
        eq(view.root, null, 'Turning override off removes overlay');
        eq(oldRoot.removed, true, 'Old overlay detached');
        eq(oldViewport.removed, true, 'Smoothing viewport detached with overlay');
        eq(obelisk.alpha, 0.8, 'Original alpha restored');
        eq(obelisk.visible, true, 'Native filters refreshed');
        eq(npc.x, 15000., 'Original native position restored');
        c = config(); view.update(window, c);
        eq(view.root != oldRoot, true, 'Toggle back on builds a fresh overlay');
        oldRoot = view.root;
        view.remove(window);
        eq(oldRoot.removed, true, 'Closing/rebuilding map detaches overlay');
        eq(obelisk.alpha, 0.8, 'Closing/rebuilding restores originals');
        view.update(window, c); oldRoot = view.root;
        world.level = 'Dungeon'; view.update(window, c);
        eq(oldRoot.removed, true, 'Instance transition clears overworld overlay');
        eq(obelisk.alpha, 0.8, 'Instance map retains native artwork');
        world.level = 'World/W1_Siagarta'; view.update(window, c);
        c = change(c, 'enabled', false); view.update(window, c);
        eq(view.root, null, 'Master Enabled also controls big map');
        view.update(window, config());
        G.failGraphics = true;
        view.markers.nextRefresh = 0;
        view.markers.mapIconMarkers[0].key = 'force redraw';
        view.update(window, config());
        eq(view.root, null, 'Render failure falls back to native map');
        eq(obelisk.alpha, 0.8, 'Render failure restores original markers');
        eq(obelisk.visible, true, 'Render failure leaves travel available');
        Sys.println('Big map: ' + checks + ' checks passed.');
    }
}
