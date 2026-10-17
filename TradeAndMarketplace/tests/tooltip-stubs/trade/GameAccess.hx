package trade;

/** Model the native dynamic-array boundary and identity-sensitive affix lookup. */
class GameAccess {
    public static var definitions:Map<String,Dynamic> = [];
    public static var creations = 0;
    public static var networked = false;
    public static function field(o:Dynamic,k:String):Dynamic return o == null ? null : Reflect.field(o,k);
    public static function set(o:Dynamic,k:String,v:Dynamic):Void Reflect.setField(o,k,v);
    public static function isA(o:Dynamic,t:String):Bool return o != null && (t == "st.item.Gear" || t == "st.item.Weapon");
    public static function current(t:String,n:String):Dynamic return t == "Data" ? {byId:{get:(key:String)->definitions.get(n+":"+key)}} : null;
    public static function enumeration(t:String,n:String):Dynamic return n;
    public static function call(t:String,m:String,o:Dynamic,?args:Array<Dynamic>):Dynamic {
        if (t == "haxe.ds.StringMap" && m == "get") return o.get(args[0]);
        if (t == "hl.types.ArrayDyn" && m == "push") { o.values.push(args[0]); return null; }
        if (t == "st.Item" && m == "makeInf") { o.inf = {id:o.kind}; return null; }
        throw "Unexpected native call "+t+"."+m;
    }
    public static function create(t:String,args:Array<Dynamic>):Dynamic return switch(t) {
        case "hxbit.EnumFlagsData": {value:0};
        case "hl.types.ArrayDyn": {values:new Array<Dynamic>()};
        case "hxbit.ArrayProxyData": {array:args[0]};
        default: throw "Unexpected native allocation "+t;
    };
    public static function staticCall(t:String,m:String,args:Array<Dynamic>):Dynamic {
        if (t == "st.Item" && m == "create") {
            creations++; return {kind:args[0],__host:networked ? {} : null};
        }
        if (t == "ui.Tooltip" && m == "fromItem") {
            var item = args[1], stats:Array<Int> = [], slots:Array<Dynamic> = item.slots.array.values;
            for (id in slots) {
                if (id == null) continue;
                // Like the native EnumValueMap, an unconverted string misses this key.
                var gift = definitions.get("item:CorruptedGift");
                if (id == gift.id) stats.push(Std.int(gift.value) * ((item.flags.value & 1) == 1 ? 2 : 1));
            }
            return {realItem:item,stats:stats};
        }
        throw "Unexpected native static call "+t+"."+m;
    }
}
