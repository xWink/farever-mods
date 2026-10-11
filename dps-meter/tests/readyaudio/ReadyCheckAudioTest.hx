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
        audio.playCountdown(0);
        decoded = D.channels[0].pcm;
        eq(decoded.length, 232448 * 4, "voice submits the complete uncut recording");
        for (i in 0...5) {
            eq(decoded.getUInt16(i * 48000 * 4), 1234 + i, "all words remain in their original positions");
            if (i > 0) audio.playCountdown(i);
        }
        eq(D.channels.length, 1, "later chat numbers never restart or interrupt the voice");
        eq(D.channels[0].stopped, false, "two plays inside the uninterrupted original recording");
        near(D.channels[0].volume, 0.2, "voice retains full master/UI volume");
        eq(G.decodes, before + 1, "voice recording decodes only once");
        audio.playCountdown(-1); audio.playCountdown(5);
        eq(D.channels.length, 1, "invalid indices do not play");
        audio.update(false, true);
        eq(D.channels[0].stopped, false, "effects mute leaves voice playing");
        audio.update(true, false);
        eq(D.channels[0].stopped, true, "voice mute stops active voice");
        audio.update(false, false);
        eq(D.channels.length, 1, "unmuting alone does not replay stale numbers");
        audio.playCountdown(3);
        decoded = D.channels[1].pcm;
        eq(decoded.getUInt16(0), 1237, "joining mid-countdown starts at the matching word");
        eq(decoded.length, (232448 - 144000) * 4, "joining retains the entire remaining recording");
        audio.playCountdown(4);
        eq(D.channels.length, 2, "joined recording continues without a per-word restart");
        audio.playCountdown(0);
        eq(D.channels[1].stopped, true, "a new countdown replaces the previous recording");
        audio.playGo(); audio.update(true, false);
        eq(D.channels[2].stopped, true, "GO stops any remaining countdown voice");
        eq(D.channels[3].stopped, false, "voice mute leaves boom playing");
        near(D.channels[3].volume, 0.16, "switching from voice to GO restores the quieter gain");
        audio.update(false, true);
        eq(D.channels[3].stopped, true, "effects mute stops active boom");
        audio.dispose();
        audio.playCountdown(0);
        var played = D.channels.length;
        D.stop(); audio.update(false, false); // Backend reports the buffer finished.
        audio.playCountdown(4);
        eq(D.channels.length, played, "late chat does not repeat a word after the complete recording finished");
        audio.prepareCheck(true, false); audio.playCountdown(2);
        eq(D.channels.length, played + 1, "new ready check resets voice playback even when first delivery is batched");
        audio.prepareCheck(true, false);
        eq(D.channels[played].stopped, true, "new ready cue stops voice left over from a replaced check");
        audio.dispose();
        Sys.println('Ready Check audio: $checks checks passed.');
    }
}
