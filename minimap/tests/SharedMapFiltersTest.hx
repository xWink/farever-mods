import minimap.MainMapFilters;
import minimap.MainMapFilterBar;
import minimap.MinimapMarkers;
import minimap.MinimapSettings;
import minimap.GameAccess as G;

@:access(minimap.MainMapFilterBar)
@:access(minimap.MinimapMarkers)
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
        var fields = ['showOre', 'showPlants', 'showEnemies', 'showCompanions', 'showActivities', 'showNpcs', 'showChests', 'showSecretOrbs'];
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
        eq(hud.accepts({kind:'riftPortal', x:0, y:0, z:0}), false, 'Minimap uses shared Rift subtype');
        main.setEnabled('companions', 'sparkling', false); hud.bind(c);
        eq(hud.accepts({kind:'companion', sparkling:true, x:0, y:0, z:0}), false, 'Shared sparkling subtype');
        for (field in ['showPlayers', 'showObelisks', 'showRespawnPoints', 'showSoulstoneCircles']) {
            eq(Reflect.field(hud.minimapSettings(), field), false, 'Minimap-specific landmark/player preference ' + field);
            eq(Reflect.field(main.settings(), field), true, 'Main-map protected category ' + field);
        }
        eq(hud.minimapSettings().hideVerticallyDistantMarkers, true, 'Minimap retains height filter');
        eq(main.settings().hideVerticallyDistantMarkers, false, 'Main map never filters by height');
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
        var hero:Dynamic = {family:'player', layer:layer, posx:0., posy:0., posz:0., player:{}};
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
        bar.dispose();
        var reloaded:MinimapSettings = haxe.Json.parse(haxe.Json.stringify(c)); hud.bind(reloaded);
        eq(hud.minimapSettings().hideIron, true, 'Shared preferences survive restart without opening map');
        eq(hud.enabled('enemies', 'regular'), false, 'Extra subtype survives restart');
        reloaded = Reflect.copy(reloaded); reloaded.showPlayers = true; hud.bind(reloaded);
        eq(hud.minimapSettings().showPlayers, true, 'Remaining BMS controls refresh through config reload');
        Sys.println('Shared map filters: $checks checks passed.');
    }
}
