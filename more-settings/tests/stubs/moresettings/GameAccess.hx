package moresettings;

/** Test adapter: plain objects stand in for native HL objects and arrays. */
class GameAccess {
    public static var master:Float = 1;
    public static var focused:Bool = true;
    public static var writes:Int = 0;
    public static var audioReady:Bool = true;
    public static var reads:Int = 0;
    public static var data:Dynamic;
    public static var inputArrayCalls:Int = 0;
    public static var blitCalls:Int = 0;
    public static var blitElements:Int = 0;
    public static var removedElements:Int = 0;
    public static function field(o:Dynamic, name:String):Dynamic return o == null ? null : Reflect.field(o, name);
    public static function set(o:Dynamic, name:String, value:Dynamic):Void if (o != null) Reflect.setField(o, name, value);
    public static function text(v:Dynamic, fallback:String = ""):String return v == null ? fallback : Std.string(v);
    public static function number(v:Dynamic, fallback:Float = 0):Float {
        var n = Std.parseFloat(text(v)); return Math.isFinite(n) ? n : fallback;
    }
    public static function integer(v:Dynamic, fallback:Int = 0):Int return Std.int(number(v, fallback));
    public static function array(v:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) v = field(v, "array");
        if (field(v, "items") != null) return (cast v.items:Array<Dynamic>).copy();
        return v == null ? [] : cast v;
    }
    public static function isA(o:Dynamic, name:String):Bool {
        if (o == null) return false;
        var types:Array<String> = field(o, "types"); return types != null && types.indexOf(name) >= 0;
    }
    public static function callInstance(o:Dynamic, name:String):Dynamic return call("", name, o);
    public static function current(type:String, name:String):Dynamic
        return type == "fmod.Api" && name == "initialized" ? audioReady : field(data, name);
    public static function call(type:String, name:String, o:Dynamic, ?args:Array<Dynamic>):Dynamic return switch name {
        case "bindUpdate":
            var callbacks:Array<Float->Void> = field(o, "callbacks");
            var callback:Float->Void = args[0];
            callbacks.push(callback); callback(0); null;
        case "set_text": set(o, "text", args[0]); args[0];
        case "getDyn": inputArrayCalls++; o.items[args[0]];
        case "setDyn": inputArrayCalls++; o.items[args[0]] = args[1]; null;
        case "blit":
            var count:Int = args[3];
            var source:Array<Dynamic> = args[1].items;
            var copy = source.slice(args[2], args[2] + count);
            for (i in 0...count) o.items[args[0] + i] = copy[i];
            blitCalls++; blitElements += count; null;
        case "resize":
            var items:Array<Dynamic> = o.items;
            items.resize(args[0]); o.length = items.length; null;
        case "remove":
            if (type == "h2d.Object") { o.parent = null; removedElements++; null; }
            else {
                var items:Array<Dynamic> = o.items;
                var removed = items.remove(args[0]); o.length = items.length; removed;
            }
        case "hasClass": (cast o.classes:Array<String>).indexOf(args[0]) >= 0;
        case "getFocusedTextInput": field(o, "textInput");
        case "get": field(o, args[0]);
        case "getSourceSkill": field(o, "sourceSkill") == null ? o : field(o, "sourceSkill");
        case "getSourceObject": field(o, "instigator") != null ? field(o, "instigator") : field(o, "owner");
        case "resolveProxy": field(o, "proxy") == null ? o : field(o, "proxy");
        case "isEnemy": field(args[0], "enemy") == true;
        case "get_isFocused": focused;
        case "isFlyingToObelisk": field(o, "flying") == true;
        case "isActive": field(o, "playing") == true;
        case "stop": set(o, "playing", false); set(o, "stops", integer(field(o, "stops")) + 1); null;
        default: throw "Unexpected native call: " + type + "." + name;
    };
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic return switch name {
        case "getInstance": {};
        case "getVcaVolume":
            if (!audioReady) throw "Access violation: FMOD has not initialized";
            reads++;
            if (args[0] != "vca:/MASTER") throw "Unexpected VCA read: " + args[0];
            master;
        case "setVcaVolume":
            if (args[0] != "vca:/MASTER") throw "Unexpected VCA write: " + args[0];
            master = args[1]; writes++; null;
        default: throw "Unexpected native static call: " + type + "." + name;
    };
}
