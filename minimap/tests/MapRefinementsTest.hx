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

        for (unit in ['HildaLambert','NellyXyr'])
            eq(NpcMarkers.kind({props:{npc:{unit:unit}}}), 'pilgrim', 'Faction merchant unit: '+unit);
        eq(NpcMarkers.kind({props:{npc:{unit:'GenericHuman'}}, texts:{name:'Nelly Xyr'}}), 'pilgrim', 'Named merchant with reused model');
        eq(MinimapMarkers.markerRadius('demon'), 9 * 0.8, 'Huntress icon twenty percent smaller');
        eq(MinimapMarkers.markerRadius('soulWell'), 10 * 0.8, 'Soul well icon twenty percent smaller');

        var icons:Map<String,Dynamic> = ['Dungeon'=>{gfx:{tile:{width:128.,height:128.,source:'Dungeon'}}},
            'Dungeon_BonusReward'=>{gfx:{tile:{width:24.,height:24.,source:'Bonus'}}}];
        G.globals['Data.icon'] = {byId:icons};
        G.globals['Data.faction'] = {byId:['Pilgrims'=>{gfx:{tile:{width:200.,height:248.,source:'Pilgrims'}}}]};
        var art = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta');
        art.graphics = {};
        art.drawIcon({kind:'dungeon', x:0, y:0, z:0, bonusDungeon:true});
        eq(G.tileDraws[G.tileDraws.length-2].source, 'Dungeon', 'Dungeon uses native atlas');
        eq(G.tileDraws[G.tileDraws.length-1].source, 'Bonus', 'Heroic bonus uses native green plus');
        eq(icons['Dungeon'].gfx.tile.width,128.,'Resizing does not mutate native tile');
        art.drawIcon({kind:'pilgrim', x:0,y:0,z:0});
        eq(G.tileDraws[G.tileDraws.length-1].source,'Pilgrims','Faction merchant uses native banner');

        G.globals['HElement.obelisks'] = [{mapId:world.level, inf:point.inf, prefab:{_41:50.,_42:60.,_43:0.}}];
        G.globals['HActivity.allActivities'] = new Map<String,Dynamic>();
        G.globals['activities'] = [];
        var window:Dynamic = {hero:hero, selector:true, zoneAt:world.zoneAt, scroll:{x:0.,y:0.},
            scrollContainer:{calculatedWidth:1000.,calculatedHeight:800.}, markers:[], zoom:1., tileScale:1., removed:false};
        window.scrollContainer.dom = {obj:window.scrollContainer};
        window.mapContainer = {interactive:{width:1000.,height:800.}};
        var native = BigMapTest.nativeMarker(window,15,50,60); native.element = point.inf;
        var clicks = 0; native.content.onClick = () -> clicks++;
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
        progress.lockedElement = null;
        window.selector = false; view.update(window,config);
        view.markers.sampledPoints = [{kind:'nextRift',x:100.,y:120.,z:0.}];
        view.markers.revision++; view.rifts.remaining = 125;
        config.clockTimerMode = 'None'; view.updateRiftLabel();
        eq(view.riftLabel.text,'02:05','Map countdown independent of minimap None setting');
        config.clockTimerMode = 'Clock'; view.updateRiftLabel();
        eq(view.riftLabel.text,'02:05','Map countdown independent of minimap Clock setting');
        eq(view.riftLabel.y > 120,true,'Countdown appears below the next rift');
        view.markers.sampledPoints = []; view.markers.revision++; view.updateRiftLabel();
        eq(view.riftLabel.visible,false,'Hidden-region rift has no floating countdown');
        view.dispose();

        G.globals['DataCache.FOW_ZONES'] = [null,region,cave];
        G.globals['Const.UI'] = {FowBlurSize:2};
        var resource:Dynamic = {entry:{name:'-2_3.png'},texture:{source:'zones'}};
        var fog = new MinimapFog(world,{resources:[resource]},{MapTileChunksPerSide:4});
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
