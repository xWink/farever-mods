package dpsmeter;

import dpsmeter.GameAccess as G;

/** Embedded GO clip played by the game's existing sound backend. */
class ReadyCheckAudio {
    var sound:Dynamic;
    var channel:Dynamic;

    public function new() {}

    public function prepare():Void {
        if (sound != null) return;
        var bytes = haxe.Resource.getBytes("dps-meter/ready-check-go.ogg");
        if (bytes == null) throw "Embedded Ready Check GO sound is missing";
        // Bytes objects belong to their HL module. Only the underlying byte
        // buffer crosses the boundary; all audio objects use native game types.
        var nativeBytes = G.create("haxe.io.Bytes", [bytes.getData(), bytes.length]);
        var entry = G.create("hxd.fs.BytesFileEntry", ["dps-meter/ready-check-go.ogg", nativeBytes]);
        var loaded = G.create("hxd.res.Sound", [entry]);
        G.call("hxd.res.Sound", "getData", loaded);
        var manager = G.staticCall("hxd.snd.Manager", "get", []);
        if (G.field(manager, "driver") == null) throw "Ready Check sound backend is unavailable";
        sound = loaded;
    }

    public function playGo():Void {
        var volume = gameVolume();
        if (volume <= 0) return;
        prepare();
        if (channel != null) G.call("hxd.snd.Channel", "stop", channel);
        channel = G.call("hxd.res.Sound", "play", sound, [false, volume, null, null]);
    }

    public function update(muted:Bool):Void {
        if (channel == null) return;
        if (G.call("hxd.snd.Channel", "isReleased", channel) == true) { channel = null; return; }
        if (muted) { G.call("hxd.snd.Channel", "stop", channel); channel = null; return; }
        G.call("hxd.snd.ChannelBase", "set_volume", channel, [gameVolume()]);
    }

    function gameVolume():Float {
        // Options.applyAudio applies focus muting to MASTER. Read the applied
        // values so this custom clip follows the same master/UI preferences.
        var master = G.number(G.staticCall("fmod.Api", "getVcaVolume", ["vca:/MASTER"]));
        var ui = G.number(G.staticCall("fmod.Api", "getVcaVolume", ["vca:/UI"]));
        return Math.max(0, Math.min(1, master)) * Math.max(0, Math.min(1, ui));
    }

    public function dispose():Void {
        if (sound != null) G.call("hxd.res.Sound", "dispose", sound);
        channel = null; sound = null;
    }
}
