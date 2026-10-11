package dpsmeter;

import dpsmeter.GameAccess as G;

/** Game Ogg decoder plus actual Windows output; Heaps' output is a no-op in Farever. */
class ReadyCheckAudio {
    var pcm:haxe.io.Bytes;
    var rate = 0;
    var channels = 0;
    var prepared = false;
    var playing = false;

    public function new() {}

    public function prepare():Void {
        if (prepared) return;
        if (pcm == null) decode();
        DesktopAudio.prepare();
        prepared = true;
    }

    function decode():Void {
        var bytes = haxe.Resource.getBytes("dps-meter/ready-check-go.ogg");
        if (bytes == null) throw "Embedded Ready Check GO sound is missing";
        // Bytes objects belong to their HL module. Only the underlying byte
        // buffer crosses the boundary. The Ogg decoder works even though the
        // compiled Heaps NativeChannel constructor has no output implementation.
        var nativeBytes = G.create("haxe.io.Bytes", [bytes.getData(), bytes.length]);
        var data = G.create("hxd.snd.OggData", [nativeBytes]);
        rate = G.integer(G.field(data, "samplingRate"));
        channels = G.integer(G.field(data, "channels"));
        var samples = G.integer(G.field(data, "samples"));
        if (rate < 8000 || rate > 192000 || channels < 1 || channels > 2 || samples <= 0 || samples > rate * 10
            || Type.enumConstructor(G.field(data, "sampleFormat")) != "I16") throw "Unexpected GO sound format";
        var output = haxe.io.Bytes.alloc(samples * channels * 2);
        var nativeOutput = G.create("haxe.io.Bytes", [output.getData(), output.length]);
        G.call("hxd.snd.Data", "decode", data, [nativeOutput, 0, 0, samples]);
        pcm = output;
    }

    public function playGo():Void {
        var volume = gameVolume();
        if (volume <= 0) return;
        prepare();
        DesktopAudio.play(pcm, rate, channels, volume);
        playing = true;
    }

    public function update(muted:Bool):Void {
        if (!playing) return;
        if (muted) { DesktopAudio.stop(); playing = false; return; }
        playing = DesktopAudio.update(gameVolume());
    }

    function gameVolume():Float {
        // Options.applyAudio applies focus muting to MASTER. Read the applied
        // values so this custom clip follows the same master/UI preferences.
        var master = G.number(G.staticCall("fmod.Api", "getVcaVolume", ["vca:/MASTER"]));
        var ui = G.number(G.staticCall("fmod.Api", "getVcaVolume", ["vca:/UI"]));
        return Math.max(0, Math.min(1, master)) * Math.max(0, Math.min(1, ui));
    }

    public function dispose():Void {
        if (prepared) DesktopAudio.dispose();
        playing = false; prepared = false; pcm = null;
    }
}
