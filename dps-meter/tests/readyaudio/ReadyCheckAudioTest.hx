import dpsmeter.ReadyCheckAudio;
import dpsmeter.GameAccess as G;
import dpsmeter.DesktopAudio as D;

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
        eq(G.decodes, 1, "preparation decodes once");
        eq(D.prepares, 1, "preparation opens output once");
        eq(D.channels.length, 0, "preparation stays silent");
        audio.playGo();
        eq(D.channels.length, 1, "GO starts once");
        var decoded:haxe.io.Bytes = D.channels[0].pcm;
        eq(decoded.getUInt16(0), 1234, "actual decoded samples reach the output plugin");
        eq(D.channels[0].rate, 48000, "sample rate preserved");
        eq(D.channels[0].channels, 2, "stereo preserved");
        eq(D.channels[0].volume, 0.2, "master and UI volume both apply");
        G.master = 0; audio.update(false);
        eq(D.channels[0].volume, 0.0, "focus mute silences a playing clip");
        audio.playGo();
        eq(D.channels.length, 1, "already-muted game does not start a clip");
        G.master = 1; G.ui = 0.7; audio.update(false);
        eq(D.channels[0].volume, 0.7, "live game volume change applies");
        audio.update(true);
        eq(D.channels[0].stopped, true, "countdown mute stops an in-flight clip");
        audio.update(false);
        eq(D.channels.length, 1, "unmuting does not restart audio");
        audio.playGo(); audio.playGo();
        eq(D.channels[1].stopped, true, "replacement does not overlap an old clip");
        audio.dispose();
        eq(D.channels[2].stopped, true, "disconnect stops playback");
        eq(D.disposed, 1, "disconnect releases the output engine");
        audio.prepare();
        eq(G.decodes, 2, "new session can prepare again");
        audio.dispose();
        D.failPrepare = true;
        var threw = false;
        try audio.prepare() catch (_:Dynamic) threw = true;
        eq(threw, true, "missing backend reports a recoverable failure");
        D.failPrepare = false; audio.prepare();
        eq(D.prepares, 3, "preparation can recover after the backend becomes available");
        audio.dispose();
        Sys.println('Ready Check audio: $checks checks passed.');
    }
}
