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
    static function main():Void {
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
        var texture = markers.mapIconMarkers[0].icon.tile.texture;
        eq(texture.clearAlpha, 0., 'Texture clear explicitly requests zero opacity');
        eq(texture.bakedBackground, 0, 'Unpainted icon pixels start transparent black, not opaque black');
        eq((cast texture.flags:Array<Dynamic>).join(','), 'Target', 'Cached textures allocate no mipmap chain');
        eq(G.field(texture, 'mipMap'), null, 'No mipmap sampling is enabled on unsupported renderers');
        eq(texture.width, 256, 'Removing mipmaps preserves the high-resolution artwork');
        eq(markers.mapIconMarkers[0].icon.smooth, true, 'Ordinary smooth filtering remains enabled');
        eq(markers.mapIconMarkers[0].icon.tile, markers.mapIconMarkers[9].icon.tile, 'Texture sharing is by appearance');
        var transforms = G.positionWrites;
        markers.draw(points, 1);
        eq(G.positionWrites, transforms, 'Unchanged periodic samples rewrite no marker positions');
        eq(G.bakes, 1, 'Unchanged samples never rebake icons');
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
        cache.dispose();
        for (o in G.created) if (G.field(o, 'nativeType') == 'h3d.mat.Texture')
            eq(o.disposed, true, 'Session teardown releases every cached texture');
        Sys.println('Main map performance: ' + checks + ' checks passed.');
    }
}
