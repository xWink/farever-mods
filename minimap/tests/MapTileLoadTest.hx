import minimap.MapTileLoad;
import minimap.GameAccess as G;

class MapTileLoadTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected ' + expected + ', got ' + actual;
    }
    static function main():Void {
        var resource:Dynamic = {enableAsyncLoading: false, tex: {flags: 512, width: 1},
            tile: {dx: -256.0, dy: -256.0, width: 512}, fail: false};
        var tiles = 0;
        G.nativeCall = function(type:String, name:String, obj:Dynamic, args:Array<Dynamic>):Dynamic {
            switch name {
                case 'toImage': return obj;
                case 'toTexture':
                    eq(obj.enableAsyncLoading, true, 'native loader asked to use supported async path');
                    if (obj.fail) throw 'load failed';
                    return obj.tex;
                case 'toTile': tiles++; return obj.tile;
                case 'clone': return Reflect.copy(obj);
                default: throw 'Unexpected native call ' + type + '.' + name;
            }
        };
        var load = new MapTileLoad(resource);
        eq(resource.enableAsyncLoading, false, 'shared resource preference restored');
        eq(load.take(), null, 'placeholder is never displayed');
        eq(tiles, 0, 'no tile allocation while loading');
        resource.tex.flags = 0; resource.tex.width = 512;
        var tile = load.take();
        eq(tile.width, 512, 'completed image uses full dimensions');
        eq(tile.dx, 0.0, 'map tile has independent horizontal origin');
        eq(tile.dy, 0.0, 'map tile has independent vertical origin');
        eq(resource.tile.dx, -256.0, 'native map tile stays centered');
        eq(load.take(), null, 'completion consumed once');
        resource.enableAsyncLoading = true;
        load = new MapTileLoad(resource);
        eq(resource.enableAsyncLoading, true, 'preexisting native preference retained');
        eq(load.take() != null, true, 'cached or synchronous native fallback available immediately');
        resource.enableAsyncLoading = false; resource.fail = true;
        var failed = false;
        try new MapTileLoad(resource) catch (_:Dynamic) failed = true;
        eq(failed, true, 'load failure reaches existing mod error handler');
        eq(resource.enableAsyncLoading, false, 'resource preference restored after failure');
        resource.fail = false; resource.tex = null;
        load = new MapTileLoad(resource);
        eq(load.take(), null, 'absent native texture waits safely');
        G.nativeCall = null;
        Sys.println('Minimap tile loading: $checks checks passed.');
    }
}
