import minimap.BigMapView;
import minimap.MinimapMarkers;
import minimap.MinimapSettings;
import minimap.GameAccess as G;

@:access(minimap.BigMapView)
@:access(minimap.MinimapMarkers)
@:access(minimap.MainMapFilterBar)
@:access(minimap.HoverMeasurements)
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
        var nativeToggle:Dynamic = {visible:true, removed:false};
        window.filterButtons = [nativeToggle];
        window.scrollContainer.dom = {obj:window.scrollContainer};
        var saves = 0;
        var view = new BigMapView(() -> saves++), c = config();
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
        eq(view.markers.markerScale, 1.5, 'Main-map size reduced by 25 percent, preserving smoothing');
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
        eq(view.markers.mapIconMarkers[0].icon.scale, 0.375, 'Icons keep constant display size while zooming');
        eq(view.arrow.scale, 0.375, 'Own arrow uses same scale');
        eq(view.markers.npcElevationMarkers[0].root.scale, 0.375, 'Height indicators use the same larger size');
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
            eq(zoom * vs * rs * G.number(view.markers.mapIconMarkers[0].icon.scale), 1.5,
                'Marker display size stays constant throughout zoom');
        }
        window.scrollContainer.calculatedWidth = 757.5;
        window.scrollContainer.calculatedHeight = 603.5;
        view.update(window, c);
        eq(view.markerViewport.width, 758, 'Fractional resized viewport rounds up for complete coverage');
        eq(view.markerViewport.height, 604, 'Resized height updates smoothing bounds');
        var ore = view.markers.points.filter(p -> p.kind == 'ore')[0];
        var edge = view.markers.hoverAt(ore.x + 8 / view.scale, ore.y, view.scale, 100, 200, hero);
        eq(edge != null, true, 'Hover area reaches the enlarged marker edge');
        eq(edge.name, 'Copper', 'Enlarged hover selects the right marker');
        c = change(c, 'markerScale', 150.); view.update(window, c);
        eq(view.markers.markerScale, 2.25, 'Existing marker-size setting applies to larger main-map baseline');
        eq(view.arrow.scale * view.scale, 2.25, 'Own arrow follows marker-size setting');
        // Hover uses displayed pan/zoom, not the minimap centre or target zoom.
        window.scroll.x = 500 - ore.x * view.scale; window.scroll.y = 400 - ore.y * view.scale;
        view.trackMouse({relX: window.scroll.x + ore.x * view.scale, relY: window.scroll.y + ore.y * view.scale});
        view.update(window, c);
        eq(view.caption.text, 'Copper', 'Big-map hover resolves shared marker name');
        eq(nativeToggle.visible, false, 'Native filter toggles hidden while override is active');
        eq(view.filterBar.buttons.length, 8, 'Eight main-map categories');
        eq(G.number(view.caption.x) + G.number(view.caption.scale) * G.number(G.call('h2d.Text', 'get_textWidth', view.caption)) / 2,
            window.scrollContainer.calculatedWidth / 2, 'Hover caption horizontally centered in map');
        eq(view.caption.filter.size, 2., 'Caption has a thicker native outline');
        eq(view.measurements.root.filter.size, 2., 'Measurement row has matching outline');
        eq(view.measurements.root.scale, 1.5, 'Measurement row is larger');
        for (key in ['hideCopper', 'hideVerticallyDistantMarkers']) c = change(c, key, true);
        for (key in ['showPlayers', 'showObelisks', 'showRespawnPoints', 'showSoulstoneCircles', 'showActivities', 'showCompanions']) c = change(c, key, false);
        view.update(window, c);
        eq(kinds(view), 'activity,companion,npc,obelisk,ore,player,respawn', 'Minimap preferences do not hide main-map markers');
        eq(npc.visible, true, 'Vertical distance never hides main-map markers or their native actions');
        for (m in [own, other, obelisk, respawn]) eq(m.visible, true, 'Always-visible landmarks and players retain native actions');
        var oreButton = view.filterBar.buttons[0].object;
        oreButton.onClick(); view.update(window, c);
        eq(kinds(view).indexOf('ore'), -1, 'Left click disables main-map category');
        eq(c.showOre, true, 'Main-map category does not change minimap category');
        eq(c.hideCopper, true, 'Main-map category does not change minimap resource preference');
        oreButton.onClick(); view.update(window, c);
        eq(kinds(view).indexOf('ore') >= 0, true, 'Second click restores category');
        oreButton.onRightClick();
        eq(view.filterBar.boxes.length, 4, 'Ore popup has exactly four checkboxes');
        eq([for (box in view.filterBar.boxes) box.key].join(','), 'copper,iron,tin,tungstene', 'Ore subfilters');
        var box = view.filterBar.boxes[0].object;
        box.onValueChange(false); view.update(window, c);
        eq(kinds(view).indexOf('ore'), -1, 'Copper checkbox filters actual main-map resource');
        eq(oreButton.selected, true, 'Unchecking a subtype keeps category enabled');
        eq(box.selected, false, 'Checkbox reflects saved subtype state');
        eq(saves, 3, 'Each actual change saves once');
        oreButton.onClick(); oreButton.onClick(); view.update(window, c);
        eq(kinds(view).indexOf('ore'), -1, 'Cycling category preserves subfilters');
        eq(c.mainMapHiddenFilters.indexOf('ore:copper') >= 0, true, 'Main-map filter persisted independently');
        var popup = view.filterBar.popup;
        view.input.onPush({});
        eq(popup.removed, true, 'Clicking outside closes popup');
        eq(view.filterBar.popup, null, 'Popup reference cleared');
        friend.party = true; friend.name = 'Party'; hero.name = 'Me';
        friend.posx = 7700.; friend.posy = 6000.;
        view.markers.nextRefresh = 0; view.update(window, c);
        eq(view.priorityViewport.layer, 26, 'Player priority layer is above every native marker');
        eq(view.markers.partyIcons.parent, view.priorityRoot, 'Party icons use priority layer');
        eq(view.arrow.parent, view.priorityRoot, 'Own arrow uses priority layer');
        eq(G.created.indexOf(view.arrow) > G.created.indexOf(view.markers.partyIcons), true, 'Own arrow draws above party');
        eq(view.markers.hoverAt(7700, 6000, view.scale, hero.posx, hero.posy, hero).name, 'Party', 'Party hover takes priority over NPC');
        hero.posx = 7700.; hero.posy = 6000.; view.update(window, c);
        eq(view.markers.hoverAt(7700, 6000, view.scale, 7700, 6000, hero).name, 'Me', 'Own main-map hover takes priority over party');
        var miniConfig = config();
        var miniForeground = {};
        baseline = new MinimapMarkers({}, miniForeground, {}, 'World/W1_Siagarta');
        baseline.update(hero, miniConfig, 7700, 6000, 100, 1, 0, view.rifts);
        eq(baseline.partyIcons.parent, miniForeground, 'Minimap party shares foreground transform');
        eq(G.created.indexOf(baseline.partyIcons) > G.created.indexOf(baseline.npcIcons), true, 'Minimap party draws over NPCs');
        eq(baseline.hoverAt(7700, 6000, 1, 7700, 6000, hero).name, 'Party', 'Minimap party hover is highest priority');
        var top = {};
        baseline.setPartyParent(top);
        eq(baseline.partyIcons.parent, top, 'Minimap can raise party icons above edge alerts');
        eq(baseline.partyElevations.parent, top, 'Party height indicators follow the priority layer');
        eq(baseline.hoverAt(7700, 6000, 1, 7700, 6000, hero, true).name, 'Party', 'Party-only hover precedes edge alerts');
        eq(baseline.hoverAt(0, 0, 1, 0, 0, hero, true), null, 'Party-only pass never selects our cursor');
        friend.posx = 9000.;
        baseline.nextRefresh = 0;
        baseline.update(hero, miniConfig, 7700, 6000, 100, 1, 0, view.rifts);
        baseline.updateAlerts(miniConfig, 7700, 6000, 250, 1, 0, view.rifts);
        eq(baseline.alertArrows[0].icon.parent, baseline.partyAlertLayer, 'Party edge arrow uses a higher layer than other alerts');
        var edgeParty = baseline.alertPositions[0];
        baseline.riftAlertPosition = {x:edgeParty.x, y:edgeParty.y, point:{id:'rift', kind:'inactiveRift', x:0, y:0, z:0}};
        eq(baseline.alertHoverAt(edgeParty.x, edgeParty.y).name, 'Party', 'Party edge hover wins over overlapping Rift');
        var savedFilters = c.mainMapHiddenFilters.copy();
        view.remove(window); view.update(window, c);
        eq(c.mainMapHiddenFilters.join(','), savedFilters.join(','), 'Reopening the map retains independent choices');
        eq(kinds(view).indexOf('ore'), -1, 'Reopened map still filters copper');
        view.filterBar.buttons[0].object.onRightClick();
        eq(view.filterBar.boxes[0].object.selected, false, 'Reopened popup reflects saved checkbox');
        view.filterBar.buttons[0].object.onRightClick();
        eq(view.filterBar.popup, null, 'Right-click same category closes popup');
        for (button in view.filterBar.buttons) {
            button.object.onRightClick();
            eq(view.filterBar.boxes.length, button.category.items.length, 'Every category builds its declared subfilters');
        }
        view.filterBar.closePopup();
        var oldRoot = view.root;
        var oldViewport = view.markerViewport;
        c = change(c, 'overrideBigMapMarkers', false); view.update(window, c);
        eq(view.root, null, 'Turning override off removes overlay');
        eq(oldRoot.removed, true, 'Old overlay detached');
        eq(oldViewport.removed, true, 'Smoothing viewport detached with overlay');
        eq(obelisk.alpha, 0.8, 'Original alpha restored');
        eq(nativeToggle.visible, true, 'Native filter toggles restored when override is disabled');
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
        eq(nativeToggle.visible, true, 'Render failure also restores native filter controls');
        Sys.println('Big map: ' + checks + ' checks passed.');
    }
}
