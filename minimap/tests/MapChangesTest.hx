import minimap.BigMapView;
import minimap.MainMapFilters;
import minimap.MapPoint;
import minimap.MapVisibility;
import minimap.MinimapSettings;
import minimap.GameAccess as G;

@:access(BigMapTest)
@:access(minimap.BigMapView)
@:access(minimap.MinimapMarkers)
@:access(minimap.MainMapBonusDungeon)
class MapChangesTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, why:String):Void {
        checks++;
        if (a != b) throw why + ': expected ' + b + ', got ' + a;
    }
    static function point(kind:String):MapPoint return {kind:kind, x:0., y:0., z:0.};
    static function main():Void {
        var fresh:MinimapSettings = cast {};
        MapVisibility.migrate(fresh);
        eq(fresh.mainMapEnabled, true, 'Main map defaults on');
        eq(fresh.minimapEnabled, true, 'Minimap defaults on');
        var legacy:MinimapSettings = cast {enabled:false};
        MapVisibility.migrate(legacy);
        eq(legacy.mainMapEnabled, false, 'Legacy disabled preference survives for main map');
        eq(legacy.minimapEnabled, false, 'Legacy disabled preference survives for minimap');
        eq(Reflect.hasField(legacy, 'enabled'), false, 'Legacy global switch is removed');
        legacy.mainMapEnabled = true;
        MapVisibility.migrate(legacy);
        eq(legacy.mainMapEnabled, true, 'Explicit main-map preference survives normalization');
        eq(legacy.minimapEnabled, false, 'Main-map change does not enable minimap');

        var config = BigMapTest.config();
        config.useSameMapFilters = false;
        var main = new MainMapFilters(), hud = new MainMapFilters(null, true);
        main.bind(config); hud.bind(config);
        var groups = [
            {category:'activities', key:'dungeon', kinds:['dungeon']},
            {category:'activities', key:'rifts', kinds:['inactiveRift','nextRift','upcomingRift','riftPortal']},
            {category:'activities', key:'soulstone', kinds:['soulstone']},
            {category:'npcs', key:'obelisk', kinds:['obelisk']},
            {category:'npcs', key:'respawn', kinds:['respawn']},
            {category:'npcs', key:'factionMerchant', kinds:['pilgrim','demon','glory']},
            {category:'npcs', key:'station', kinds:['craft','upgrade','recycler','infusion','soulWell']}
        ];
        for (group in groups) {
            main.setEnabled(group.category, group.key, false);
            hud.bind(config);
            var restored = new MainMapFilters();
            restored.bind(haxe.Json.parse(haxe.Json.stringify(config)));
            for (kind in group.kinds) {
                eq(main.accepts(point(kind)), false, 'Main-map subtype hides ' + kind);
                eq(hud.accepts(point(kind)), true, 'Unlinked minimap preserves ' + kind);
                eq(restored.accepts(point(kind)), false, 'Saved subtype restores ' + kind);
            }
            eq(main.accepts(point('quest')), true, 'Service filters retain quest NPCs');
            eq(main.accepts(point('bank')), true, 'Service filters retain guild merchant');
            main.setEnabled(group.category, group.key, true);
        }

        var world:Dynamic = {level:'World/W1_Siagarta'};
        var inf:Dynamic = {id:'questNpc',dialog:[],testGoals:[{}],props:{}};
        G.globals['HElement.npcs'] = [{mapId:world.level,inf:inf,prefab:{_41:30.,_42:40.,_43:0.}}];
        G.globals['HElement.obelisks'] = [{mapId:world.level,inf:{id:'obelisk'},prefab:{_41:50.,_42:60.,_43:0.}}];
        var icons:Map<String,Dynamic> = [];
        for (state in 1...5) icons['NativeQuestState'+state] = {gfx:{tile:{width:32.,height:32.,source:'native'+state}}};
        G.globals['Data.icon'] = {byId:icons};
        G.globals['HActivity.allActivities'] = new Map<String,Dynamic>();
        G.globals['activities'] = [{inf:{id:'DungeonOne',inherit:'Dungeon'},prefab:{},position:{x:300.,y:400.,z:0.}}];
        G.globals['activity:DungeonOne'] = {id:'DungeonOne',inherit:'Dungeon',label:'Test Dungeon'};
        var progress:Dynamic = {questState:1};
        var layer:Dynamic = {world:world,units:[],interactibles:[]};
        var hero:Dynamic = {layer:layer,player:{progress:progress},posx:0.,posy:0.,posz:0.,rotationZ:0.,
            specialization:{bonusHeroicDungeon:{activity:'DungeonOne'}}};
        var window:Dynamic = {hero:hero,scroll:{x:0.,y:0.},scrollContainer:{calculatedWidth:1000.,calculatedHeight:800.},
            markers:[],tileScale:2.,zoom:0.5,targetZoom:0.5,removed:false};
        window.scrollContainer.dom = {obj:window.scrollContainer};
        var view = new BigMapView();
        config = BigMapTest.config();
        config.minimapEnabled = false;
        view.update(window, config);
        eq(view.root != null, true, 'Main map stays active with minimap disabled');
        for (loaded in [false,true]) {
            layer.interactibles = loaded ? [{family:'npc',kind:'questNpc',enabled:true,inf:inf,posx:30.,posy:40.,posz:0.}] : [];
            for (state in [1,2,3,2,1,4,3]) {
                progress.questState = state; view.markers.nextRefresh = 0;
                view.update(window, config);
                var npc = view.markers.points.filter(p -> p.kind == 'quest' || p.kind == 'npc')[0];
                eq(npc.kind, state == 4 ? 'npc' : 'quest', 'Completion classification: loaded='+loaded+' state='+state);
                if (state != 4) {
                    eq(npc.questIcon, 'NativeQuestState'+state, 'Native quest state icon: loaded='+loaded+' state='+state);
                    eq(view.markers.npcIconMarkers[0].key.indexOf(':quest:'+state+':') >= 0, true, 'Quest state invalidates cached artwork');
                    eq(G.tileDraws.filter(t -> t.source == 'native'+state).length > 0, true, 'Quest marker uses a cached native atlas image');
                }
            }
        }
        view.filters.setEnabled('activities', null, false);
        view.update(window, config);
        eq(view.markers.points.filter(p -> p.kind == 'dungeon').length, 0, 'Activities toggle hides dungeon marker');
        var event:Dynamic = {button:0,propagate:true};
        view.bonusDungeon.input.onClick(event);
        eq(window.scrolledTo.x, 300., 'Bonus card pans to dungeon world X even with hidden marker');
        eq(window.scrolledTo.y, 400., 'Bonus card pans to dungeon world Y');
        eq(window.targetPanning.x, 300., 'Native target centers dungeon using tile scale and zoom');
        eq(window.zoom, 0.5, 'Bonus click preserves zoom');
        eq(event.propagate, false, 'Bonus click does not trigger map interactions');
        var definitions:Map<String,Dynamic> = ['DungeonOne' => {inf:{id:'DungeonOne',inherit:'Dungeon',props:{}}}];
        G.globals['HActivity.allActivities'] = definitions;
        G.globals['HElement.instanceOrbs'] = [{mapId:world.level,inf:{props:{targetActivity:'DungeonOne'}},
            prefab:{_41:1234.,_42:5678.,_43:0.}}];
        view.bonusDungeon.input.onClick({button:0,propagate:true});
        eq(window.scrolledTo.x, 1234., 'Dungeon entrance takes precedence over interior coordinates');
        eq(window.scrolledTo.y, 5678., 'Bonus navigation uses the same entrance as dungeon markers');
        window.scrolledTo = null;
        view.bonusDungeon.input.onClick({button:1,propagate:true});
        eq(window.scrolledTo, null, 'Right click does not navigate');
        hero.specialization.bonusHeroicDungeon = null;
        view.bonusDungeon.nextSample = 0; view.update(window, config);
        view.bonusDungeon.input.onClick({button:0,propagate:true});
        eq(window.scrolledTo, null, 'Unassigned bonus never pans to stale dungeon');
        view.filters.setEnabled('npcs', null, false);
        view.update(window, config);
        eq(view.markers.points.filter(p -> p.kind == 'obelisk').length, 0, 'NPC toggle hides ordinary-map obelisks');
        window.selector = true; view.update(window, config);
        eq(view.markers.points.filter(p -> p.kind == 'obelisk').length, 1, 'Fast travel retains usable destinations');
        config.mainMapEnabled = false; view.update(window, config);
        eq(view.root, null, 'Main map switch restores native map');
        eq(config.minimapEnabled, false, 'Main-map toggle leaves minimap preference intact');
        Sys.println('Map changes: '+checks+' checks passed.');
    }
}
