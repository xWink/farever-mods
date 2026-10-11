package dpsmeter;

class DesktopAudio {
    public static var prepares = 0;
    public static var disposed = 0;
    public static var failPrepare = false;
    public static var channels:Array<Dynamic> = [];
    static var current:Dynamic;
    public static function prepare():Void {
        if (failPrepare) throw "Missing audio backend";
        prepares++;
    }
    public static function play(pcm:haxe.io.Bytes, rate:Int, channels:Int, volume:Float):Void {
        stop();
        current = {pcm:pcm, rate:rate, channels:channels, volume:volume, stopped:false};
        DesktopAudio.channels.push(current);
    }
    public static function update(volume:Float):Bool {
        if (current == null || current.stopped) return false;
        current.volume = volume;
        return true;
    }
    public static function stop():Void { if (current != null) current.stopped = true; }
    public static function dispose():Void { stop(); disposed++; }
}
