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
            case "ent.Hero.get_equipment": field(object, "equipment");
            case "ent.Hero.get_weapon1": field(object, "weapon1");
            case "ent.Hero.get_weapon2": field(object, "weapon2");
            case "st.GameLayer.getPlayerById":
                var found:Dynamic = null;
                for (p in array(object.players)) if (p.uid == args[0]) found = p;
                found;
            default: throw "Unexpected native/network call: " + type + "." + name;
        }
    }
}
