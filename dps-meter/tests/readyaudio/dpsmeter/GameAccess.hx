package dpsmeter;

/** Native boundary model: catches unexpected calls or foreign resource objects. */
class GameAccess {
    public static var master = 0.5;
    public static var ui = 0.4;
    public static var manager:Dynamic = {driver:{}};
    public static var sounds:Array<Dynamic> = [];
    public static var channels:Array<Dynamic> = [];
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function number(value:Dynamic, fallback:Float = 0):Float return value == null ? fallback : value;
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        return switch (type + "." + name) {
            case "hxd.snd.Manager.get": manager;
            case "fmod.Api.getVcaVolume":
                switch (args[0]) {
                    case "vca:/MASTER": master;
                    case "vca:/UI": ui;
                    default: throw "Unexpected volume control";
                };
            default: throw 'Unexpected static call $type.$name';
        };
    }
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        return switch (type) {
            case "haxe.io.Bytes": {buffer:args[0], length:args[1], nativeBytes:true};
            case "hxd.fs.BytesFileEntry":
                if (args[1].nativeBytes != true || args[1].length <= 0) throw "Invalid native bytes";
                {path:args[0], bytes:args[1]};
            case "hxd.res.Sound":
                var sound:Dynamic = {entry:args[0], decoded:false, channel:null, disposed:false};
                sounds.push(sound); sound;
            default: throw 'Unexpected construction $type';
        };
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        return switch (type + "." + name) {
            case "hxd.res.Sound.getData": object.decoded = true; {};
            case "hxd.res.Sound.play":
                if (!object.decoded || object.disposed) throw "Sound unavailable";
                if (args[0] != false || args[2] != null || args[3] != null) throw "GO must be a local one-shot";
                var channel:Dynamic = {volume:args[1], stopped:false};
                object.channel = channel; channels.push(channel); channel;
            case "hxd.snd.Channel.isReleased": object.stopped;
            case "hxd.snd.Channel.stop": object.stopped = true; null;
            case "hxd.snd.ChannelBase.set_volume": object.volume = args[0]; null;
            case "hxd.res.Sound.dispose":
                object.disposed = true;
                if (object.channel != null) object.channel.stopped = true;
                null;
            default: throw 'Unexpected call $type.$name';
        };
    }
}
