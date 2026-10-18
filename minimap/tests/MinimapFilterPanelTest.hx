import minimap.MainMapFilters;
import minimap.MainMapFilterBar;
import minimap.MinimapSettings;
import minimap.MinimapMarkers;
import minimap.GameAccess as G;

@:access(minimap.MainMapFilterBar)
@:access(minimap.MinimapMarkers)
class MinimapFilterPanelTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, why:String):Void {
        checks++; if (a != b) throw why + ': expected $b, got $a';
    }
    static function main():Void {
        var config:MinimapSettings = cast {markerScale:100., mainMapMarkerScale:100.};
        var saves = 0;
        var main = new MainMapFilters(() -> saves++), hud = new MainMapFilters(() -> saves++, true);
        main.bind(config); hud.bind(config);
        eq(config.useSameMapFilters, true, 'Sharing defaults on for existing configs');
        hud.setEnabled('ore', 'copper', false); main.bind(config);
        eq(main.settings().hideCopper, true, 'HUD subfilter updates main map while linked');
        config.useSameMapFilters = false; hud.bind(config); main.bind(config);
        main.setEnabled('ore', null, false); hud.bind(config);
        eq(hud.minimapSettings().showOre, true, 'Independent main toggle does not hide minimap ore');
        hud.setEnabled('plants', null, false); main.bind(config);
        eq(main.settings().showPlants, true, 'Independent HUD toggle does not hide main-map plants');
        hud.setEnabled('players', 'party', false); main.bind(config);
        eq(main.enabled('players', 'party'), true, 'Independent subfilters remain separate');
        var restored:MinimapSettings = haxe.Json.parse(haxe.Json.stringify(config));
        main.bind(restored); hud.bind(restored);
        eq(main.settings().showOre, false, 'Main preferences survive reload');
        eq(hud.minimapSettings().showPlants, false, 'HUD preferences survive reload');
        restored.useSameMapFilters = true;
        // Bind the HUD first: update order must not choose the wrong authority.
        hud.bind(restored); main.bind(restored);
        eq(hud.minimapSettings().showOre, false, 'Relinking copies main categories to HUD');
        eq(hud.minimapSettings().showPlants, true, 'Relinking discards conflicting HUD choices');
        eq(hud.enabled('players', 'party'), true, 'Relinking copies main subfilters to HUD');
        restored.useSameMapFilters = false; main.bind(restored); hud.bind(restored);
        eq(hud.minimapSettings().showPlants, true, 'Unlinking again starts with synchronized choices');

        var container:Dynamic = {dom:null}; container.dom = {obj:container};
        var icons:Array<String> = [];
        var bar = new MainMapFilterBar(container, hud, (parent, kind) -> {
            icons.push(kind); return G.create('h2d.Graphics', [parent]);
        }, true);
        bar.updateHud(250, true, 1920, 1080, 1660, 10);
        eq(icons.join(','), [for (c in MainMapFilters.CATEGORIES) c.icon].concat(['settings']).join(','),
            'HUD uses the same ordered category icons plus the gear');
        eq(bar.root.visible, false, 'Filter panel starts closed');
        bar.gear.object.onClick(); bar.updateHud(250, true, 1920, 1080, 1660, 10);
        eq(bar.root.visible, true, 'Gear opens filters');
        for (button in bar.buttons) {
            eq(button.object.background.borderRadius.top, 24., 'Circular map has round filter buttons');
            eq(button.object.selected, true, 'Border stays selected');
            var enabled = hud.enabled(button.category.key);
            button.object.onClick();
            eq(hud.enabled(button.category.key), !enabled, 'HUD click toggles ' + button.category.key);
            eq(button.slash.visible, enabled, 'Disabled category has a slash');
            if (button.category.items.length > 0) {
                button.object.onRightClick();
                eq(bar.boxes.length, button.category.items.length, 'Right-click offers matching subfilters');
                bar.boxes[0].object.onValueChange(false);
                eq(hud.enabled(button.category.key, bar.boxes[0].key), false, 'HUD checkbox edits HUD preference');
            } else eq(G.field(button.object, 'onRightClick'), null, 'No empty submenu');
        }
        eq(bar.popup != null, true, 'Subfilter popup opened');
        var popup = bar.popup;
        bar.gear.object.onClick();
        eq(bar.root.visible, false, 'Gear closes filters');
        eq(bar.popup, null, 'Gear closes active subfilter popup');
        eq(popup.removed, true, 'Closed popup removed from input tree');
        bar.gear.object.onClick();
        bar.updateHud(160, false, 800, 600, 0, 0);
        var small = bar.root.scale;
        eq(bar.root.x >= 0, true, 'Left-edge map keeps buttons on screen');
        for (button in bar.buttons) eq(button.object.background.borderRadius.top, 6., 'Square map restores square buttons');
        bar.updateHud(400, false, 800, 600, 390, 190);
        eq(bar.root.scale / small, 2.5, 'Filter size scales proportionally with minimap size');
        var last = bar.buttons[bar.buttons.length - 1].object;
        eq(bar.root.y + (last.y + 48) * bar.root.scale <= 400.01, true, 'All nine categories fit along minimap');
        bar.buttons[2].object.onRightClick();
        eq(bar.popup.x + 390 >= 0 && bar.popup.x + 390 + 286 * bar.popup.scale <= 800, true, 'Popup stays inside horizontal viewport');
        eq(bar.popup.y + 190 >= 0 && bar.popup.y + 190 + 216 * bar.popup.scale <= 600, true, 'Popup stays inside vertical viewport');
        var saved = saves, positions = G.positionWrites;
        for (_ in 0...50) { hud.bind(restored); bar.updateHud(400, false, 800, 600, 390, 190); }
        eq(saves, saved, 'Idle HUD does not save config');
        eq(G.positionWrites, positions, 'Idle HUD does not relayout');
        var gear = bar.gear.object, root = bar.root;
        bar.dispose();
        eq(gear.removed && root.removed, true, 'Disposal removes controls');

        // Cached distant NPCs and loaded NPCs must both track character progress.
        var inf:Dynamic = {id:'quest', dialog:[], testGoals:[{}], props:{}};
        G.globals['HElement.npcs'] = [{mapId:'World/W1_Siagarta', inf:inf, prefab:{_41:10., _42:10., _43:0.}}];
        G.globals['activities'] = [];
        var progress:Dynamic = {questState:2};
        var layer:Dynamic = {units:[], interactibles:[]};
        var hero:Dynamic = {layer:layer, posx:0., posy:0., posz:0., player:{progress:progress}};
        var markers = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta');
        var settings:MinimapSettings = cast {showNpcs:true, markerScale:100.};
        var rifts = new minimap.RiftMarkers('World/W1_Siagarta');
        markers.update(hero, settings, 0, 0, 100, 1, 0, rifts);
        eq(markers.points[0].kind, 'quest', 'Distant active quest marker');
        progress.questState = 4; markers.nextRefresh = 0;
        markers.update(hero, settings, 0, 0, 100, 1, 0, rifts);
        eq(markers.points[0].kind, 'npc', 'Cached distant quest becomes ordinary NPC after completion');
        progress.questState = 1; markers.nextRefresh = 0;
        markers.update(hero, settings, 0, 0, 100, 1, 0, rifts);
        eq(markers.points[0].kind, 'quest', 'Newly available follow-up restores quest icon');
        layer.interactibles = [{family:'npc', enabled:true, kind:'quest', inf:inf, posx:12., posy:10., posz:0.}];
        progress.questState = 3; markers.nextRefresh = 0;
        markers.update(hero, settings, 0, 0, 100, 1, 0, rifts);
        eq(markers.points.length, 1, 'Live NPC replaces cached definition');
        eq(markers.points[0].kind, 'quest', 'Ready to turn in is still a quest');
        progress.questState = 4; markers.nextRefresh = 0;
        markers.update(hero, settings, 0, 0, 100, 1, 0, rifts);
        eq(markers.points[0].kind, 'npc', 'Loaded quest becomes ordinary NPC after completion');
        Sys.println('Minimap filter panel: $checks checks passed.');
    }
}
