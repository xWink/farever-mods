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
    static function near(a:Float, b:Float, why:String):Void {
        checks++; if (Math.abs(a-b) > 0.000001) throw why + ': expected $b, got $a';
    }
    static function mirroredControls(filters:MainMapFilters):Void {
        for (round in [true, false]) for (size in [160,400]) for (edge in [true,false]) {
            var extent = size + (round ? 0 : 2 * minimap.MinimapGeometry.FRAME_BORDER);
            var screen = 1400., leftX = edge ? 0. : 450., rightX = screen - leftX - extent;
            var top = size == 400 ? 390. : 20.;
            var bars:Array<MainMapFilterBar> = [];
            for (_ in 0...2) {
                var container:Dynamic = {}; container.dom = {obj:container};
                bars.push(new MainMapFilterBar(container, filters, (parent, _) -> G.create('h2d.Graphics',[parent]), true));
            }
            var left = bars[0], right = bars[1];
            left.toggleExpanded(100); right.toggleExpanded(100);
            for (time in [100.,100.07,100.14,100.28,101.,101.07,101.14,101.28]) {
                if (time == 101.) { left.toggleExpanded(time); right.toggleExpanded(time); }
                left.updateHud(size, round, screen, 800, leftX, top, time, false);
                right.updateHud(size, round, screen, 800, rightX, top, time, true);
                var scale = G.number(left.root.scale), bw = 48 * scale;
                near(G.number(right.gear.object.x), extent - G.number(left.gear.object.x) - bw, 'Gear mirrors without mirroring its artwork');
                near(G.number(right.gear.object.y), G.number(left.gear.object.y), 'Gear preserves height');
                eq(right.root.visible, left.root.visible, 'Opening and closing visibility matches');
                for (i in 0...left.buttons.length) {
                    var a = left.buttons[i].object, b = right.buttons[i].object;
                    var ax = G.number(left.root.x) + G.number(a.x) * scale;
                    var bx = G.number(right.root.x) + G.number(b.x) * scale;
                    near(bx, extent - ax - bw, 'Every animation position is reflected');
                    near(G.number(b.y), G.number(a.y), 'Mirrored controls follow the same vertical path');
                    eq(rightX + bx >= 0 && rightX + bx + bw <= screen, true, 'Right rail remains on screen');
                }
                if (time == 100.28) {
                    left.buttons[2].object.onRightClick(); right.buttons[2].object.onRightClick();
                    var pw = 286 * G.number(right.popup.scale);
                    eq(Math.abs((leftX + G.number(left.popup.x)) + (rightX + G.number(right.popup.x)) + pw - screen) <= 1,
                        true, 'Popup placement and edge fallback mirror too');
                    eq(rightX + G.number(right.popup.x) >= 0 && rightX + G.number(right.popup.x) + pw <= screen,
                        true, 'Right popup stays visible');
                }
            }
            // Changing sides on an open panel preserves its expansion and filters.
            left.toggleExpanded(102); left.updateHud(size, round, screen, 800, leftX, top, 103);
            left.updateHud(size, round, screen, 800, rightX, top, 103, true);
            eq(left.expansion, 1., 'Side changes do not collapse an open panel');
            eq(left.rightSide, true, 'Changing only the side triggers relayout');
            for (bar in bars) bar.dispose();
        }
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

        G.globals['ui.BaseUI.current'] = {style:{}};
        mirroredControls(hud);
        var container:Dynamic = {dom:null}; container.dom = {obj:container};
        var icons:Array<String> = [];
        var bar = new MainMapFilterBar(container, hud, (parent, kind) -> {
            if (kind != 'filterRound' && kind != 'filterSquare') icons.push(kind);
            return G.create('h2d.Graphics', [parent]);
        }, true);
        bar.updateHud(250, true, 1920, 1080, 1660, 10);
        eq(G.styledObjects.indexOf(container) >= 0, true, 'Reparented HUD is registered for native styling');
        eq(icons.join(','), [for (c in MainMapFilters.CATEGORIES) c.icon].concat(['settings']).join(','),
            'HUD uses the same ordered category icons plus the gear');
        eq(bar.root.visible, false, 'Filter panel starts closed');
        bar.gear.object.onClick(); bar.updateHud(250, true, 1920, 1080, 1660, 10);
        eq(bar.root.visible, true, 'Gear starts opening filters');
        eq(Math.abs(G.number(bar.root.scale) / (250 / 534) - 1.12 * 1.10 * 1.05) < 0.00001, true, 'HUD buttons and their contents grow by another five percent');
        eq(bar.buttons[0].icon.scale, 1.35 * 1.20, 'HUD symbols grow twenty percent within buttons');
        var opening = bar.animationStart;
        bar.updateHud(250, true, 1920, 1080, 1660, 10, opening);
        var initialSaves = saves;
        bar.buttons[0].object.onClick(); bar.buttons[0].object.onRightClick();
        eq(saves, initialSaves, 'Moving buttons cannot accidentally toggle filters');
        eq(bar.popup, null, 'Moving buttons cannot open subfilters');
        var collapsedX = G.number(bar.root.x) + G.number(bar.buttons[0].object.x) * G.number(bar.root.scale);
        eq(Math.abs(collapsedX - G.number(bar.gear.object.x)) < 0.001, true, 'Buttons emerge from behind the gear');
        bar.updateHud(250, true, 1920, 1080, 1660, 10, opening + 0.14);
        eq(Math.abs(bar.expansion - 0.5) < 0.001, true, 'Opening has a smooth midpoint');
        var movingCenter = 125., movingRadius = movingCenter + 34 * G.number(bar.root.scale);
        for (button in bar.buttons) {
            var dx = (G.number(button.object.x) + 24) * G.number(bar.root.scale) - movingCenter;
            var dy = (G.number(button.object.y) + 24) * G.number(bar.root.scale) - movingCenter;
            eq(Math.abs(Math.sqrt(dx * dx + dy * dy) - movingRadius) < 0.001, true, 'Animation follows arc, not a chord');
        }
        bar.updateHud(250, true, 1920, 1080, 1660, 10, opening + 1);
        eq(bar.expansion, 1., 'Opening completes exactly at final positions');
        for (button in bar.buttons) {
            eq(button.roundFace.visible, true, 'Circular map has an explicit round button face');
            eq(button.squareFace.visible, false, 'Circular map hides square face');
            eq(button.object.background.visible, false, 'HUD does not depend on native window skin');
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
        eq(bar.boxes[0].object.nativeType, 'check-box', 'HUD uses the same native checkbox as main map');
        var arcScale = G.number(bar.root.scale), center = 125., radius = center + 34 * arcScale;
        for (button in bar.buttons) {
            var dx = (G.number(button.object.x) + 24) * arcScale - center;
            var dy = (G.number(button.object.y) + 24) * arcScale - center;
            eq(Math.abs(Math.sqrt(dx * dx + dy * dy) - radius) < 0.001, true, 'Buttons follow the circular rim');
        }
        eq(G.number(bar.buttons[0].object.x) > G.number(bar.buttons[4].object.x), true, 'Upper buttons curve inward');
        eq(G.number(bar.buttons[8].object.x) > G.number(bar.buttons[4].object.x), true, 'Lower buttons curve inward');
        eq(G.number(bar.popup.x) == Math.round(G.number(bar.popup.x)) && G.number(bar.popup.y) == Math.round(G.number(bar.popup.y)), true, 'Popup origin is pixel aligned');
        var close = G.created.filter(o -> G.field(G.field(o, 'dom'), 'id') == 'mainMapFilterClose').pop();
        eq(close.nativeType, 'button', 'Close has native hover and pressed styling');
        G.globals['keyFrame'] = 100; G.globals['mouseDown'] = true;
        eq(bar.blocksAttackClick(), false, 'Unrelated clicks are not blocked');
        close.onPush();
        eq(bar.blocksAttackClick(), true, 'Close press blocks attacks');
        G.globals['keyFrame'] = 120;
        eq(bar.blocksAttackClick(), true, 'Holding close cannot attack');
        G.globals['mouseDown'] = false;
        close.onClick();
        eq(bar.popup, null, 'Native close dismisses popup');
        eq(bar.blocksAttackClick(), true, 'Release remains consumed after popup removal');
        eq(bar.blocksAttackClick(), true, 'All input polls in release frame remain blocked');
        G.globals['keyFrame'] = 121;
        eq(bar.blocksAttackClick(), false, 'Following independent click can attack normally');
        bar.buttons[0].object.onRightClick();
        var popup = bar.popup;
        bar.gear.object.onClick();
        eq(bar.root.visible, true, 'Closing remains visible during retraction');
        var closing = bar.animationStart;
        bar.updateHud(250, true, 1920, 1080, 1660, 10, closing + 0.14);
        var halfClosed = bar.expansion;
        bar.toggleExpanded(closing + 0.14);
        eq(bar.expansion, halfClosed, 'Mid-animation reversal does not snap');
        bar.updateHud(250, true, 1920, 1080, 1660, 10, closing + 1);
        eq(bar.expansion, 1., 'Reversed animation opens fully');
        bar.toggleExpanded(closing + 1);
        bar.updateHud(250, true, 1920, 1080, 1660, 10, closing + 2);
        eq(bar.root.visible, false, 'Root hides only after retraction completes');
        eq(bar.expansion, 0., 'Closing returns to gear');
        eq(bar.popup, null, 'Gear closes active subfilter popup');
        eq(popup.removed, true, 'Closed popup removed from input tree');
        bar.gear.object.onClick();
        bar.updateHud(160, false, 800, 600, 0, 0, bar.animationStart + 0.14);
        for (button in bar.buttons) eq(G.number(button.object.x) == 0. || G.number(button.object.y) == 0., true,
            'Square animation moves left before descending the side');
        bar.updateHud(160, false, 800, 600, 0, 0, bar.animationStart + 1);
        bar.updateHud(160, false, 800, 600, 400, 100);
        eq(G.number(bar.gear.object.y), 0., 'Square gear returns to the top edge of the map');
        eq(G.number(bar.gear.object.x), 0., 'Square gear is inside the top-left map corner');
        bar.updateHud(160, false, 800, 600, 0, 0);
        var small = G.number(bar.root.scale);
        eq(G.number(bar.root.x) >= 0, true, 'Left-edge map keeps buttons on screen');
        for (button in bar.buttons) {
            eq(button.squareFace.visible, true, 'Square map restores square button faces');
            eq(button.roundFace.visible, false, 'Square map hides round faces');
        }
        bar.updateHud(400, false, 800, 600, 390, 190);
        eq(Math.abs(G.number(bar.root.scale) / small - 2.5) < 0.00001, true, 'Filter size scales proportionally with minimap size');
        var last = bar.buttons[bar.buttons.length - 1].object;
        eq(190 + G.number(bar.root.y) + (G.number(last.y) + 48) * G.number(bar.root.scale) <= 600, true, 'Larger column stays within viewport');
        bar.updateHud(250, false, 1920, 1080, 1660, 10);
        bar.expansion = 0; bar.layoutHud();
        for (button in bar.buttons) {
            eq(Math.abs(G.number(bar.root.x) + G.number(button.object.x) * G.number(bar.root.scale) - G.number(bar.gear.object.x)) < 0.001,
                true, 'Square filters start behind the inside gear');
            eq(button.object.y, 0., 'Square filters start at the top edge');
        }
        var leftLeg = (G.number(bar.gear.object.x) - G.number(bar.root.x)) / G.number(bar.root.scale);
        bar.expansion = 0.01; bar.layoutHud();
        for (button in bar.buttons) {
            eq(button.object.y, 0., 'Square filters first travel horizontally');
            eq(G.number(button.object.x) > 0 && G.number(button.object.x) < leftLeg, true,
                'Square filters emerge to the left of the gear');
        }
        bar.expansion = 1; bar.layoutHud();
        var side = bar.buttons.filter(b -> G.number(b.object.y) * G.number(bar.root.scale) < 261.99);
        var underside = bar.buttons.filter(b -> G.number(b.object.y) * G.number(bar.root.scale) >= 261.99);
        eq(side.length, 8, 'First category occupies the former gear slot above the seven side slots');
        eq(underside.length, 1, 'Last category occupies the lower-left corner');
        eq(G.number(underside[0].object.x), 0., 'First overflow button fills the lower-left corner');
        var stride = G.number(underside[0].object.y) / 8, previousY = -stride;
        for (button in side.concat([underside[0]])) {
            eq(Math.abs(G.number(button.object.y) - previousY - stride) < 0.001, true, 'Every vertical slot is evenly occupied through the corner');
            previousY = G.number(button.object.y);
        }
        var sideGap = -(G.number(bar.root.x) + 48 * G.number(bar.root.scale));
        var bottomGap = G.number(bar.root.y) + G.number(underside[0].object.y) * G.number(bar.root.scale) - (250 + 2 * minimap.MinimapGeometry.FRAME_BORDER);
        eq(Math.abs(bottomGap - sideGap) < 0.001, true, 'Bottom and side gaps match at the outer map border');
        for (button in underside) eq(Math.abs(G.number(button.object.y) * G.number(bar.root.scale) - 262) < 0.001, true, 'Overflow buttons sit below the bottom edge');
        eq(G.number(bar.buttons[0].object.x), 0., 'First filter aligns with the old gear X');
        eq(G.number(bar.buttons[0].object.y), 0., 'First filter starts at the old gear Y');
        bar.updateHud(400, false, 800, 600, 390, 190);
        var wrapped = bar.buttons[bar.buttons.length - 1].object;
        eq(G.number(wrapped.x) > 0, true, 'Limited vertical room still wraps filters under the map');
        var turn = G.number(wrapped.y), lead = (G.number(bar.gear.object.x) - G.number(bar.root.x)) / G.number(bar.root.scale);
        bar.expansion = (lead + turn + G.number(wrapped.x) / 2) / (lead + turn + G.number(wrapped.x));
        bar.layoutHud();
        eq(G.number(wrapped.x) > 0 && Math.abs(G.number(wrapped.y) - turn) < 0.001, true, 'Animation travels around the L corner');
        bar.expansion = 1; bar.layoutHud();
        bar.updateHud(400, false, 800, 600, 390, 190);
        bar.buttons[2].object.onRightClick();
        eq(G.number(bar.popup.x) + 390 >= 0 && G.number(bar.popup.x) + 390 + 286 * G.number(bar.popup.scale) <= 800, true, 'Popup stays inside horizontal viewport');
        eq(G.number(bar.popup.y) + 190 >= 0 && G.number(bar.popup.y) + 190 + 216 * G.number(bar.popup.scale) <= 600, true, 'Popup stays inside vertical viewport');
        var saved = saves, positions = G.positionWrites;
        for (_ in 0...50) { hud.bind(restored); bar.updateHud(400, false, 800, 600, 390, 190); }
        eq(saves, saved, 'Idle HUD does not save config');
        eq(G.positionWrites, positions, 'Idle HUD does not relayout');
        var gear = bar.gear.object, root = bar.root;
        bar.dispose();
        eq(gear.removed && root.removed, true, 'Disposal removes controls');
        eq(G.styledObjects.indexOf(container), -1, 'Disposal unregisters detached HUD style root');
        eq(bar.blocksAttackClick(), false, 'Disposal clears click guard');

        // Cached distant NPCs and loaded NPCs must both track character progress.
        var inf:Dynamic = {id:'quest', dialog:[], testGoals:[{}], props:{}};
        G.globals['HElement.npcs'] = [{mapId:'World/W1_Siagarta', inf:inf, prefab:{_41:10., _42:10., _43:0.}}];
        G.globals['activities'] = [];
        var progress:Dynamic = {questState:2};
        var layer:Dynamic = {world:{level:"World/W1_Siagarta"}, units:[], interactibles:[]};
        var hero:Dynamic = {layer:layer, posx:0., posy:0., posz:0., player:{progress:progress}};
        var markers = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta');
        var settings:MinimapSettings = cast {showNpcs:true, markerScale:100., hideCompletedActivities:true};
        var rifts = new minimap.RiftMarkers('World/W1_Siagarta');
        markers.update(hero, settings, 0, 0, 100, 1, 0, rifts);
        eq(markers.points[0].kind, 'quest', 'Distant active quest marker');
        progress.questState = 4; markers.nextRefresh = 0;
        markers.update(hero, settings, 0, 0, 100, 1, 0, rifts);
        eq(markers.points[0].kind, 'npc', 'Cached distant quest becomes ordinary NPC after completion');
        settings.hideCompletedActivities = false; markers.nextRefresh = 0;
        markers.update(hero, settings, 0, 0, 100, 1, 0, rifts);
        eq(markers.points[0].kind, 'quest', 'Showing completed activities restores distant completed quest artwork');
        settings.hideCompletedActivities = true;
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
        settings.hideCompletedActivities = false; markers.nextRefresh = 0;
        markers.update(hero, settings, 0, 0, 100, 1, 0, rifts);
        eq(markers.points[0].kind, 'quest', 'Showing completed activities restores loaded completed quest artwork');
        Sys.println('Minimap filter panel: $checks checks passed.');
    }
}
