package itemutilities;
class InspectAccess {
    public static function field(object:Dynamic, name:String):Dynamic return object == null ? null : Reflect.field(object,name);
    public static function text(value:Dynamic):String return value == null ? "" : Std.string(value);
    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) value = field(value,"array");
        return value == null ? [] : cast value;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type == "st.Item" && name == "isType") return (cast object.types:Array<String>).indexOf(args[0]) >= 0;
        throw "Unexpected native/network action: " + type + "." + name;
    }
}
