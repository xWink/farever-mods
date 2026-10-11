package dpsmeter;

/** Fail on any unexpected native call, especially chat focus/input operations. */
class GameAccess {
    public static var sent:Array<Dynamic> = [];
    public static var sounds:Array<Dynamic> = [];
    public static var failAudio = false;
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type == "haxe.ds.StringMap" && args.length == 0) return new Map<String, String>();
        throw 'Unexpected native constructor $type';
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type != "client.Audio" || name != "play") throw 'Unexpected native static call $type.$name';
        if (failAudio) throw "Simulated audio failure";
        var params:Map<String, String> = args[2];
        sounds.push({event:args[0], source:args[1], window:params["WindowID"]});
        return null;
    }
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function set(object:Dynamic, name:String, value:Dynamic):Void Reflect.setField(object, name, value);
    public static function text(value:Dynamic, fallback:String = ""):String return value == null ? fallback : Std.string(value);
    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic>
        return value == null ? [] : proxy ? value.array : value;
    public static function enumeration(type:String, name:String):Dynamic {
        if (type == "st.Channel" && name == "Group") return TestChannel.Group;
        throw 'Unexpected enum $type.$name';
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        return switch (type + "." + name) {
            case "haxe.ds.StringMap.set": var map:Map<String, String> = object; map[args[0]] = args[1]; null;
            case "st.Group.get_leader": object.players.array[0];
            case "st.Player.getName": object.name;
            case "st.player.ChatClient.sendMessage": sent.push({client:object, message:args[0]}); null;
            default: throw 'Unexpected native call $type.$name';
        };
    }
}

enum TestChannel {
    Local(position:Dynamic);
    All;
    AllSystem;
    Player(uid:String, name:String);
    Group;
    System(uid:String);
}
