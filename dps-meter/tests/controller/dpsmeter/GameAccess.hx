package dpsmeter;

/** Controller registry model: changing window flags alone cannot release focus. */
class GameAccess {
    public static var layers:Array<Dynamic> = [];
    public static var focused:Dynamic;
    public static var bindings:Array<Dynamic> = [];
    public static function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);
    public static function set(object:Dynamic, name:String, value:Dynamic):Void
        Reflect.setField(object, name, value);
    public static function integer(value:Dynamic, fallback:Int = 0):Int
        return value == null ? fallback : Std.int(value);

    public static function attach(object:Dynamic):Void {
        object.allocated = true;
        if (field(object, "isBindLayer") == true && layers.indexOf(object) < 0) layers.push(object);
        if (field(object, "padFocusable") == true && field(object, "padDefaultFocus") == true) focused = object;
        if (field(object, "padClick") != null || field(object, "padHover") != null) {
            if (bindings.indexOf(object) < 0) bindings.push(object);
        }
        for (child in (cast object.children:Array<Dynamic>)) attach(child);
    }

    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        switch (type + "." + name) {
            case "h2d.Object.get_numChildren": return (cast object.children:Array<Dynamic>).length;
            case "h2d.Object.getChildAt": return object.children[args[0]];
            case "ui.UIElement.set_padDefaultFocus": object.padDefaultFocus = args[0];
            case "ui.UIElement.set_padFocusable":
                if (object.allocated && !args[0] && focused == object) focused = null;
                object.padFocusable = args[0];
            case "ui.UIElement.set_padClick", "ui.UIElement.set_padHover":
                set(object, name.substr(4), args[0]);
                if (object.padClick == null && object.padHover == null) bindings.remove(object);
            case "ui.UIElement.set_isBindLayer":
                if (object.allocated && object.isBindLayer && !args[0]) layers.remove(object);
                object.isBindLayer = args[0];
            case "domkit.Properties.initStyle":
                (cast object.styles:Map<String, Dynamic>).set(args[0], args[1]);
            default: throw "Unexpected focus call: " + type + "." + name;
        }
        return null;
    }

    public static function applyControllerStyles(object:Dynamic):Void {
        // The game's button/controller styles would otherwise restore these.
        var defaults:Map<String, Dynamic> = ["pad-focusable" => true, "pad-default-focus" => true,
            "pad-always-focusable" => true, "is-bind-layer" => true, "pad-click" => "UIAccept", "pad-hover" => "UIInspect"];
        var fields = ["pad-focusable" => "padFocusable", "pad-default-focus" => "padDefaultFocus",
            "pad-always-focusable" => "padAlwaysFocusable", "is-bind-layer" => "isBindLayer",
            "pad-click" => "padClick", "pad-hover" => "padHover"];
        var inlineStyles:Map<String, Dynamic> = object.dom.styles;
        for (property => value in defaults)
            set(object, fields[property], inlineStyles.exists(property) ? inlineStyles[property] : value);
        attach(object);
    }
}
