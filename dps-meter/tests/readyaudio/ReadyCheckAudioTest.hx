import dpsmeter.ReadyCheckAudio;
import dpsmeter.GameAccess as G;
import dpsmeter.DesktopAudio as D;

class ReadyCheckAudioTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw why + ': expected $expected, got $actual';
    }
    static function near(actual:Float, expected:Float, why:String):Void {
        checks++;
        if (Math.abs(actual - expected) > 0.000001) throw why + ': expected $expected, got $actual';
    }
    static function main():Void {
        var bytes = haxe.Resource.getBytes("dps-meter/ready-check-go.ogg");
        eq(bytes.getString(0, 4), "OggS", "build includes the Ogg asset");
        eq(haxe.crypto.Sha256.make(bytes).toHex(), haxe.crypto.Sha256.make(sys.io.File.getBytes("assets/ready-check-go.ogg")).toHex(), "embedded clip matches the packaged source");
        bytes = haxe.Resource.getBytes("dps-meter/ready-check-countdown.ogg");
        eq(bytes.getString(0, 4), "OggS", "build includes countdown voiceover");
        eq(haxe.crypto.Sha256.make(bytes).toHex(), haxe.crypto.Sha256.make(sys.io.File.getBytes("assets/ready-check-countdown.ogg")).toHex(), "embedded voice matches source");
        var audio = new ReadyCheckAudio();
        audio.prepare(); audio.prepare();
        eq(G.decodes, 2, "preparation decodes each clip once");
        eq(D.prepares, 1, "preparation opens output once");
        eq(D.channels.length, 0, "preparation stays silent");
        audio.playGo();
        eq(D.channels.length, 1, "GO starts once");
        var decoded:haxe.io.Bytes = D.channels[0].pcm;
        eq(decoded.getUInt16(0), 1234, "actual decoded samples reach the output plugin");
        eq(D.channels[0].rate, 48000, "sample rate preserved");
        eq(D.channels[0].channels, 2, "stereo preserved");
        near(D.channels[0].volume, 0.16, "boom is 20 percent quieter after master and UI volume");
        G.master = 0; audio.update(false, false);
        eq(D.channels[0].volume, 0.0, "focus mute silences a playing clip");
        audio.playGo();
        eq(D.channels.length, 1, "already-muted game does not start a clip");
        G.master = 1; G.ui = 0.7; audio.update(false, false);
        near(D.channels[0].volume, 0.56, "live volume changes preserve the boom reduction");
        audio.update(false, true);
        eq(D.channels[0].stopped, true, "countdown mute stops an in-flight clip");
        audio.update(false, false);
        eq(D.channels.length, 1, "unmuting does not restart audio");
        audio.playGo(); audio.playGo();
        eq(D.channels[1].stopped, true, "replacement does not overlap an old clip");
        audio.dispose();
        eq(D.channels[2].stopped, true, "disconnect stops playback");
        eq(D.disposed, 1, "disconnect releases the output engine");
        audio.prepare();
        eq(G.decodes, 4, "new session can prepare again");
        audio.dispose();
        D.failPrepare = true;
        var threw = false;
        try audio.prepare() catch (_:Dynamic) threw = true;
        eq(threw, true, "missing backend reports a recoverable failure");
        D.failPrepare = false; audio.prepare();
        eq(D.prepares, 3, "preparation can recover after the backend becomes available");
        audio.dispose();
        D.channels = []; G.master = 0.5; G.ui = 0.4;
        var before = G.decodes;
        audio.prepare(false, false);
        eq(G.decodes, before, "muting both categories skips preparation");
        for (i in 0...5) {
            audio.playCountdown(i);
            decoded = D.channels[i].pcm;
            eq(decoded.getUInt16(0), 1234 + i, "matching one-second segment reaches playback");
            eq(decoded.length, i < 4 ? 192000 : (232448 - 192000) * 4, "voice slice preserves final number tail");
            near(D.channels[i].volume, 0.2, "voice retains full master/UI volume");
            if (i > 0) eq(D.channels[i - 1].stopped, true, "next number replaces previous voice without overlap");
        }
        eq(G.decodes, before + 1, "all five numbers share one decoded recording");
        audio.playCountdown(-1); audio.playCountdown(5);
        eq(D.channels.length, 5, "invalid indices do not play");
        audio.update(false, true);
        eq(D.channels[4].stopped, false, "effects mute leaves voice playing");
        audio.update(true, false);
        eq(D.channels[4].stopped, true, "voice mute stops active voice");
        audio.update(false, false);
        eq(D.channels.length, 5, "unmuting voice does not replay stale numbers");
        audio.playGo(); audio.update(true, false);
        eq(D.channels[5].stopped, false, "voice mute leaves boom playing");
        near(D.channels[5].volume, 0.16, "switching from voice to GO restores the quieter gain");
        audio.update(false, true);
        eq(D.channels[5].stopped, true, "effects mute stops active boom");
        audio.dispose();
        Sys.println('Ready Check audio: $checks checks passed.');
    }
}
