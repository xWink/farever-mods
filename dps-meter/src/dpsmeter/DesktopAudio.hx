package dpsmeter;

/** Real Windows output, independent of Farever's inactive Heaps audio driver. */
class DesktopAudio {
    public static function prepare():Void {
        #if hl
        check(prepareNative());
        #else
        throw "GO audio requires the Windows desktop plugin";
        #end
    }
    public static function play(pcm:haxe.io.Bytes, rate:Int, channels:Int, volume:Float):Void {
        #if hl
        check(playNative(pcm, pcm.length, rate, channels, volume));
        #else
        throw "GO audio requires the Windows desktop plugin";
        #end
    }
    public static function update(volume:Float):Bool {
        #if hl
        var result = updateNative(volume);
        if (result < 0) check(result);
        return result == 1;
        #else
        return false;
        #end
    }
    public static function stop():Void {
        #if hl
        check(stopNative());
        #end
    }
    public static function dispose():Void {
        #if hl
        check(disposeNative());
        #end
    }
    #if hl
    static function check(code:Int):Void {
        if (code == -1) throw "Update the complete DPS Meter download, including hlx/plugins/dps-meter/dps_meter_desktop.hdll, and restart Farever for GO audio";
        if (code != 0) throw "Ready Check audio failed (Windows error " + code + ")";
    }
    @:hlNative("?dps_meter_desktop", "prepare_audio") static function prepareNative():Int return -1;
    @:hlNative("?dps_meter_desktop", "play_audio") static function playNative(pcm:hl.Bytes, length:Int, rate:Int, channels:Int, volume:Float):Int return -1;
    @:hlNative("?dps_meter_desktop", "update_audio") static function updateNative(volume:Float):Int return -1;
    @:hlNative("?dps_meter_desktop", "stop_audio") static function stopNative():Int return -1;
    @:hlNative("?dps_meter_desktop", "dispose_audio") static function disposeNative():Int return -1;
    #end
}
