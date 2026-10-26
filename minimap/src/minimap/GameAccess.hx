package minimap;

import hlx.runtime.ResolvedMember;

/** All game objects stay in their original HL module; never cast game arrays to Array<Dynamic>. */
class GameAccess {
    static var classes:Map<String, String> = [];
    static var members:Map<String, ResolvedMember> = [];
    public static function family(object:Dynamic):String {
        var type = hl.Type.getDynamic(object);
        var name = type.getTypeName();
        if (classes.exists(name)) return classes[name];
        var kind = "";
        // HashLink returns HVoid (not null) after the root class. Only walk
        // object types, or unrelated entities loop forever on the void sentinel.
        while (type != null && type.kind == HObj) {
            kind = switch type.getTypeName() {
                case "ent.Hero": "player";
                case "ent.Foe": "enemy";
                case "ent.interactible.Gatherable": "gatherable";
                case "ent.interactible.Chest": "chest";
                case "ent.interactible.Npc", "ent.interactible.CraftStation",
                    "ent.interactible.GearUpgradeStation", "ent.interactible.ScrapStation",
                    "ent.interactible.InfusionStation", "ent.interactible.SoulwellStation": "npc";
                default: "";
            };
            if (kind != "") break;
            type = type.getSuper();
        }
        classes[name] = kind;
        return kind;
    }

    public static function field(object:Dynamic, name:String):Dynamic {
        if (object == null) return null;
        try return HlxRuntime.resolveField(object, name) catch (_:Dynamic) return null;
    }
    public static function text(value:Dynamic, fallback:String = ""):String {
        return value == null ? fallback : Std.string(value);
    }
    public static function number(value:Dynamic, fallback:Float = 0):Float {
        if (value == null) return fallback;
        // Native numeric values need no string formatting, allocation or parsing.
        // Preserve support for strings from either HashLink module as a fallback.
        var n:Float = Std.isOfType(value, Float) ? cast value : Std.parseFloat(Std.string(value));
        return Math.isFinite(n) ? n : fallback;
    }
    public static function integer(value:Dynamic, fallback:Int = 0):Int {
        return Std.int(number(value, fallback));
    }
    public static function member(type:String, name:String, isStatic:Bool = false):ResolvedMember {
        var key = type + (isStatic ? "::" : ".") + name;
        if (members.exists(key)) return members[key];
        var t = HlxRuntime.resolveType(type);
        if (t == null) throw "Game type unavailable: " + type;
        var m = isStatic ? HlxRuntime.resolveStaticMember(t, name) : HlxRuntime.resolveMember(t, name);
        if (m == null) throw "Game member unavailable: " + key;
        members[key] = m;
        return m;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        var all:Array<Dynamic> = [object];
        if (args != null) for (a in args) all.push(a);
        return HlxRuntime.callResolved(member(type, name), all);
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        return HlxRuntime.callResolved(member(type, name, true), args);
    }
    public static function current(type:String, name:String):Dynamic {
        var t = HlxRuntime.resolveType(type);
        return t == null ? null : HlxRuntime.resolveStaticField(t, name);
    }
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        var t = HlxRuntime.resolveType(type);
        if (t == null) throw "Game type unavailable: " + type;
        return HlxRuntime.constructInstanceByName(t, args.length, args);
    }
    public static function enumBit(type:String, name:String):Int {
        var value = current(type, name);
        if (value == null) throw "Game flag unavailable: " + type + "." + name;
        return 1 << Type.enumIndex(value);
    }
    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) value = field(value, "array");
        var out:Array<Dynamic> = [];
        var count = integer(field(value, "length"));
        if (count <= 0) return out;
        // Replicated ArrayProxyData lists use ArrayDyn, while hero skill lists
        // use ArrayObj. Invoke the real array's reader without reinterpreting it.
        var type = hl.Type.getDynamic(value).getTypeName();
        for (i in 0...count) out.push(call(type, "getDyn", value, [i]));
        return out;
    }
    public static function set(object:Dynamic, name:String, value:Dynamic):Void {
        if (object != null) HlxRuntime.setField(object, name, value);
    }
}
