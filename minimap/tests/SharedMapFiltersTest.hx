import minimap.MainMapFilters;
import minimap.MainMapFilterBar;
import minimap.MinimapMarkers;
import minimap.MinimapSettings;
import minimap.GameAccess as G;

@:access(minimap.MainMapFilterBar)
@:access(minimap.MinimapMarkers)
@:access(minimap.RiftMarkers)
class SharedMapFiltersTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, why:String):Void {
        checks++; if (a != b) throw why + ': expected $b, got $a';
    }
    static function main():Void {
        // Deliberately conflicting legacy settings: saved main-map choices win.
        var c:MinimapSettings = cast {markerScale:110., mainMapMarkerScale:140., showOre:false, hideIron:true,
            showPlayers:false, showObelisks:false, showRespawnPoints:false, showSoulstoneCircles:false,
            hideVerticallyDistantMarkers:true, verticallyDistantThreshold:30., sparklingCompanionAlerts:true,
            riftAlerts:true, mainMapHiddenFilters:['ore:copper', 'npcs', 'enemies:mastered']};
        var saves = 0, main = new MainMapFilters(() -> saves++), hud = new MainMapFilters();
        main.bind(c); hud.bind(c);
        eq(hud.minimapSettings().showOre, true, 'Saved main-map category wins over retired BMS toggle');
        eq(hud.minimapSettings().hideCopper, true, 'Saved main-map subtype applies to minimap');
        eq(hud.minimapSettings().hideIron, false, 'Retired BMS exclusion cannot silently hide markers');
        eq(hud.minimapSettings().showNpcs, false, 'Saved category exclusion applies to both');
        eq(hud.minimapSettings().hideMasteredCodexEnemies, true, 'Saved mastery filter applies to both');
        var container:Dynamic = {dom:null}; container.dom = {obj:container};
        var bar = new MainMapFilterBar(container, main, (parent, kind) -> G.create('h2d.Graphics', [parent]));
        bar.update({filterButtons:[]}, 1000, 800);
        var fields = ['showOre', 'showPlants', 'showEnemies', 'showCompanions', 'showActivities', 'showPlayers', 'showNpcs', 'showChests', 'showSecretOrbs'];
        for (i in 0...bar.buttons.length) {
            var button = bar.buttons[i];
            main.setEnabled(button.category.key, null, true);
            button.object.onClick(); hud.bind(c);
            eq(Reflect.field(main.settings(), fields[i]), false, button.category.label + ' hidden on main map');
            eq(Reflect.field(hud.minimapSettings(), fields[i]), false, button.category.label + ' hidden on minimap');
            button.object.onClick(); hud.bind(c);
            eq(Reflect.field(hud.minimapSettings(), fields[i]), true, button.category.label + ' restored on minimap');
            if (button.category.items.length == 0) continue;
            button.object.onRightClick();
            for (box in bar.boxes) {
                box.object.onValueChange(false); hud.bind(c);
                eq(hud.enabled(button.category.key, box.key), false, 'Popup hides shared subtype ' + box.key);
                box.object.onValueChange(true); hud.bind(c);
                eq(hud.enabled(button.category.key, box.key), true, 'Popup restores shared subtype ' + box.key);
            }
            bar.closePopup();
        }
        main.setEnabled('enemies', 'regular', false); hud.bind(c);
        eq(hud.accepts({kind:'enemy', x:0, y:0, z:0}), false, 'Minimap uses shared regular-enemy subtype');
        eq(hud.accepts({kind:'boss', x:0, y:0, z:0}), true, 'Bosses retain their own subtype');
        main.setEnabled('activities', 'rifts', false); hud.bind(c);
        eq(hud.accepts({kind:'riftPortal', x:0, y:0, z:0}), false, 'Rift subtype hides minimap rifts');
        main.setEnabled('companions', 'sparkling', false); hud.bind(c);
        eq(hud.accepts({kind:'companion', sparkling:true, x:0, y:0, z:0}), false, 'Shared sparkling subtype');
        for (field in ['showPlayers', 'showObelisks', 'showRespawnPoints', 'showSoulstoneCircles']) {
            eq(Reflect.field(hud.minimapSettings(), field), true, 'Retired minimap toggle cannot hide category ' + field);
            eq(Reflect.field(main.settings(), field), true, 'Main-map protected category ' + field);
        }
        eq(hud.minimapSettings().hideVerticallyDistantMarkers, true, 'Minimap retains height filter');
        eq(main.settings().hideVerticallyDistantMarkers, true, 'Main map uses shared height filter');
        eq(hud.minimapSettings().sparklingCompanionAlerts, true, 'Separate minimap guidance setting retained');
        eq(hud.minimapSettings().riftAlerts, true, 'Separate Rift alerts retained');
        eq(hud.minimapSettings().markerScale, 110., 'Minimap retains its own scale');
        eq(main.settings().markerScale, 140., 'Main map retains its own scale');
        var cached = hud.minimapSettings(), revision = hud.revision, saved = saves;
        for (_ in 0...100) { hud.bind(c); eq(hud.minimapSettings(), cached, 'Idle frame reuses settings'); }
        eq(hud.revision, revision, 'Idle frames do not invalidate markers');
        eq(saves, saved, 'Reading shared preferences does not write config');
        c.markerScale = 160.; eq(hud.minimapSettings().markerScale, 160., 'Minimap rescale invalidates cached settings');
        eq(main.settings().markerScale, 140., 'Minimap rescale does not affect main map');

        // Exercise the actual collector: the main-map toggle must refresh the
        // minimap immediately, even during its normal 200 ms sample interval.
        var layer:Dynamic = {world:{level:'World/W1_Siagarta'}, units:[], interactibles:[]};
        var hero:Dynamic = {family:'player', layer:layer, posx:0., posy:0., posz:0., player:{progress:{}}};
        layer.interactibles = [{family:'gatherable', enabled:true, posx:3., posy:4., posz:0., name:'Iron',
            gatherInf:{id:'Ore_Iron_Small', requiredTool:'GearPickaxe'}}];
        var rifts = new minimap.RiftMarkers('World/W1_Siagarta');
        G.globals['activities'] = [];
        var markers = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta'); markers.pointFilter = hud.accepts;
        main.setEnabled('ore', null, true); main.setEnabled('ore', 'iron', true); hud.bind(c);
        markers.update(hero, hud.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(markers.points.filter(p -> p.kind == 'ore').length, 1, 'Shared ore filter displays loaded ore');
        markers.nextRefresh = haxe.Timer.stamp() + 100;
        bar.buttons[0].object.onClick(); hud.bind(c);
        markers.update(hero, hud.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(markers.points.filter(p -> p.kind == 'ore').length, 0, 'Main-map click immediately removes minimap ore');
        bar.buttons[0].object.onClick(); hud.bind(c);
        markers.update(hero, hud.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(markers.points.filter(p -> p.kind == 'ore').length, 1, 'Main-map click restores minimap ore');
        main.setEnabled('ore', 'iron', false); hud.bind(c);
        markers.update(hero, hud.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(markers.points.filter(p -> p.kind == 'ore').length, 0, 'Shared subtype removes minimap ore');
        // Both renderers use the same height rule and threshold. Test the
        // actual collector so hidden points cannot become hover targets.
        main.setEnabled('ore', 'iron', true); hud.bind(c);
        layer.interactibles[0].posz = 30.;
        var full = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta'); full.pointFilter = main.accepts;
        full.update(hero, main.settings(), 0, 0, Math.POSITIVE_INFINITY, 1, 0, rifts);
        markers.update(hero, hud.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(full.points.length, 1, 'Main-map marker exactly at threshold stays visible');
        eq(markers.points.length, 1, 'Minimap marker exactly at threshold stays visible');
        layer.interactibles[0].posz = 31.;
        full.nextRefresh = markers.nextRefresh = 0;
        full.update(hero, main.settings(), 0, 0, Math.POSITIVE_INFINITY, 1, 0, rifts);
        markers.update(hero, hud.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(full.points.length, 0, 'Main-map marker above threshold is hidden');
        eq(markers.points.length, 0, 'Minimap marker above threshold is hidden');
        eq(full.hitPoints.length, 0, 'Hidden main-map markers have no hover target');
        c = Reflect.copy(c); c.verticallyDistantThreshold = 31.; main.bind(c); hud.bind(c);
        full.update(hero, main.settings(), 0, 0, Math.POSITIVE_INFINITY, 1, 0, rifts);
        markers.update(hero, hud.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(full.points.length, 1, 'Threshold update restores main-map marker');
        eq(markers.points.length, 1, 'Threshold update restores minimap marker');
        main.setEnabled('ore', 'iron', false);
        bar.dispose();
        var reloaded:MinimapSettings = haxe.Json.parse(haxe.Json.stringify(c)); hud.bind(reloaded);
        eq(hud.minimapSettings().hideIron, true, 'Shared preferences survive restart without opening map');
        eq(hud.enabled('enemies', 'regular'), false, 'Extra subtype survives restart');
        reloaded = Reflect.copy(reloaded); reloaded.hideVerticallyDistantMarkers = false; hud.bind(reloaded);
        eq(hud.minimapSettings().hideVerticallyDistantMarkers, false, 'Remaining BMS controls refresh through config reload');
        G.globals['HActivity.allActivities'] = new Map<String, Dynamic>();
        G.globals['activities'] = [{inf:{id:'Dungeon'}, prefab:{}, position:{x:2., y:2., z:0.}},
            {inf:{id:'ordinary'}, prefab:{}, position:{x:3., y:3., z:0.}}];
        rifts.points = [{id:'active', kind:'riftPortal', x:4., y:4., z:0.}];
        rifts.inactive = [{id:'inactive', kind:'inactiveRift', x:5., y:5., z:0.}];
        reloaded.mainMapHiddenFilters = ['activities', 'activities:dungeon', 'activities:rifts', 'activities:inactiveRifts'];
        hud.bind(reloaded);
        for (settings in [hud.settings(), hud.minimapSettings()]) {
            var travel = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta'); travel.pointFilter = hud.accepts;
            travel.update(hero, settings, 0, 0, 100, 1, 0, rifts);
            for (kind in ['dungeon', 'riftPortal', 'inactiveRift'])
                eq(travel.points.filter(p -> p.kind == kind).length, 0, 'Activity filter hides destination ' + kind);
            eq(travel.points.filter(p -> p.kind == 'activity').length, 0, 'Activities off still hides ordinary activities');
        }
        var playerConfig:MinimapSettings = Reflect.copy(reloaded);
        playerConfig.mainMapHiddenFilters = [];
        playerConfig.mainMapPlayerFiltersInitialized = false;
        var pf = new MainMapFilters(); pf.bind(playerConfig);
        eq(pf.enabled('players', 'regular'), false, 'New player filters hide ordinary players by default');
        eq(pf.enabled('players', 'party'), true, 'Party defaults on');
        eq(pf.enabled('players', 'friends'), true, 'Friends default on');
        hero.player.friendList = {friends:['friend', 'party']};
        layer.units = [hero,
            {family:'player', posx:10., posy:0., posz:0., player:{uid:'stranger'}},
            {family:'player', posx:20., posy:0., posz:0., player:{uid:'friend'}},
            {family:'player', posx:30., posy:0., posz:0., party:true, player:{uid:'party'}},
            {family:'player', posx:1000., posy:0., posz:0., party:true, player:{uid:'remote'}}];
        var pm = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta'); pm.pointFilter = pf.accepts;
        pm.update(hero, pf.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(pm.points.filter(p -> p.kind == 'player').length, 2, 'Collector shows friend and nearby party only by default');
        eq(pm.alertTargets.filter(p -> p.kind == 'player').length, 2, 'Both party edge-alert candidates retained');
        pf.setEnabled('players', 'party', false);
        pm.update(hero, pf.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(pm.points.filter(p -> p.kind == 'player').length, 1, 'Party toggle hides party even if also friend');
        eq(pm.alertTargets.filter(p -> p.kind == 'player').length, 0, 'Hidden party does not leak through edge alerts');
        pf.setEnabled('players', 'friends', false); pf.setEnabled('players', 'regular', true);
        pm.update(hero, pf.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(pm.points.filter(p -> p.kind == 'player').length, 1, 'Only ordinary player restored');
        eq(pm.points.filter(p -> p.kind == 'player')[0].entity.player.uid, 'stranger', 'Regular category excludes friends and party');
        pf.setEnabled('players', null, false);
        pm.update(hero, pf.minimapSettings(), 0, 0, 100, 1, 0, rifts);
        eq(pm.points.filter(p -> p.kind == 'player').length, 0, 'Top-level player toggle hides all other players');
        var persisted:MinimapSettings = haxe.Json.parse(haxe.Json.stringify(playerConfig));
        var restored = new MainMapFilters(); restored.bind(persisted);
        eq(restored.enabled('players', 'regular'), true, 'Saved player preference is not overwritten by migration');
        Sys.println('Shared map filters: $checks checks passed.');
    }
}
