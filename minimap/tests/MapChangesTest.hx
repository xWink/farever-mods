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
    static function near(a:Float, b:Float, why:String):Void {
        checks++; if (Math.abs(a-b) > 0.000001) throw why + ': expected $b, got $a';
    }
    static function layoutMigration():Void {
        for (old in [null, true, false]) {
            var config:MinimapSettings = cast {circular:old, minimapShape:null, filterButtonPosition:null};
            minimap.MinimapLayout.migrate(config);
            eq(config.minimapShape, old == false ? 'Square' : 'Circular', 'Existing checkbox and fresh shape defaults');
            eq(config.filterButtonPosition, 'Left', 'Filter controls default left');
            eq(Reflect.hasField(config, 'circular'), false, 'Legacy checkbox removed from saved config');
            config = haxe.Json.parse(haxe.Json.stringify(config));
            minimap.MinimapLayout.migrate(config);
            eq(config.minimapShape, old == false ? 'Square' : 'Circular', 'Migrated shape survives reload');
        }
        for (shape in ['Circular', 'Square']) {
            var config:MinimapSettings = cast {circular:shape == 'Square', minimapShape:shape, filterButtonPosition:'Right'};
            minimap.MinimapLayout.migrate(config);
            eq(config.minimapShape, shape, 'New dropdown overrides conflicting legacy key');
            eq(config.filterButtonPosition, 'Right', 'Right side survives normalization');
        }
        var invalid:MinimapSettings = cast {minimapShape:'Unknown', filterButtonPosition:'Unknown'};
        minimap.MinimapLayout.migrate(invalid);
        eq(invalid.minimapShape, 'Circular', 'Invalid shape falls back safely');
        eq(invalid.filterButtonPosition, 'Left', 'Invalid side falls back safely');
    }
    static function nativeStep(window:Dynamic, dt:Float):Void {
        var fraction = 1 - Math.pow(0.7, dt * 60);
        var p = window.panning, t = window.targetPanning;
        p.x = G.number(p.x) + (G.number(t.x) - G.number(p.x)) * fraction;
        p.y = G.number(p.y) + (G.number(t.y) - G.number(p.y)) * fraction;
    }
    static function bonusPanning():Void {
        var pan = new minimap.BonusDungeonPan();
        for (fps in [30,60,144]) {
            var w:Dynamic = {panning:{x:20.,y:-40.},tileScale:2.,zoom:0.5,targetZoom:0.5};
            pan.scrollTo(w, 300., 400.);
            // Four frames now equal one frame of the previous half-speed pan.
            for (_ in 0...4) { pan.beginUpdate(w); nativeStep(w, 1. / fps); pan.beforeScroll(w); }
            var fraction = 1 - Math.pow(0.7, 30. / fps);
            near(G.number(w.panning.x), 20 + 280 * fraction, 'Quarter of previous speed X at '+fps+'fps');
            near(G.number(w.panning.y), -40 + 440 * fraction, 'Quarter of previous speed Y at '+fps+'fps');
            eq(w.zoom, 0.5, 'Slower pan does not alter zoom');
            var x = G.number(w.panning.x); pan.beforeScroll(w);
            near(G.number(w.panning.x), x, 'Repeated scroll refresh cannot slow a frame twice');
        }
        for (input in ['pan','zoom','reset']) {
            var w:Dynamic = {panning:{x:0.,y:0.},tileScale:1.,zoom:1.,targetZoom:1.};
            pan.scrollTo(w, 300., 400.); pan.beginUpdate(w);
            if (input == 'pan') w.targetPanning.x = 500.;
            else if (input == 'zoom') w.targetZoom = 2.;
            else pan.reset();
            nativeStep(w, 1./60); var x = G.number(w.panning.x);
            pan.beforeScroll(w);
            near(G.number(w.panning.x), x, 'Manual '+input+' retains native speed');
            pan.beginUpdate(w); nativeStep(w, 1./60); x = G.number(w.panning.x); pan.beforeScroll(w);
            near(G.number(w.panning.x), x, 'Automatic pan stays cancelled after '+input);
        }
        var ordinary:Dynamic = {panning:{x:0.,y:0.},targetPanning:{x:50.,y:60.}};
        pan.beginUpdate(ordinary); nativeStep(ordinary, 1./60); pan.beforeScroll(ordinary);
        near(G.number(ordinary.panning.x), 15., 'Ordinary map panning is unaffected');
    }
    static function main():Void {
        layoutMigration();
        bonusPanning();
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
