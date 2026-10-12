package itemutilities;

/** Native boundary for identity/availability tests; no network requests. */
class InspectAccess {
    public static function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);
    public static function text(value:Dynamic, fallback:String = ""):String
        return value == null ? fallback : Std.string(value);
    public static function isA(object:Dynamic, name:String):Bool return field(object, "type") == name;
    public static function array(value:Dynamic, proxy:Bool = false):Array<Dynamic> {
        if (proxy) value = field(value, "array");
        return value == null ? [] : cast value;
    }
    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        return switch type + "." + name {
            case "ui.BaseElement.get_myPlayer": object.me;
            case "ui.BaseElement.get_baseUI": object.ui;
            case "st.Player.getName": object.name;
            case "st.GameLayer.getPlayerById":
                var found:Dynamic = null;
                var list = field(object.players, "array");
                for (p in array(list == null ? object.players : list)) if (p.uid == args[0]) found = p;
                found;
            default: throw "Unexpected native/network call: " + type + "." + name;
        }
    }
}
