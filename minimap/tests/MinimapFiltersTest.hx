import minimap.MinimapFilters;
import minimap.MainMapFilters;
import minimap.MainMapFilterBar;
import minimap.MainMapIconCache;
import minimap.MinimapMarkers;
import minimap.MinimapSettings;
import minimap.GameAccess as G;
@:access(minimap.MainMapFilterBar)
class MinimapFiltersTest {
    static var checks=0;
    static function eq(a:Dynamic,b:Dynamic,why:String):Void {checks++; if(a!=b)throw why+': expected $b, got $a';}
    static function main():Void {
        var c:MinimapSettings=cast {markerScale:110.,mainMapMarkerScale:140.,showOre:true,hideIron:true,
            hideMasteredCodexEnemies:false,hideCollectedCompanions:true,mainMapHiddenFilters:['ore:copper','npcs']};
        var saves=0,hud=new MinimapFilters(()->saves++),main=new MainMapFilters(); hud.bind(c); main.bind(c);
        eq(hud.enabled('ore','iron'),false,'Existing resource exclusion retained');
        eq(hud.enabled('enemies','mastered'),true,'Existing mastery preference retained');
        eq(hud.enabled('companions','collected'),false,'Existing collected preference retained');
        hud.setEnabled('ore',null,false); eq(c.showOre,false,'Toggle edits BMS preference');
        eq(main.settings().showOre,true,'Main map unaffected');
        main.setEnabled('ore','iron',false); hud.setEnabled('ore','iron',true);
        eq(c.hideIron,false,'Subfilter edits BMS'); eq(main.settings().hideIron,true,'Main-map subtype remains independent');
        eq(main.settings().hideCopper,true,'Main-map saved exclusion retained');
        for(category in MainMapFilters.CATEGORIES) {
            hud.setEnabled(category.key,null,false); eq(hud.enabled(category.key),false,'Disable '+category.key);
            hud.setEnabled(category.key,null,true); eq(hud.enabled(category.key),true,'Enable '+category.key);
            for(item in category.items) {
                hud.setEnabled(category.key,item.key,false); eq(hud.enabled(category.key,item.key),false,'Disable '+item.key);
                hud.setEnabled(category.key,item.key,true); eq(hud.enabled(category.key,item.key),true,'Enable '+item.key);
            }
        }
        hud.setEnabled('enemies','regular',false);
        eq(hud.accepts({kind:'enemy',x:0,y:0,z:0}),false,'Regular enemy subtype filtered');
        eq(hud.accepts({kind:'boss',x:0,y:0,z:0}),true,'Boss remains visible');
        hud.setEnabled('activities','rifts',false); eq(hud.accepts({kind:'riftPortal',x:0,y:0,z:0}),false,'Rifts subtype filtered');
        var reloaded:MinimapSettings=haxe.Json.parse(haxe.Json.stringify(c)); hud.bind(reloaded);
        eq(hud.enabled('enemies','regular'),false,'Subtypes persist');
        reloaded.showOre=false; hud.bind(Reflect.copy(reloaded)); eq(hud.enabled('ore'),false,'BMS edits reach HUD');
        var before=saves; hud.setEnabled('ore',null,false); eq(saves,before,'No redundant save');
        var panel:Dynamic={},root:Dynamic={dom:{}},cache=new MainMapIconCache([]);
        var markers=new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta');
        var bar=new MainMapFilterBar(root,hud,(parent,kind)->cache.bitmap(parent,kind,g->markers.drawFilterIcon(g,kind)),panel);
        bar.updateMinimap(700,36,250,true,1024,768); eq(bar.root.parent,panel,'Buttons belong to HUD layer');
        eq(bar.buttons.length,8,'Eight filter buttons'); var button=bar.buttons[0];
        eq(button.slash.visible,true,'Off state slashed'); button.object.onClick(); eq(button.slash.visible,false,'Click toggles category');
        eq(button.object.selected,true,'Border retained'); button.object.onRightClick();
        eq(bar.boxes.length,4,'Ore has four subfilters'); eq(bar.popup.parent,panel,'Popup stays below native windows');
        eq(bar.popup.x+700>=0,true,'Right-edge popup on screen'); bar.boxes[0].object.onValueChange(false);
        eq(hud.enabled('ore','copper'),false,'Popup changes HUD subfilter');
        bar.updateMinimap(36,36,160,false,640,480); eq(bar.round,false,'Square shape follows minimap');
        eq(bar.popup.x+36>=0,true,'Popup repositions with minimap'); eq(bar.popup.x+36+286*bar.popup.scale<=640,true,'Popup fits width');
        for(shape in [true,false])for(size in [160,250,400]) {
            var points=[for(i in 0...8)MainMapFilterBar.minimapButtonPosition(i,size,shape)];
            for(i in 0...points.length) {
                var p=points[i]; eq(p.x>=-MainMapFilterBar.HUD_MARGIN,true,'Left margin holds button');
                eq(p.x+32<=size+6+MainMapFilterBar.HUD_MARGIN,true,'Right margin holds button');
                eq(p.y>=0 && p.y+32<=size+6,true,'Clock/footer stay clear');
                for(j in 0...i){var q=points[j];eq(Math.abs(p.x-q.x)>=32 || Math.abs(p.y-q.y)>=32,true,'Button hitboxes do not overlap');}
            }
        }
        for(i in [5,6,7])eq(G.field(bar.buttons[i].object,'onRightClick'),null,'No NPC/chest/orb subfilters');
        var bakes=G.bakes,reductions=G.reductions;
        for(_ in 0...30)bar.updateMinimap(36,36,160,false,640,480);
        eq(G.bakes,bakes,'Idle buttons do not bake'); eq(G.reductions,reductions,'Idle smoothing reused');
        bar.setVisible(false); eq(bar.popup,null,'Hiding closes popup'); bar.dispose(); cache.dispose();
        Sys.println('Minimap filters: $checks checks passed.');
    }
}
