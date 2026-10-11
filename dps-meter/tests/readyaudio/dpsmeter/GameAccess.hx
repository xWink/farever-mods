package dpsmeter;

enum TestSampleFormat { I16; }

/** Ogg decoder boundary only. Any call to the inactive Heaps player fails. */
class GameAccess {
    public static var master = 0.5;
    public static var ui = 0.4;
    public static var decodes = 0;
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function number(value:Dynamic, fallback:Float = 0):Float return value == null ? fallback : value;
    public static function integer(value:Dynamic, fallback:Int = 0):Int return value == null ? fallback : value;
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type != "fmod.Api" || name != "getVcaVolume") throw 'Unexpected static call $type.$name';
        return switch (args[0]) {
            case "vca:/MASTER": master;
            case "vca:/UI": ui;
            default: throw "Unexpected volume control";
        };
    }
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        return switch (type) {
            case "haxe.io.Bytes":
                #if hl
                // Enforce the actual game constructor's raw-byte argument type.
                // An interpreter-only test accepts BytesDataImpl here and hides
                // the cast failure that prevents the GO clip from decoding.
                var buffer:hl.Bytes = args[0];
                #else
                var buffer = args[0];
                #end
                {buffer:buffer, length:args[1], nativeBytes:true};
            case "hxd.snd.OggData":
                if (args[0].nativeBytes != true || args[0].length <= 0) throw "Invalid native bytes";
                {samples:960, channels:2, samplingRate:48000, sampleFormat:I16};
            default: throw 'Unexpected construction $type';
        };
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type != "hxd.snd.Data" || name != "decode") throw 'Unexpected call $type.$name';
        var out = args[0];
        if (out.nativeBytes != true || out.length != object.samples * 4 || args[1] != 0 || args[2] != 0 || args[3] != object.samples)
            throw "Invalid PCM decode buffer";
        #if hl
        var buffer:hl.Bytes = out.buffer;
        var length = Std.int(out.length);
        buffer.toBytes(length).setUInt16(0, 1234);
        #else
        haxe.io.Bytes.ofData(out.buffer).setUInt16(0, 1234);
        #end
        decodes++;
        return null;
    }
}
