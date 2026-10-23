import minimap.BigMapView;
import minimap.MinimapMarkers;
import minimap.MinimapSettings;
import minimap.GameAccess as G;

@:access(minimap.BigMapView)
@:access(minimap.MinimapMarkers)
@:access(minimap.MainMapFilterBar)
@:access(minimap.HoverMeasurements)
@:access(minimap.MainMapBonusDungeon)
class BigMapTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, message:String):Void {
        checks++;
        if (a != b) throw message + ': expected ' + b + ', got ' + a;
    }
    static function config():MinimapSettings return cast {
        mainMapEnabled: true, minimapEnabled: true, markerScale: 100., mainMapPlayerFiltersInitialized:true,
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
            children:[{font:{size:22, nativeFont:true}}], markers: [], respawnPoints: new Map<String, Dynamic>(), tileScale: 2., zoom: 0.5, removed: false};
        var nativeMoves = 0, nativePushes = 0, nativePins = 0;
        var nativeMove = (_:Dynamic) -> nativeMoves++;
        var nativePush = (_:Dynamic) -> nativePushes++;
        var nativeRightClick = () -> nativePins++;
        var nativeInput:Dynamic = {width:1000., height:800., propagateEvents:false, onMove:nativeMove, onPush:nativePush};
        window.mapContainer = {interactive:nativeInput, onRightClick:nativeRightClick};
        var obelisk = nativeMarker(window, 15, 9000, 7000); obelisk.element = {id: 'tower'};
        var click = () -> {}; obelisk.content.onClick = click;
        var respawn = nativeMarker(window, 14, 8000, 6000); window.respawnPoints.set('spawn', respawn);
        var activity = nativeMarker(window, 13, 7000, 5000); activity.activity = {id: 'task'}; activity.showOffscreen = true;
        var completed = nativeMarker(window, 13, 6000, 4000); completed.activity = {id: 'done'};
        var npc = nativeMarker(window, 13, 7500, 6000); npc.activity = {id: 'npc'};
        var own = nativeMarker(window, 20, 0, 0); own.hero = hero;
        own.content.alpha = 0.9;
        own.camera = {visible:true, alpha:1., rotation:0.25};
        G.set(own.camera, "parent", own);
        var other = nativeMarker(window, 20, 6000, 3000); other.hero = friend;
        var pin = nativeMarker(window, 16, 0, 0);
        var label = nativeMarker(window, 10, 0, 0);
        var death = nativeMarker(window, 22, 0, 0);
        var obeliskTip = () -> 'Native obelisk tooltip';
        var ownTip = () -> 'Native own-player tooltip';
        var otherTip = () -> 'Native other-player tooltip';
        var activityTip = () -> 'Native activity tooltip';
        obelisk.content.getTip = obeliskTip; obelisk.content.showTipOnOver = true;
        own.content.getTip = ownTip; own.content.showTipOnOver = true;
        other.content.getTip = otherTip; other.content.showTipOnOver = true;
        activity.content.getTip = activityTip; activity.content.showTipOnOver = true;
        var nativeToggle:Dynamic = {visible:true, removed:false};
        window.filterButtons = [nativeToggle];
        window.scrollContainer.dom = {obj:window.scrollContainer};
        var saves = 0;
        var view = new BigMapView(() -> saves++), c = config();
        view.update(window, c);
        eq(view.root != null, true, 'Overlay created with real shared marker collector');
        eq(kinds(view), 'activity,companion,npc,obelisk,ore,player,respawn', 'All enabled marker categories, including far-away locations');
        window.selector = true;
        view.update(window, c);
        eq(kinds(view), 'obelisk', 'Travel hides ordinary players and unrelated markers');
        eq(view.arrow.visible, true, 'Travel keeps our own player marker');
        eq(own.visible, true, 'Travel keeps the native camera cone parent visible');
        eq(own.alpha, 0.8, 'Travel preserves camera cone parent opacity');
        eq(own.content.alpha, 0., 'Travel hides only the duplicate native player icon');
        eq(own.camera.rotation, 0.25, 'Travel keeps native camera direction');
        eq(other.visible, false, 'Unrelated player native target hidden');
        eq(pin.visible, false, 'Travel hides native pins');
        eq(death.visible, false, 'Travel hides death marker');
        eq(obelisk.visible, true, 'Obelisk travel destination remains clickable');
        eq(obelisk.content.onClick, click, 'Obelisk travel callback preserved');
        eq(view.markers.obeliskScale, 1.5, 'Obelisks are 50 percent larger only in travel');
        eq(view.markers.highlightObelisks, true, 'Fast travel adds the obelisk ring');
        // Render an on-screen destination; the fixture's actual tower starts
        // outside the viewport and is intentionally culled from artwork.
        view.markers.updateIcons([{kind:'obelisk', x:0., y:0., z:0.}], [], {}, 1.);
        eq(G.rings > 0, true, 'Fast travel artwork actually paints its ring');
        hero.name = 'Me';
        eq(view.markers.hoverAt(hero.posx, hero.posy, view.scale, hero.posx, hero.posy, hero).name, 'Me', 'Travel retains own-player hover text');
        for (kind in ['dungeon', 'soulstone', 'inactiveRift', 'nextRift', 'upcomingRift', 'riftPortal'])
            eq(BigMapView.travelPoint({kind:kind, x:0, y:0, z:0}), false, 'Travel hides ' + kind);
        eq(BigMapView.travelPoint({kind:'player', partyMember:true, x:0, y:0, z:0}), false, 'Travel hides party');
        eq(BigMapView.travelPoint({kind:'player', friend:true, x:0, y:0, z:0}), false, 'Travel hides friends');
        // Travel destinations must remain usable above/below the shared height cutoff.
        window.scroll.x = -8500.; window.scroll.y = -6500.;
        c = change(c, 'hideVerticallyDistantMarkers', true);
        for (height in [-10.1, -9.9, 20.1, 19.9, -100., 100.]) {
            hero.posz = height;
            view.markers.nextRefresh = 0;
            view.update(window, c);
            eq(kinds(view), 'obelisk', 'Travel keeps obelisk across height changes: ' + height);
            eq(view.markers.npcIconMarkers.length, 1, 'Travel draws distant obelisk: ' + height);
            eq(obelisk.visible, true, 'Travel keeps distant destination clickable: ' + height);
            eq(obelisk.content.onClick, click, 'Travel keeps native action: ' + height);
        }
        eq(c.hideVerticallyDistantMarkers, true, 'Travel does not change saved height preference');
        eq(view.filters.minimapSettings().hideVerticallyDistantMarkers, true, 'HUD retains height filtering during travel');
        window.selector = false;
        view.update(window, c);
        eq(view.markers.points.filter(p -> p.kind == 'obelisk').length, 0, 'Normal map still filters distant obelisk');
        eq(obelisk.visible, false, 'Normal map still hides distant native target');
        window.selector = true;
        view.update(window, c);
        eq(kinds(view), 'obelisk', 'Reopening travel restores distant obelisk');
        eq(obelisk.visible, true, 'Reopening travel restores destination click target');
        hero.posz = 5.;
        c = change(c, 'hideVerticallyDistantMarkers', false);
        // Put the obelisk onscreen to check actual icon size and smooth zoom.
        window.scroll.x = -8500.; window.scroll.y = -6500.;
        view.update(window, c);
        eq(view.markers.npcIconMarkers[0].icon.scale, 2.25, 'Travel obelisk actual rendered size');
        window.zoom = 1.; window.scroll.x = -17500.; window.scroll.y = -13500.;
        view.update(window, c);
        eq(view.markers.npcIconMarkers[0].icon.scale, 1.125, 'Travel obelisk retains enlargement during smooth zoom');
        window.zoom = 0.5; window.scroll.x = 13.; window.scroll.y = 27.;
        window.selector = false;
        view.update(window, c);
        eq(kinds(view), 'activity,companion,npc,obelisk,ore,player,respawn', 'Normal map restored after leaving travel');
        eq(view.markers.obeliskScale, 1., 'Normal map uses normal obelisk size');
        eq(view.markers.highlightObelisks, false, 'Normal map does not use travel rings');
        eq(view.arrow.visible, true, 'Normal map restores own arrow');
        eq(own.alpha, 0.8, 'Main map preserves camera cone parent opacity');
        eq(own.content.alpha, 0., 'Main map hides only the duplicate native player icon');
        own.camera.rotation = 1.25; view.update(window, c);
        eq(own.camera.rotation, 1.25, 'Native camera direction changes remain intact');
        eq(view.markerViewport.parent, window.scroll, 'Smoothing retains native marker layer order');
        eq(view.markerViewport.layer, 15, 'Custom pins and crosshair still draw above markers');
        eq(view.root.parent, view.markerViewport, 'World artwork is inside bounded smoothing viewport');
        eq(view.root.scale, 1., 'World coordinates include current map tile scale and zoom');
        eq(view.markerViewport.width, 1000, 'Smoothing bounds use visible map width');
        eq(view.markerViewport.height, 800, 'Smoothing bounds use visible map height');
        eq(G.field(view.markerViewport, 'filter'), null, 'No per-frame marker-layer render target');
        eq(G.field(view.priorityViewport, 'filter'), null, 'No per-frame priority-layer render target');
        eq(view.arrow.nativeType, 'h2d.Bitmap', 'Own arrow uses cached high-resolution artwork');
        eq(view.arrow.tile.texture.width, 64, 'Cached icon retains supersampled soft edges');
        eq(view.arrow.tile.width, 32., 'Texture resolution does not enlarge icons');
        eq(view.arrow.tile.dx, -16., 'Cached icon stays centered');
        eq(view.arrow.tile.texture.bakedBackground, 0, 'Own player arrow has a transparent background');
        eq(view.markers.hitPoints.length, 0, 'Offscreen world points have no artwork or hover targets');
        eq(G.field(view.root, 'filter'), null, 'Never filter the unbounded world root');
        eq(G.field(window.scroll, 'filter'), null, 'Map terrain is not supersampled');
        eq(view.markers.markerScale, 1.5, 'Main-map size reduced by 25 percent, preserving smoothing');
        eq(view.input, nativeInput, 'Hover observes the existing native map input');
        eq(view.input.propagateEvents, false, 'Native event propagation stays unchanged');
        eq(window.mapContainer.onRightClick, nativeRightClick, 'Native pin placement callback stays unchanged');
        view.input.onMove({relX:321., relY:234.});
        eq(nativeMoves, 1, 'Original map move handler runs');
        eq(view.mouseX, 321., 'Native input coordinates reach hover tracking');
        nativeInput.absX = 50.; view.overlay.absX = 20.;
        nativeInput.absY = 70.; view.overlay.absY = 30.;
        view.input.onMove({relX:321., relY:234.});
        eq(view.mouseX, 351., 'Hover transforms native input coordinates into the overlay');
        eq(view.mouseY, 274., 'Hover transforms vertical coordinates into the overlay');
        nativeInput.absX = 0.; view.overlay.absX = 0.;
        nativeInput.absY = 0.; view.overlay.absY = 0.;
        window.mapContainer.onRightClick();
        eq(nativePins, 1, 'Native pin placement remains callable');
        eq(G.created.filter(o -> G.field(o, 'nativeType') == 'h2d.Interactive' && G.field(o, 'parent') == view.overlay).length,
            0, 'No overlay input can block the native top-interactive guard');
        eq(view.input.width, 1000., 'Native input size stays unchanged');
        eq(obelisk.alpha, 0., 'No duplicate original icon');
        eq(obelisk.visible, true, 'Visible obelisk retains hit target');
        eq(obelisk.content.onClick, click, 'Native travel action untouched');
        eq(obelisk.content.getTip, null, 'Native obelisk tooltip provider suppressed');
        eq(own.content.getTip, null, 'Native own-player tooltip provider suppressed');
        eq(obelisk.content.showTipOnOver, false, 'Obelisk hover does not open a native tooltip');
        eq(own.content.showTipOnOver, false, 'Own-player hover does not open a native tooltip');
        eq(obelisk.content.tipHidden, true, 'Already-visible obelisk tooltip is dismissed');
        eq(own.content.tipHidden, true, 'Already-visible own-player tooltip is dismissed');
        eq(other.content.getTip, otherTip, 'Other-player tooltip retained');
        eq(activity.content.getTip, activityTip, 'Activity tooltip retained');
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
        window.zoom = 2.; window.scroll.x = 500 - 7700. * 4; window.scroll.y = 400 - 6000. * 4;
        view.update(window, c);
        eq(view.markers.revision, before, 'Smooth zoom does not rescan world entities');
        eq(G.arraysRead, arrays, 'Smooth zoom does not allocate source arrays');
        eq(view.markers.npcIconMarkers[0].icon.scale, 0.375, 'Icons keep constant display size while zooming');
        eq(view.arrow.scale, 0.375, 'Own arrow uses same scale');
        eq(view.markers.npcElevationMarkers[0].root.scale, 0.375, 'Height indicators use the same larger size');
        for (zoom in [0.125, 0.5, 1., 2., 8.]) {
            window.zoom = zoom;
            window.scroll.x = 500 - 10000. * zoom * 2; window.scroll.y = 400 - 5000. * zoom * 2;
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
        eq(view.markers.markerScale, 1.5, 'Minimap marker scale no longer changes the main map');
        c = change(c, 'mainMapMarkerScale', 150.); view.update(window, c);
        eq(view.markers.markerScale, 2.25, 'Main-map marker slider applies to its own baseline');
        eq(view.arrow.scale * view.scale, 2.25, 'Own arrow follows marker-size setting');
        // Hover uses displayed pan/zoom, not the minimap centre or target zoom.
        window.scroll.x = 500 - ore.x * view.scale; window.scroll.y = 400 - ore.y * view.scale;
        view.trackMouse({relX: window.scroll.x + ore.x * view.scale, relY: window.scroll.y + ore.y * view.scale});
        view.update(window, c);
        eq(view.caption.text, 'Copper', 'Big-map hover resolves shared marker name');
        view.markers.nextRefresh = haxe.Timer.stamp() + 100;
        var idleHover = view.hoverState, idleProjection = view.projection;
        var idleBakes = G.bakes, idlePositions = G.positionWrites, idleVisibility = G.visibilityWrites;
        for (_ in 0...30) view.update(window, c);
        eq(view.hoverState, idleHover, 'Stationary hover reuses the previous search and measurements');
        eq(view.projection, idleProjection, 'Stationary projection is not rebuilt');
        eq(G.bakes, idleBakes, 'Stationary frames bake no icon textures');
        eq(G.positionWrites, idlePositions, 'Stationary frames rewrite no object positions');
        eq(G.visibilityWrites, idleVisibility, 'Stationary frames rewrite no visibility');
        // Simulate the real native update before our postfix, including a visual refresh.
        G.call('ui.win.MapWindow', 'refreshVisuals', window);
        view.refreshNative(window);
        G.call('ui.win.MapWindow', 'updateMapInfos', window);
        view.update(window, c);
        eq(completed.visible, false, 'Native filter refresh is corrected without waiting for a world scan');
        eq(npc.x, 15400., 'Relocated NPC target is corrected after each native position reset');
        eq(activity.x, 14000., 'Clamped native targets also stay on the replacement artwork');
        eq(obelisk.x, 18000., 'Unchanged landmarks keep their native projection');
        eq(G.bakes, idleBakes, 'Native refresh does not rebake artwork');

        eq(nativeToggle.visible, false, 'Native filter toggles hidden while override is active');
        eq(view.filterBar.buttons.length, 9, 'Nine main-map categories');
        eq(G.number(view.caption.x) + G.number(view.caption.scale) * G.number(G.call('h2d.Text', 'get_textWidth', view.caption)) / 2,
            window.scrollContainer.calculatedWidth / 2, 'Hover caption horizontally centered in map');
        eq(view.caption.filter.size, 1.0, 'Caption has a compact solid outline without a broad halo');
        eq(view.caption.font.nativeFont, true, 'Hover uses native smooth UI font');
        eq(view.caption.scale, 1., 'Native font retains 22 pixel caption size');
        eq(view.caption.smooth, true, 'Caption font is smoothed');
        eq(view.caption.filter.color, 0x000000, 'Caption outline is black');
        eq(view.caption.filter.alpha, 1., 'Caption outline has full opacity');
        eq(view.measurements.root.filter.size, 1.0, 'Measurement row has matching compact outline');
        eq(view.measurements.root.filter.alpha, 1., 'Measurement outline has matching opacity');
        eq(view.measurements.root.scale, 1.5, 'Measurement row is larger');
        eq([for (o in G.created) if (o.parent == view.overlay && o.nativeType == 'h2d.Text') o].length,
            1, 'Hover caption has no duplicate shadow text');
        for (slot in view.measurements.slots) {
            eq(slot.shadow, null, 'Main-map distance has no offset text shadow');
            eq(slot.arrowShadow, null, 'Main-map distance arrow has no offset shadow');
        }
        hero.name = 'Me';
        var savedX = window.scroll.x, savedY = window.scroll.y;
        window.scroll.x = 350 - 9000. * view.scale; window.scroll.y = 300 - 7000. * view.scale;
        view.update(window, c); view.trackMouse({relX:350., relY:300.}); view.update(window, c);
        eq(view.caption.text, 'tower', 'Custom obelisk hover caption remains available');
        window.scroll.x = 350 - hero.posx * view.scale; window.scroll.y = 300 - hero.posy * view.scale;
        view.update(window, c); view.trackMouse({relX:350., relY:300.}); view.update(window, c);
        eq(view.caption.text, 'Me', 'Custom own-player hover caption remains available');
        window.scroll.x = savedX; window.scroll.y = savedY;
        window.nearClickableMarker = npc;
        for (key in ['hideCopper', 'hideVerticallyDistantMarkers']) c = change(c, key, true);
        for (key in ['showPlayers', 'showObelisks', 'showRespawnPoints', 'showSoulstoneCircles', 'showActivities', 'showCompanions']) c = change(c, key, false);
        view.update(window, c);
        eq(kinds(view), 'activity,companion,obelisk,ore,player,respawn', 'Only the shared height filter hides a distant marker');
        eq(npc.visible, false, 'Height-hidden main-map marker also loses native click target');
        eq(window.nearClickableMarker, null, 'Height-hidden marker is removed from native selection');
        eq(npc.content.tipHidden, true, 'Height-hidden marker cannot retain a stale native tooltip');
        c = change(c, 'hideVerticallyDistantMarkers', false); view.update(window, c);
        eq(npc.visible, true, 'Disabling shared height filter restores native action');
        for (m in [own, other, obelisk, respawn]) eq(m.visible, true, 'Always-visible landmarks and players retain native actions');
        var oreButton = view.filterBar.buttons[0].object;
        eq(oreButton.minWidth, 48, 'Filter buttons are twenty percent larger');
        eq(oreButton.minHeight, 48, 'Filter buttons stay square');
        eq(view.filterBar.buttons[0].icon.scale, 1.35, 'Filter symbols are larger too');
        for (button in view.filterBar.buttons) {
            eq(G.field(button.object, 'textTip'), null, 'Filter toggle has no hover tooltip');
            eq(button.icon.nativeType, 'h2d.Bitmap', 'Filter symbol uses shared cached artwork');
            eq(button.icon.tile.texture.width, 128, 'Filter symbol retains four times native resolution');
            eq(button.icon.smooth, true, 'Filter symbols are smoothly downsampled');
            eq(button.icon.tile.texture.bakedBackground, 0, 'Filter icon background is transparent');
            eq(G.field(button.icon, 'filter'), null, 'Filter symbols have no per-frame smoothing pass');
            eq(G.field(button.object, 'filter'), null, 'Small icon smoothing does not capture the full native button');
        }
        eq(oreButton.background.fill, 0xFFE9D9BB, 'Native rounded background uses light parchment');
        oreButton.hasHover = true; oreButton.onOver();
        eq(oreButton.background.color.argb, 0xFFDED4C4, 'Hover darkens rather than flashing white');
        oreButton.pushed = 'left'; view.update(window, c);
        eq(oreButton.background.color.argb, 0xFFC1B39E, 'Press has a darker native-style response');
        oreButton.pushed = null; oreButton.hasHover = false; oreButton.onOut();
        eq(oreButton.background.color.argb, 0xFFFFFFFF, 'Leaving restores the base parchment color');
        oreButton.onClick(); view.update(window, c);
        eq(view.filterBar.buttons[0].slash.visible, true, 'Disabled category shows diagonal slash');
        eq(oreButton.selected, true, 'Native inset border remains selected when the category is disabled');
        eq(view.filterBar.buttons[0].icon.alpha, 1., 'Disabled category keeps its full-color icon');
        eq(kinds(view).indexOf('ore'), -1, 'Left click disables main-map category');
        eq(c.showOre, true, 'Legacy category flag is no longer authoritative');
        eq(c.hideCopper, true, 'Legacy resource flag is no longer authoritative');
        oreButton.onClick(); view.update(window, c);
        eq(kinds(view).indexOf('ore') >= 0, true, 'Second click restores category');
        eq(view.filterBar.buttons[0].slash.visible, false, 'Enabled category hides slash');
        oreButton.onRightClick();
        eq(view.filterBar.boxes.length, 4, 'Ore popup has exactly four checkboxes');
        for (row in view.filterBar.boxes) eq(row.object.paddingLeft, 8, 'Checkbox has an inset within its row');
        var close = [for (o in G.created) if (G.field(G.field(o, 'dom'), 'id') == 'mainMapFilterClose' && o.parent == view.filterBar.popup) o][0];
        var cross = [for (o in G.created) if (o.parent == close && o.nativeType == 'h2d.Graphics') o][0];
        eq(cross.x, 14., 'Close cross is horizontally centered in its 28-pixel button');
        eq(cross.y, 14., 'Close cross is vertically centered in its 28-pixel button');
        eq([for (box in view.filterBar.boxes) box.key].join(','), 'copper,iron,tin,tungstene', 'Ore subfilters');
        var box = view.filterBar.boxes[0].object;
        box.onValueChange(false); view.update(window, c);
        eq(kinds(view).indexOf('ore'), -1, 'Copper checkbox filters actual main-map resource');
        eq(oreButton.selected, true, 'Unchecking a subtype keeps category enabled');
        eq(box.selected, false, 'Checkbox reflects saved subtype state');
        eq(saves, 3, 'Each actual change saves once');
        oreButton.onClick(); oreButton.onClick(); view.update(window, c);
        eq(kinds(view).indexOf('ore'), -1, 'Cycling category preserves subfilters');
        eq(c.mainMapHiddenFilters.indexOf('ore:copper') >= 0, true, 'Shared filter preference persisted');
        var popup = view.filterBar.popup;
        view.input.onPush({});
        eq(nativePushes, 1, "Native drag handler still runs");
        eq(popup.removed, true, 'Clicking outside closes popup');
        eq(view.filterBar.popup, null, 'Popup reference cleared');
        friend.party = true; friend.name = 'Party'; hero.name = 'Me';
        friend.posx = 7700.; friend.posy = 6000.;
        window.scroll.x = 400 - 7700. * view.scale; window.scroll.y = 300 - 6000. * view.scale;
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
        var reopenBakes = G.bakes;
        view.remove(window); view.update(window, c);
        eq(G.bakes, reopenBakes, 'Map reopen reuses all previously encountered icon appearances');
        eq(c.mainMapHiddenFilters.join(','), savedFilters.join(','), 'Reopening the map retains independent choices');
        eq(kinds(view).indexOf('ore'), -1, 'Reopened map still filters copper');
        view.filterBar.buttons[0].object.onRightClick();
        eq(view.filterBar.boxes[0].object.selected, false, 'Reopened popup reflects saved checkbox');
        view.filterBar.buttons[0].object.onRightClick();
        eq(view.filterBar.popup, null, 'Right-click same category closes popup');
        for (button in view.filterBar.buttons) {
            if (button.category.items.length > 0) {
                button.object.onRightClick();
                eq(view.filterBar.boxes.length, button.category.items.length, 'Category builds its declared subfilters');
            } else {
                view.filterBar.closePopup();
                eq(G.field(button.object, 'onRightClick'), null, 'No right-click handler for ' + button.category.key);
                view.filterBar.openPopup(button.category);
                eq(view.filterBar.popup, null, 'Empty submenus cannot be opened');
            }
        }
        view.filterBar.closePopup();
        eq(view.bonusDungeon.visible, false, 'Bonus card waits for character specialization');
        hero.specialization = {bonusHeroicDungeon:{activity:'DungeonOne'}};
        G.globals['activity:DungeonOne'] = {id:'DungeonOne', label:'The Sanguine Chapel'};
        view.bonusDungeon.nextSample = 0; view.update(window, c);
        eq(view.bonusDungeon.nameText.text, 'The Sanguine Chapel', 'Bonus card uses localized assigned dungeon name');
        eq(view.bonusDungeon.title.text, 'Heroic bonus dungeon', 'Bonus card identifies the reward');
        eq(view.bonusDungeon.root.x, 12., 'Bonus card is at left edge');
        eq(view.bonusDungeon.root.y, G.number(window.scrollContainer.calculatedHeight) - 68, 'Bonus card is at bottom edge');
        eq(view.bonusDungeon.visible, true, 'Bonus is visible regardless of main-map activity filters');
        eq(view.bonusDungeon.icon.visible, false, 'Missing icon data does not prevent the bonus name from showing');
        var heroicTile:Dynamic = {width:96., height:96., source:'Dungeon_Heroic'};
        var iconDefinitions:Map<String, Dynamic> = ['Dungeon_Heroic' => {gfx:{tile:heroicTile}}];
        G.globals['Data.icon'] = {byId:iconDefinitions};
        eq(view.bonusDungeon.fontSource.styleClass, 'bold-16', 'Bonus uses the native bold font style');
        var boldFont:Dynamic = {size:16, name:'NativeBold'};
        view.bonusDungeon.fontSource.font = boldFont;
        view.update(window, c);
        eq(view.bonusDungeon.nameText.font, boldFont, 'Delayed native styling updates the dungeon name font');
        eq(view.bonusDungeon.title.font, boldFont, 'Heading also updates to native bold');
        eq(view.bonusDungeon.nameText.scale, 18 / 16., 'Name retains requested display size after font change');
        eq(view.bonusDungeon.nameText.smooth, true, 'Native text smoothly scales to fit');
        var reads = G.activityNameReads;
        view.bonusDungeon.nextSample = 0; view.update(window, c);
        eq(G.activityNameReads, reads, 'Unchanged bonus does not resolve dungeon name again');
        eq(view.bonusDungeon.icon.tile, heroicTile, 'Bonus uses the exact native heroic icon asset');
        eq(view.bonusDungeon.icon.visible, true, 'Delayed icon data becomes visible');
        eq(view.bonusDungeon.icon.color.argb, 0xff91ef6b, 'Neutral heroic atlas is tinted green');
        eq(view.bonusDungeon.icon.scale, 32 / 96., 'Full-resolution heroic asset is downsampled to card size');
        hero.specialization.bonusHeroicDungeon.activity = 'DungeonTwo';
        G.globals['activity:DungeonTwo'] = {id:'DungeonTwo', label:'The Honeyzabeth Dungeon'};
        view.bonusDungeon.nextSample = 0; view.update(window, c);
        eq(view.bonusDungeon.nameText.text, 'The Honeyzabeth Dungeon', 'Replicated bonus change updates while map stays open');
        hero.specialization.bonusHeroicDungeon = null;
        view.bonusDungeon.nextSample = 0; view.update(window, c);
        eq(view.bonusDungeon.nameText.text, 'None assigned', 'No assignment clears the old dungeon');
        hero.specialization.bonusHeroicDungeon = {activity:'PendingDefinition'};
        view.bonusDungeon.nextSample = 0; view.update(window, c);
        eq(view.bonusDungeon.visible, false, 'Missing definition never displays a stale dungeon or internal ID');
        G.globals['activity:PendingDefinition'] = {id:'PendingDefinition', label:'Ready Dungeon'};
        view.bonusDungeon.nextSample = 0; view.update(window, c);
        eq(view.bonusDungeon.nameText.text, 'Ready Dungeon', 'Delayed game definition retries correctly');
        G.failActivityLookup = true;
        hero.specialization.bonusHeroicDungeon.activity = 'DungeonOne';
        view.bonusDungeon.nextSample = 0; view.update(window, c);
        eq(view.bonusDungeon.visible, false, 'Unavailable bonus API hides only its card');
        eq(view.root != null, true, 'Optional bonus data failure leaves markers and filters working');
        G.failActivityLookup = false;
        view.bonusDungeon.nextSample = 0; view.update(window, c);
        eq(view.bonusDungeon.visible, true, 'Bonus indicator recovers after optional data failure');
        hero.specialization = null;
        view.bonusDungeon.nextSample = 0; view.update(window, c);
        var oldRoot = view.root;
        var oldViewport = view.markerViewport;
        var oldFontSource = view.bonusDungeon.fontSource;
        c = change(c, 'overrideBigMapMarkers', false); view.update(window, c);
        eq(view.root, oldRoot, 'Legacy override=false cannot disable enhanced map');
        c = change(c, 'mainMapEnabled', false); view.update(window, c);
        eq(view.root, null, 'Disabling mod removes overlay');
        eq(oldRoot.removed, true, 'Old overlay detached');
        eq(oldViewport.removed, true, 'Smoothing viewport detached with overlay');
        eq(oldFontSource.removed, true, 'Hidden native font source is removed with the map overlay');
        eq(nativeInput.onMove, nativeMove, 'Original move handler restored on disable');
        eq(nativeInput.onPush, nativePush, 'Original push handler restored on disable');
        eq(obelisk.alpha, 0.8, 'Original alpha restored');
        eq(own.content.alpha, 0.9, 'Disabling restores original native player icon opacity');
        eq(own.alpha, 0.8, 'Disabling preserves native camera parent opacity');
        eq(obelisk.content.getTip, obeliskTip, 'Disabling mod restores native obelisk tooltip');
        eq(own.content.getTip, ownTip, 'Disabling mod restores own-player tooltip');
        eq(obelisk.content.showTipOnOver, true, 'Disabling mod restores native hover behavior');
        eq(nativeToggle.visible, true, 'Native filter toggles restored when the mod is disabled');
        eq(obelisk.visible, true, 'Native filters refreshed');
        eq(npc.x, 15000., 'Original native position restored');
        c = config(); view.update(window, c);
        eq(view.root != oldRoot, true, 'Toggle back on builds a fresh overlay');
        oldRoot = view.root;
        view.remove(window);
        eq(oldRoot.removed, true, 'Closing/rebuilding map detaches overlay');
        eq(obelisk.alpha, 0.8, 'Closing/rebuilding restores originals');
        eq(obelisk.content.getTip, obeliskTip, 'Closing restores obelisk tooltip provider');
        eq(own.content.getTip, ownTip, 'Closing restores own-player tooltip provider');
        view.update(window, c); oldRoot = view.root;
        world.level = 'Dungeon'; view.update(window, c);
        eq(oldRoot.removed, true, 'Instance transition clears overworld overlay');
        eq(obelisk.alpha, 0.8, 'Instance map retains native artwork');
        world.level = 'World/W1_Siagarta'; view.update(window, c);
        c = change(c, 'mainMapEnabled', false); view.update(window, c);
        eq(view.root, null, 'Master Enabled also controls big map');
        view.update(window, config());
        // Force an uncached appearance to exercise the native fallback.
        view.release();
        G.failBake = true;
        view.update(window, config());
        eq(view.root, null, 'Render failure falls back to native map');
        eq(obelisk.alpha, 0.8, 'Render failure restores original markers');
        eq(obelisk.visible, true, 'Render failure leaves travel available');
        eq(nativeToggle.visible, true, 'Render failure also restores native filter controls');
        G.failBake = false;
        view.release();
        Sys.println('Big map: ' + checks + ' checks passed.');
    }
}
