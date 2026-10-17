package trade;

import hlx.runtime.ResolvedMember;

/** All game objects stay in their original HL module; never cast game arrays to Array<Dynamic>. */
class GameAccess {
    static var members:Map<String, ResolvedMember> = [];
    public static function typeName(object:Dynamic):String return hl.Type.getDynamic(object).getTypeName();
    public static function isA(object:Dynamic, name:String):Bool {
        if (object == null) return false;
        var type = hl.Type.getDynamic(object);
        while (type != null && type.kind == HObj) {
            if (type.getTypeName() == name) return true;
            type = type.getSuper();
        }
        return false;
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
        var n = Std.parseFloat(Std.string(value));
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
    public static function enumeration(type:String, name:String):Dynamic {
        // Native code compares no-argument enum values by identity. A newly
        // allocated Scroll never matches the game's shared Scroll value.
        return current(type, name);
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
    public static function uid(value:Dynamic):String {
        // Reflecting hl.I64 and formatting it preserves all 64 bits.
        return text(field(value, "__uid"));
    }
    public static function set(object:Dynamic, name:String, value:Dynamic):Void {
        if (object != null) HlxRuntime.setField(object, name, value);
    }
    public static function vector(x:Float,y:Float,z:Float):Dynamic {
        var rx:hl.Ref<Float> = x, ry:hl.Ref<Float> = y, rz:hl.Ref<Float> = z;
        return create("h3d.VectorImpl",[rx,ry,rz]);
    }
    public static function enumValue(type:String,name:String,args:Array<Dynamic>):Dynamic {
        var t = HlxRuntime.resolveType(type);
        if (t == null) throw "Game enum unavailable: "+type;
        return HlxRuntime.constructEnum(t,name,args);
    }
    public static function enumName(value:Dynamic):String {
        if (value == null || hl.Type.getDynamic(value).kind != HEnum) return "";
        return Type.enumConstructor(value);
    }
    public static function enumArgument(value:Dynamic,index:Int):Dynamic return array(staticCall("Type","enumParameters",[value]))[index];
}
