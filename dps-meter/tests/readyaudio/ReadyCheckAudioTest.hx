import dpsmeter.ReadyCheckAudio;
import dpsmeter.GameAccess as G;

class ReadyCheckAudioTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected $expected, got $actual';
    }
    static function main():Void {
        var bytes = haxe.Resource.getBytes("dps-meter/ready-check-go.ogg");
        eq(bytes.getString(0, 4), "OggS", "build includes the Ogg asset");
        eq(haxe.crypto.Sha256.make(bytes).toHex(), haxe.crypto.Sha256.make(sys.io.File.getBytes("assets/ready-check-go.ogg")).toHex(), "embedded clip matches the packaged source");
        var audio = new ReadyCheckAudio();
        audio.prepare(); audio.prepare();
        eq(G.sounds.length, 1, "preparation caches one native sound");
        eq(G.channels.length, 0, "preparation stays silent");
        audio.playGo();
        eq(G.channels.length, 1, "GO starts once");
        eq(G.channels[0].volume, 0.2, "master and UI volume both apply");
        G.master = 0; audio.update(false);
        eq(G.channels[0].volume, 0.0, "focus mute silences a playing clip");
        audio.playGo();
        eq(G.channels.length, 1, "already-muted game does not start a clip");
        G.master = 1; G.ui = 0.7; audio.update(false);
        eq(G.channels[0].volume, 0.7, "live game volume change applies");
        audio.update(true);
        eq(G.channels[0].stopped, true, "countdown mute stops an in-flight clip");
        audio.update(false);
        eq(G.channels.length, 1, "unmuting does not restart audio");
        audio.playGo(); audio.playGo();
        eq(G.channels[1].stopped, true, "replacement does not overlap an old clip");
        audio.dispose();
        eq(G.channels[2].stopped, true, "disconnect stops playback");
        eq(G.sounds[0].disposed, true, "disconnect releases the sound");
        audio.prepare();
        eq(G.sounds.length, 2, "new session can prepare again");
        audio.dispose();
        G.manager.driver = null;
        var threw = false;
        try audio.prepare() catch (_:Dynamic) threw = true;
        eq(threw, true, "missing backend reports a recoverable failure");
        Sys.println('Ready Check audio: $checks checks passed.');
    }
}
