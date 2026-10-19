import minimap.BigMapView;
import minimap.MapDiscovery;
import minimap.MinimapFog;
import minimap.MinimapMarkers;
import minimap.NativeMarkerIcons;
import minimap.NpcMarkers;
import minimap.GameAccess as G;

@:access(BigMapTest)
@:access(minimap.BigMapView)
@:access(minimap.BigMapNativeMarkers)
@:access(minimap.MinimapMarkers)
@:access(minimap.MinimapFog)
@:access(minimap.RiftMarkers)
class MapRefinementsTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, message:String):Void {
        checks++;
        if (a != b) throw message + ': expected ' + b + ', got ' + a;
    }
    static function near(a:Float, b:Float, message:String):Void {
        checks++;
        if (Math.abs(a-b) > 0.000001) throw message + ': expected ' + b + ', got ' + a;
    }
    static function main():Void {
        var region = {id:'region', type:1};
        var cave = {id:'cave', type:2};
        var progress:Dynamic = {lockedZone:'region', lockedElement:'tower', unexploredZone:'cave'};
        var world:Dynamic = {level:'World/W1_Siagarta', terrainData:{chunkSize:32}, zoneAt:(_:Dynamic) -> region};
        var layer:Dynamic = {world:world, units:[], interactibles:[]};
        var hero:Dynamic = {layer:layer, player:{progress:progress}, posx:0., posy:0., posz:100., rotationZ:0.};
        var point:minimap.MapPoint = {kind:'obelisk', inf:{id:'tower'}, x:50., y:60., z:0.};
        var discovery = new MapDiscovery();
        discovery.sample(hero);
        eq(discovery.accepts(point), false, 'Markers do not reveal a locked region');
        eq(MapDiscovery.travelUnlocked(point,hero), false, 'Unactivated travel destination rejected');
        progress.lockedZone = null; progress.lockedElement = null;
        discovery.sample(hero);
        eq(discovery.accepts(point), true, 'Activation reveals previously cached region');
        eq(MapDiscovery.travelUnlocked(point,hero), true, 'Activation enables travel');
        eq(discovery.fogVisible(cave), false, 'Unexplored cave retains fog');
        progress.unexploredZone = null; discovery.sample(hero);
        eq(discovery.fogVisible(cave), true, 'Explored cave in unlocked region reveals');
        eq(discovery.regionVisible(null), false, 'Unknown region does not disclose markers');

        var bakedZones:Map<String,Dynamic> = ['region'=>region,'interior'=>{id:'interior',type:1}];
        G.globals['Data.zone'] = {byId:bakedZones};
        world.zoneAt = (_:Dynamic) -> null;
        var early = new MapDiscovery(); early.sample(hero);
        var entrance:minimap.MapPoint = {kind:'dungeon',x:300.,y:200.,z:0.,zoneBaked:'region',inf:{zoneBaked:'interior'}};
        progress.lockedZone = 'interior'; early.sample(hero);
        eq(early.accepts(entrance),true,'Unlocked entrance appears before terrain loads, regardless of interior');
        early.window = {zoneAt:world.zoneAt};
        eq(early.accepts(entrance),true,'Main map also uses baked entrance region');
        var npc:minimap.MapPoint = {kind:'npc',x:301.,y:200.,z:0.,inf:{zoneBaked:'region'}};
        eq(early.accepts(npc),true,'Static NPC appears without terrain');
        var foe:minimap.MapPoint = {kind:'enemy',x:302.,y:200.,z:0.,entity:{spawner:{inf:{zoneBaked:'region'}}}};
        eq(early.accepts(foe),true,'Available enemy uses its spawner region');
        progress.lockedZone = 'region'; early.sample(hero);
        eq(early.accepts(entrance),false,'Baked metadata never bypasses locked regions');
        eq(early.accepts(npc),false,'NPC in locked region stays hidden');
        eq(early.accepts(foe),false,'Enemy in locked region stays hidden');
        progress.lockedZone = null; early.sample(hero);
        entrance.zoneBaked = '';
        eq(early.accepts(entrance),false,'Unknown entrance never falls back to interior metadata');
        npc.inf.zoneBaked = 'late';
        eq(early.accepts(npc),false,'Unavailable definition remains hidden');
        bakedZones['late'] = {id:'late',type:1};
        eq(early.accepts(npc),true,'Missing definitions are retried when available');
        world.zoneAt = (_:Dynamic) -> region;

        for (unit in ['HildaLambert','NellyXyr'])
            eq(NpcMarkers.kind({props:{npc:{unit:unit}}}), 'pilgrim', 'Faction merchant unit: '+unit);
        eq(NpcMarkers.kind({props:{npc:{unit:'GenericHuman'}}, texts:{name:'Nelly Xyr'}}), 'pilgrim', 'Named merchant with reused model');
        eq(MinimapMarkers.markerRadius('demon'), 9 * 0.8, 'Huntress icon twenty percent smaller');
        eq(MinimapMarkers.markerRadius('soulWell'), 10 * 0.8, 'Soul well icon twenty percent smaller');

        var icons:Map<String,Dynamic> = ['Dungeon'=>{gfx:{tile:{x:256.,y:0.,width:128.,height:128.,source:'Dungeon'}}},
            'Dungeon_BonusReward'=>{gfx:{tile:{x:48.,y:24.,width:24.,height:24.,source:'Bonus'}}}];
        G.globals['Data.icon'] = {byId:icons};
        G.globals['Data.faction'] = {byId:[
            'Pilgrims'=>{gfx:{tile:{width:200.,height:248.,source:'Pilgrims'}}},
            'Riftstalkers'=>{gfx:{tile:{x:200.,y:0.,width:200.,height:248.,source:'Riftstalkers'}}}
        ]};
        var art = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta');
        art.graphics = {};
        art.drawIcon({kind:'dungeon', x:0, y:0, z:0, bonusDungeon:true});
        eq(G.tileDraws[G.tileDraws.length-2].source, 'Dungeon', 'Dungeon uses native atlas');
        eq(G.tileDraws[G.tileDraws.length-1].source, 'Bonus', 'Heroic bonus uses native green plus');
        eq(icons['Dungeon'].gfx.tile.width,128.,'Resizing does not mutate native tile');
        art.drawIcon({kind:'pilgrim', x:0,y:0,z:0});
        eq(G.tileDraws[G.tileDraws.length-1].source,'Pilgrims','Faction merchant uses native banner');
        var regions = G.textureRegions;
        var dungeon = regions[regions.length-3], bonus = regions[regions.length-2], pilgrim = regions[regions.length-1];
        near(dungeon.x,256,'Dungeon begins at the atlas cell origin');
        near(dungeon.width,128,'Complete dungeon artwork is sampled, not a transparent corner');
        near(dungeon.height,128,'Complete dungeon artwork height');
        near(bonus.x,48,'Bonus symbol atlas X origin');
        near(bonus.y,24,'Bonus symbol atlas Y origin');
        near(bonus.width,24,'Full bonus symbol sampled');
        near(bonus.drawWidth,20.8,'Bonus plus is thirty percent larger');
        near(pilgrim.width,200,'Full Pilgrims banner width sampled');
        near(pilgrim.height,248,'Full Pilgrims banner height sampled');
        art.drawIcon({kind:'demon',x:0,y:0,z:0});
        eq(G.tileDraws[G.tileDraws.length-1].source,'Riftstalkers','Demon Huntress uses the native faction banner');
        var faction = G.textureRegions[G.textureRegions.length-1];
        near(faction.x,200,'Riftstalkers samples the second faction banner');
        near(faction.width,200,'Full Riftstalkers banner width sampled');
        near(faction.height,248,'Full Riftstalkers banner height sampled');

        G.recordShapes = true; G.shapes = [];
        art.drawIcon({kind:'companion',x:0,y:0,z:0});
        G.recordShapes = false;
        var stroke = 0., toes = 0, pads = 0;
        for (command in G.shapes) {
            if (command.name == 'lineStyle') stroke = G.number(command.args[0]);
            if (command.name == 'drawCircle') {
                toes++;
                near(stroke,0.65,'Each toe outline has half the previous thickness');
                near(G.number(command.args[2]),7*0.23,'Outline preserves each toe size and position');
            }
            if (command.name == 'moveTo') { pads++; near(stroke,0.65,'Paw pad outline has half the previous thickness'); }
        }
        eq(toes,4,'Exactly four outlined toes, without a displaced silhouette');
        eq(pads,1,'Exactly one outlined pad');
        eq(stroke,0.,'Paw resets line style for subsequent artwork');

        var friend:minimap.MapPoint = {kind:'player',friend:true,x:0,y:0,z:0,heading:0,entity:{name:'Friend'}};
        var party:minimap.MapPoint = {kind:'player',partyMember:true,friend:true,x:0,y:0,z:0,heading:0,entity:{name:'Party'}};
        var services:Array<minimap.MapPoint> = [{kind:'demon',x:0,y:0,z:0},{kind:'soulWell',x:0,y:0,z:0}];
        art.showOwn = false;
        art.draw(services.concat([party,friend]),1);
        eq(art.hitPoints[0].kind,'soulWell','Soul Well is behind Demon Huntress');
        eq(art.hitPoints[1].kind,'demon','Demon Huntress is above Soul Well');
        eq(art.hitPoints[2],friend,'Friends are above services');
        eq(art.hitPoints[3],party,'Party remains above friends');
        eq(art.partyIconMarkers.length,2,'Friends and party share the foreground layer');
        eq(art.playerIconMarkers.length,0,'Friends are removed from ordinary player layer');
        eq(art.hoverAt(0,0,1,100,100,hero).name,'Party','Party wins overlapping hover');
        art.draw(services.concat([friend]),1);
        eq(art.hoverAt(0,0,1,100,100,hero).name,'Friend','Friend wins hover over services');
        var obelisk:minimap.MapPoint = {kind:'obelisk',x:0,y:0,z:0,name:'Obelisk'};
        art.draw(services.concat([obelisk,friend,party]),1);
        eq(art.hitPoints[2],obelisk,'Obelisk is above all services');
        eq(art.hitPoints[3],friend,'Friends remain above obelisks');
        eq(art.hitPoints[4],party,'Party remains top priority');
        eq(art.npcIconMarkers[2].key,'obelisk','Obelisk artwork follows NPCs in their foreground layer');
        art.draw(services.concat([obelisk]),1);
        eq(art.hoverAt(0,0,1,100,100,hero).name,'Obelisk','Obelisk wins hover over services');

        G.globals['HElement.obelisks'] = [{mapId:world.level, inf:point.inf, prefab:{_41:50.,_42:60.,_43:0.}}];
        G.globals['HActivity.allActivities'] = new Map<String,Dynamic>();
        G.globals['activities'] = [];
        var window:Dynamic = {hero:hero, selector:true, zoneAt:world.zoneAt, scroll:{x:0.,y:0.},
            scrollContainer:{calculatedWidth:1000.,calculatedHeight:800.}, markers:[], zoom:1., tileScale:1., removed:false};
        window.scrollContainer.dom = {obj:window.scrollContainer};
        window.mapContainer = {interactive:{width:1000.,height:800.}};
        var native = BigMapTest.nativeMarker(window,15,50,60); native.element = point.inf;
        var clicks = 0; native.content.onClick = () -> clicks++;
        var routeEnters = 0, routeExits = 0;
        native.content.onOver = () -> routeEnters++;
        native.content.onOut = () -> routeExits++;
        var view = new BigMapView(); var config = BigMapTest.config();
        view.update(window,config);
        eq(view.markers.points.length,1,'Unlocked travel marker visible');
        eq(view.markers.mapElevationMarkers.length,0,'Travel has no height arrows');
        var record = view.nativeMarkers.originals.get(native);
        var hit = record.target;
        eq(hit.isEllipse,true,'Travel target is a circle');
        var radius = view.markers.hitRadius(point) * 1.5;
        eq(hit.width,radius*2,'Entire ring width is clickable');
        eq(hit.x,point.x-radius,'Clickable circle is centered on artwork');
        eq(radius > 8*1.47*2.25,true,'Ring encloses the complete obelisk artwork');
        var event:Dynamic = {button:0,propagate:true,relX:radius*1.9,relY:radius};
        // The native boundary normally supplies the target's global transform.
        hit.absX = hit.x; hit.absY = hit.y;
        hit.onOver(event); view.updateHover();
        eq(routeEnters,1,'Outer ring invokes native route preview');
        hit.onMove(event);
        eq(routeEnters,1,'Moving within ring does not rebuild route');
        hit.onOut(event);
        eq(routeExits,1,'Leaving ring clears native route preview');
        hit.onOver(event); view.updateHover();
        eq(view.caption.text, 'tower', 'Hover near outer ring resolves obelisk caption');
        hit.onClick(event);
        eq(clicks,1,'Outer ring delegates to native travel action');
        eq(event.propagate,false,'Travel click does not reach the game');
        progress.lockedElement = 'tower'; hit.onClick(event);
        eq(clicks,1,'Stale target cannot travel after unlock state changes');
        view.markers.nextRefresh = 0; view.update(window,config);
        eq(view.markers.points.length,0,'Locked destination disappears');
        eq(native.visible,false,'Locked native destination cannot remain clickable');
        eq(hit.removed,true,'Stale expanded hit area removed');
        eq(routeExits,2,'Filtering hovered destination clears route preview');
        progress.lockedElement = null;
        var timerMarker = BigMapTest.nativeMarker(window,13,100,120);
        timerMarker.activity = {id:'Rift'};
        timerMarker.eventTimer = {font:{size:18,sdfCutoff:0.5},scaleX:1.,textColor:0xffffff,smooth:true,
            letterSpacing:0.5,dropShadow:{dx:0.,dy:1.,color:0,alpha:0.5}};
        window.dom = {obj:window};
        window.selector = false; view.update(window,config);
        view.markers.sampledPoints = [{kind:'nextRift',x:100.,y:120.,z:0.}];
        view.markers.revision++; view.rifts.remaining = 125;
        config.clockTimerMode = 'None'; view.updateRiftLabel();
        eq(view.riftLabel.text,'02:05','Map countdown independent of minimap None setting');
        eq(view.riftFontSource.styleClass,'bold-16','Countdown uses the same stylesheet font as the minimap timer');
        eq(view.riftFontSource.visible,false,'Font source stays hidden');
        eq(view.riftLabel.font,view.riftFontSource.font,'Countdown uses the styled timer font');
        eq(view.riftLabel.color,0xffffff,'Countdown keeps its existing color');
        eq(G.field(view.riftLabel,'filter'),null,'Countdown has no outline filter');
        eq(view.riftLabel.dropShadow.color,0x171b24,'Countdown uses the minimap shadow color');
        near(view.riftLabel.dropShadow.dx * view.riftLabelScale,1.,'Shadow offset stays one screen pixel');
        near(view.riftLabelScale * view.riftLabel.font.size,18.,'Font switch preserves current display size');
        var styledSource = view.riftFontSource;
        styledSource.font = {size:32}; view.updateRiftLabel();
        eq(view.riftLabel.font,styledSource.font,'Countdown follows late style and locale updates');
        near(view.riftLabelScale * view.riftLabel.font.size,18.,'Font refresh preserves display size');
        config.clockTimerMode = 'Clock'; view.updateRiftLabel();
        eq(view.riftLabel.text,'02:05','Map countdown independent of minimap Clock setting');
        eq(view.riftLabel.y > 120,true,'Countdown appears below the next rift');
        view.markers.sampledPoints = []; view.markers.revision++; view.updateRiftLabel();
        eq(view.riftLabel.visible,false,'Hidden-region rift has no floating countdown');
        view.dispose();
        eq(styledSource.removed,true,'Closing the map removes its hidden font source');

        G.globals['DataCache.FOW_ZONES'] = [null,region,cave];
        G.globals['Const.UI'] = {FowBlurSize:2};
        var resource:Dynamic = {entry:{name:'-2_3.png'},texture:{source:'zones'}};
        // MapWindow.refreshTiles reads this exact directory in the game's resources.
        var directories:Map<String, Array<Dynamic>> = [
            'Level/World/W1_Siagarta.dat/minimap/fowZones' => [resource]
        ];
        var fog = new MinimapFog(world,{directories:directories},{MapTileChunksPerSide:4});
        eq(fog.zoneTexture,resource.texture,'Fog loads the native fowZones atlas');
        progress.lockedZone = 'region'; fog.update(hero);
        eq(fog.buffer.values[1],0.,'Locked region darkened by native fog buffer');
        var bitmap:Dynamic = {}; fog.attach(bitmap,2,5);
        eq(bitmap.shader.tileSize,128,'Fog uses native tile cell dimensions');
        eq(bitmap.shader.texOffsetx,320,'Fog X offset follows zone atlas origin');
        eq(bitmap.shader.texOffsety,544,'Fog Y offset follows zone atlas origin');
        eq(bitmap.shader.visibleZones,fog.buffer,'Terrain shader shares visibility buffer');
        var allocated = G.fogAllocations, uploaded = G.fogUploads;
        fog.nextRefresh = 0; fog.update(hero);
        eq(G.fogUploads,uploaded,'Unchanged visibility does not upload');
        progress.lockedZone = null; fog.nextRefresh = 0; fog.update(hero);
        eq(fog.buffer.values[1],1.,'Activation updates fog without reopening minimap');
        eq(G.fogAllocations,allocated,'Activation reuses GPU buffer');
        var buffer = fog.buffer; fog.detach(bitmap); fog.dispose();
        eq(buffer.disposed,true,'Private fog buffer disposed');
        eq(G.field(resource.texture,'disposed'),null,'Shared game texture is not disposed');
        Sys.println('Map refinements: '+checks+' checks passed.');
    }
}
