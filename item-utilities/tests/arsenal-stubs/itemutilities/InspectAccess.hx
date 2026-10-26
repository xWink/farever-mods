package itemutilities;

/** Strict native boundary fixture; the RPC deliberately does not replicate immediately. */
class InspectAccess {
    public static var data:Dynamic;
    public static var calls:Array<Dynamic> = [];
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object, name);
    public static function text(value:Dynamic):String return value == null ? "" : Std.string(value);
    public static function integer(value:Dynamic):Int return Std.int(value);
    public static function isA(object:Dynamic, name:String):Bool return field(object, "type") == name;
    public static function array(value:Dynamic):Array<Dynamic> {
        if (value == null) return [];
        #if hl
        return [for (i in 0...cast(field(value, "length"), Int))
            Reflect.callMethod(value, Reflect.field(value, "getDyn"), [i])];
        #else
        return [for (v in (cast value:Array<Dynamic>)) v];
        #end
    }
    public static function current(type:String, name:String):Dynamic {
        if (type != "Data") throw "Unexpected static field: " + type + "." + name;
        return field(data, name);
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type != "st.item.Weapon" || name != "isValidArsenalSkill") throw "Unexpected native static call";
        return (cast field(args[0], "valid"):Array<String>).indexOf(args[1]) >= 0;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (args == null) args = [];
        calls.push({type:type, name:name, object:object, args:args});
        if (type == "haxe.ds.StringMap" && name == "get") return (cast object:Map<String, Dynamic>).get(args[0]);
        if (type == "ent.Hero" && name == "getNbArsenalSkillSlots") return field(object, "limit");
        if (type == "st.player.HeroSpecialization" && name == "getArsenalSkills")
            return (cast field(object, "arsenals"):Map<String, Dynamic>).get(args[0]);
        if (type == "st.player.HeroSpecialization" && name == "setArsenalSkills") {
            Reflect.setField(object, "request", {weapon:args[0], skills:args[1]});
            return null;
        }
        if (type == "hl.types.ArrayObj" && ["copy", "resize", "push"].indexOf(name) >= 0)
            return Reflect.callMethod(object, Reflect.field(object, name), args);
        throw "Unexpected native call: " + type + "." + name;
    }
}
