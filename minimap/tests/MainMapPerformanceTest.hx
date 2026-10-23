import minimap.GameAccess as G;
import minimap.MainMapIconCache;
import minimap.MinimapMarkers;
import minimap.MinimapSettings;
import minimap.MapPoint;

@:access(minimap.MinimapMarkers)
class MainMapPerformanceTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected ' + expected + ', got ' + actual;
    }
    static function outlinePixels():Void {
        var root = G.create('h2d.Object', [null]);
        var source:Dynamic = {width:32., height:32.};
        var start = G.created.length;
        minimap.MarkerOutline.compose(root, source, 1., 'AlphaAdd');
        var layers = G.created.slice(start);
        eq(layers.length, 9, 'Outline consists of eight alpha-preserving silhouettes and original art');
        for (i in 0...layers.length) {
            var layer = layers[i];
            eq(layer.nativeType, 'h2d.Bitmap', 'Outline uses source pixels without native filters');
            eq(layer.tile, source, 'Every layer samples the same alpha mask');
            eq(layer.blendMode, 'AlphaAdd', 'Premultiplied source alpha survives composition');
            eq(layer.scale, 1., 'Outline does not enlarge or distort artwork');
            var x = G.number(layer.x), y = G.number(layer.y);
            eq(Math.abs(x*x + y*y - (i == 8 ? 0 : 1)) < 0.000001, true, 'Silhouettes extend only one pixel');
            eq(layer.color.argb, i == 8 ? 0xffffffff : 0xff000000, 'Tint changes RGB while keeping source alpha');
        }
        // Sample the actual configured bitmap transforms over a diamond alpha
        // fixture. Transparent corners and holes must not acquire a background.
        var hole = false;
        function pixel(x:Float, y:Float):Int {
            var result = 0;
            for (layer in layers) {
                var dx = x - G.number(layer.x) - 16, dy = y - G.number(layer.y) - 16;
                if (Math.abs(dx) + Math.abs(dy) <= 5 && (!hole || dx*dx + dy*dy >= 4))
                    result = layer.color.argb == 0xffffffff ? 0xff79ef93 : 0xff000000;
            }
            return result;
        }
        eq(pixel(16,16), 0xff79ef93, 'Original icon color remains intact');
        eq(pixel(21.75,16), 0xff000000, 'A thin black edge appears just beyond the icon');
        eq(pixel(22.01,16), 0, 'Pixels beyond the one-pixel border stay transparent');
        for (x in [0.5,31.5]) for (y in [0.5,31.5]) eq(pixel(x,y), 0, 'Texture corners stay transparent');
        hole = true;
        eq(pixel(16,16), 0, 'Transparent internal space is preserved');
    }
    static function main():Void {
        outlinePixels();
        var cache = new MainMapIconCache([]);
        var markers = new MinimapMarkers({}, {}, {}, 'World/W1_Siagarta', 1.5, {}, cache);
        var hero:Dynamic = {layer:{}, posx:0., posy:0., posz:0.};
        var config:MinimapSettings = cast {markerScale:100.};
        // Supply a cached world sample: panning/zooming must not read native data.
        var points:Array<MapPoint> = [for (i in 0...1000)
            {kind:'ore', x:100. + i * 100., y:100., z:0., name:'Copper'}];
        markers.sampledPoints = points;
        markers.previousConfig = config; markers.lastHero = hero; markers.layer = hero.layer;
        markers.previousRadius = Math.POSITIVE_INFINITY; markers.markerScale = 1.5;
        markers.previousScale = 1; markers.nextRefresh = haxe.Timer.stamp() + 100;
        markers.setViewport(0, 0, 1000, 800);
        var arrays = G.arraysRead;
        markers.update(hero, config, 0, 0, Math.POSITIVE_INFINITY, 1, 0, null);
        eq(markers.points.length, 1000, 'Complete data retained for navigation and native targets');
        eq(markers.hitPoints.length, 10, 'Only viewport markers become hover targets');
        eq(markers.mapIconMarkers.length, 10, 'Only ten of a thousand markers create artwork');
        eq(G.bakes, 1, 'A thousand identical markers share one texture');
        eq(G.reductions, 2, 'Soft edges are averaged once per appearance, never per marker');
        var texture = markers.mapIconMarkers[0].icon.tile.texture;
        eq(texture.clearAlpha, 0., 'Texture clear explicitly requests zero opacity');
        eq(texture.bakedBackground, 0, 'Unpainted icon pixels start transparent black, not opaque black');
        eq((cast texture.flags:Array<Dynamic>).join(','), 'Target', 'Cached textures allocate no mipmap chain');
        eq(G.field(texture, 'mipMap'), null, 'No mipmap sampling is enabled on unsupported renderers');
        eq(texture.width, 64, 'Cached artwork retains two pixels per local pixel after supersampling');
        for (o in G.created) if (G.field(o, 'nativeType') == 'h3d.mat.Texture' && o != texture)
            eq(o.disposed, true, 'Temporary supersampling targets are released after baking');
        eq(markers.mapIconMarkers[0].icon.smooth, true, 'Ordinary smooth filtering remains enabled');
        eq(markers.mapIconMarkers[0].icon.tile, markers.mapIconMarkers[9].icon.tile, 'Texture sharing is by appearance');
        var transforms = G.positionWrites;
        markers.draw(points, 1);
        eq(G.positionWrites, transforms, 'Unchanged periodic samples rewrite no marker positions');
        eq(G.bakes, 1, 'Unchanged samples never rebake icons');
        eq(G.reductions, 2, 'Unchanged samples never repeat smoothing passes');
        eq(markers.mapIconMarkers[0].icon.blendMode, 'AlphaAdd', 'Premultiplied cached edges use the native matching blend mode');
        var firstTile = markers.mapIconMarkers[0].icon.tile;
        markers.setViewport(-50000, 0, 1000, 800);
        markers.update(hero, config, 0, 0, Math.POSITIVE_INFINITY, 1, 0, null);
        eq(markers.hitPoints[0].x, 50000., 'Panning immediately reveals the new viewport before the next world scan');
        eq(markers.mapIconMarkers[0].icon.tile, firstTile, 'Panning reuses cached artwork');
        eq(G.arraysRead, arrays, 'Panning reads no native source arrays');
        eq(markers.revision, 0, 'Panning never forces a world-data refresh');
        markers.setViewport(-100000, 0, 1000, 800);
        markers.update(hero, config, 0, 0, Math.POSITIVE_INFINITY, 2, 0, null);
        eq(markers.mapIconMarkers[0].icon.scale, 0.75, 'Zoom changes transforms without changing icon size on screen');
        eq(G.bakes, 1, 'Zoom does not rebake high-resolution icons');
        eq(G.arraysRead, arrays, 'Zoom reads no native source arrays');
        markers.setViewport(-1000000, 0, 1000, 800);
        markers.update(hero, config, 0, 0, Math.POSITIVE_INFINITY, 2, 0, null);
        eq(markers.mapIconMarkers.length, 0, 'Empty viewport has no marker artwork');
        eq(markers.hoverAt(100, 100, 2, 0, 0, hero), null, 'Offscreen markers cannot intercept hover');
        // Overdraw margin retains partly clipped icons and separate height arrows.
        markers.sampledPoints = [{kind:'npc', x:-15., y:100., z:20., name:'Edge NPC'},
            {kind:'ore', x:-100., y:100., z:0., name:'Hidden ore'}];
        markers.heroHeight = 0;
        markers.setViewport(0, 0, 1000, 800);
        markers.update(hero, config, 0, 0, Math.POSITIVE_INFINITY, 1, 0, null);
        eq(markers.hitPoints.length, 1, 'Partly visible icons survive viewport culling');
        eq(markers.npcElevationMarkers.length, 1, 'Edge markers retain elevation indicators');
        eq(markers.npcElevationMarkers[0].arrow.nativeType, 'h2d.Bitmap', 'Height indicators also share cached artwork');
        markers.setViewport(0, 0, 1000, 800);
        var activityPoints:Array<minimap.MapPoint> = [for (i in 0...6)
            {kind:"activity", activityIcon:["boss", "orbChest", "orbRace", "battle", "ambushChest", "boss"][i],
                x:100.+i*25, y:100., z:0.}];
        var beforeActivities = G.bakes;
        markers.draw(activityPoints, 1);
        eq(G.bakes, beforeActivities + 10, "Each activity appearance is baked and outlined once");
        eq(markers.mapIconMarkers[0].icon.tile, markers.mapIconMarkers[5].icon.tile, "Matching activity types share artwork");
        eq(markers.mapIconMarkers[0].icon.tile == markers.mapIconMarkers[1].icon.tile, false, "Boss and chest artwork cannot collide");
        markers.draw(activityPoints, 1);
        eq(G.bakes, beforeActivities + 10, "Refreshing activities never rebakes unchanged artwork");
        var outlinedKinds = ['activity','quest','dungeon','soulstone','riftPortal','upcomingRift','inactiveRift','nextRift','pilgrim','demon','glory'];
        var firstOutline = G.created.length;
        var outlined:Array<MapPoint> = [for (i in 0...outlinedKinds.length)
            {kind:outlinedKinds[i], x:50.+i*25, y:100., z:0., bonusDungeon:outlinedKinds[i] == 'dungeon'}];
        markers.draw(outlined, 1);
        for (marker in markers.mapIconMarkers.concat(markers.npcIconMarkers)) {
            eq(marker.icon.tile.texture.width, 72, 'Outlined markers retain padding beyond the heroic plus');
            eq(marker.icon.tile.texture.bakedBackground, 0, 'Outlined marker background remains transparent');
            eq(G.field(marker.icon, 'filter'), null, 'Live marker has no per-frame outline filter');
        }
        var outlines = G.created.slice(firstOutline).filter(o -> G.field(o,'nativeType') == 'h2d.filter.Outline');
        eq(outlines.length, 0, 'Offscreen icon baking never uses the rectangular native outline filter');
        var silhouettes = G.created.slice(firstOutline).filter(o -> G.field(o,'nativeType') == 'h2d.Bitmap'
            && G.field(G.field(o,'color'),'argb') == 0xff000000);
        eq(silhouettes.length, outlinedKinds.length * 8, 'Every activity and faction style receives its alpha silhouette');
        for (shadow in silhouettes) {
            var x = G.number(shadow.x), y = G.number(shadow.y);
            eq(Math.abs(x*x + y*y - 64) < 0.000001, true, 'One local pixel becomes eight supersampled pixels');
            eq(shadow.tile.texture.bakedBackground, 0, 'Silhouettes sample a transparent source texture');
        }
        var outlinedBakes = G.bakes, outlinedObjects = G.created.length;
        markers.draw(outlined, 1);
        eq(G.bakes, outlinedBakes, 'Outlined artwork is reused after refresh');
        eq(G.created.length, outlinedObjects, 'No new outline filters are allocated while markers move');
        var firstFailedOutline = G.created.length;
        G.failComposite = true;
        var compositeFailed = false;
        try cache.tile('failed-outline', g -> MinimapMarkers.drawPlayerArrow(g, 10, 0xffffff), 2, true)
            catch (_:Dynamic) compositeFailed = true;
        G.failComposite = false;
        eq(compositeFailed, true, 'Failed outline composition is reported');
        for (o in G.created.slice(firstFailedOutline)) if (G.field(o,'nativeType') == 'h3d.mat.Texture')
            eq(o.disposed, true, 'Failed composition releases both source and target textures');
        cache.tile('failed-outline', g -> MinimapMarkers.drawPlayerArrow(g, 10, 0xffffff), 2, true);
        var beforeFailure = G.bakes;
        G.failBake = true;
        var failed = false;
        try cache.tile('new-style', g -> MinimapMarkers.drawPlayerArrow(g, 10, 0xffffff)) catch (_:Dynamic) failed = true;
        G.failBake = false;
        eq(failed, true, 'Failed bake is reported to the native fallback');
        var textures = [for (o in G.created) if (G.field(o, 'nativeType') == 'h3d.mat.Texture') o];
        eq(textures[textures.length - 1].disposed, true, 'Failed bake releases its render target');
        cache.tile('new-style', g -> MinimapMarkers.drawPlayerArrow(g, 10, 0xffffff));
        eq(G.bakes, beforeFailure + 1, 'Failed appearance is retried instead of caching a blank tile');
        var firstNewObject = G.created.length;
        G.failReduction = true;
        failed = false;
        try cache.tile('failed-smoothing', g -> MinimapMarkers.drawPlayerArrow(g, 10, 0xffffff)) catch (_:Dynamic) failed = true;
        G.failReduction = false;
        eq(failed, true, 'Smoothing failures are reported instead of caching unfinished artwork');
        for (i in firstNewObject...G.created.length) if (G.field(G.created[i], 'nativeType') == 'h3d.mat.Texture')
            eq(G.created[i].disposed, true, 'Failed smoothing releases both source and destination targets');
        cache.tile('failed-smoothing', g -> MinimapMarkers.drawPlayerArrow(g, 10, 0xffffff));
        cache.dispose();
        for (o in G.created) if (G.field(o, 'nativeType') == 'h3d.mat.Texture')
            eq(o.disposed, true, 'Session teardown releases every cached texture');
        Sys.println('Main map performance: ' + checks + ' checks passed.');
    }
}
