package dpsmeter;

import dpsmeter.GameAccess as G;

private typedef ReadyAudioClip = {
    var pcm:haxe.io.Bytes;
    var rate:Int;
    var channels:Int;
}

/** Game Ogg decoder plus actual Windows output; Heaps' output is a no-op in Farever. */
class ReadyCheckAudio {
    var go:ReadyAudioClip;
    var numbers:Array<ReadyAudioClip>;
    var prepared = false;
    var playing = false;
    var playingVoice = false;
    var gain = 1.0;

    public function new() {}

    public function prepare(voiceover:Bool = true, effects:Bool = true):Void {
        if (!voiceover && !effects) return;
        if (effects && go == null) go = decode("ready-check-go.ogg");
        if (voiceover && numbers == null) {
            var voice = decode("ready-check-countdown.ogg");
            var second = voice.rate * voice.channels * 2;
            if (voice.pcm.length <= second * 4 || voice.pcm.length > second * 5) throw "Unexpected countdown voice duration";
            // The supplied recording has each number in its own one-second
            // interval, with silence at each cut. Use the matching server echo
            // to start each number so network/frame stalls cannot cause drift.
            numbers = [for (i in 0...5) {
                pcm:voice.pcm.sub(i * second, Std.int(Math.min(second, voice.pcm.length - i * second))),
                rate:voice.rate, channels:voice.channels
            }];
        }
        if (!prepared) { DesktopAudio.prepare(); prepared = true; }
    }

    static function decoderBytes(bytes:haxe.io.Bytes):Dynamic {
        #if hl
        // getData() is a BytesDataImpl wrapper on HashLink. Convert before
        // boxing into Dynamic so the game's constructor receives raw bytes.
        var raw:hl.Bytes = hl.Bytes.fromBytes(bytes);
        #else
        var raw = bytes.getData();
        #end
        return G.create("haxe.io.Bytes", [raw, bytes.length]);
    }

    function decode(resource:String):ReadyAudioClip {
        var bytes = haxe.Resource.getBytes("dps-meter/" + resource);
        if (bytes == null) throw "Embedded Ready Check sound is missing: " + resource;
        // Bytes objects belong to their HL module. Only the underlying byte
        // buffer crosses the boundary. The Ogg decoder works even though the
        // compiled Heaps NativeChannel constructor has no output implementation.
        var nativeBytes = decoderBytes(bytes);
        var data = G.create("hxd.snd.OggData", [nativeBytes]);
        var rate = G.integer(G.field(data, "samplingRate"));
        var channels = G.integer(G.field(data, "channels"));
        var samples = G.integer(G.field(data, "samples"));
        if (rate < 8000 || rate > 192000 || channels < 1 || channels > 2 || samples <= 0 || samples > rate * 10
            || Type.enumConstructor(G.field(data, "sampleFormat")) != "I16") throw "Unexpected Ready Check sound format: " + resource;
        var output = haxe.io.Bytes.alloc(samples * channels * 2);
        var nativeOutput = decoderBytes(output);
        G.call("hxd.snd.Data", "decode", data, [nativeOutput, 0, 0, samples]);
        return {pcm:output, rate:rate, channels:channels};
    }

    public function playGo():Void {
        prepare(false, true);
        play(go, false, 0.8);
    }

    public function playCountdown(index:Int):Void {
        if (index < 0 || index >= 5) return;
        prepare(true, false);
        play(numbers[index], true, 1.0);
    }

    function play(clip:ReadyAudioClip, voice:Bool, gain:Float):Void {
        var volume = gameVolume();
        if (volume <= 0) return;
        DesktopAudio.play(clip.pcm, clip.rate, clip.channels, volume * gain);
        this.gain = gain;
        playingVoice = voice;
        playing = true;
    }

    public function update(muteVoice:Bool, muteEffects:Bool):Void {
        if (!playing) return;
        if (playingVoice ? muteVoice : muteEffects) { DesktopAudio.stop(); playing = false; return; }
        playing = DesktopAudio.update(gameVolume() * gain);
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
        playing = false; prepared = false; go = null; numbers = null;
    }
}
