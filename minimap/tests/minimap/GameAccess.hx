package minimap;

/** Native activity/progress boundary for the interpreter regression tests. */
class GameAccess {
    public static var definitions:Map<String, Dynamic> = [];
    public static var completionReads:Int = 0;

    public static function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);

    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type != "HActivity" || name != "isOfType") throw "Unexpected native static call";
        var inf = args[0];
        // Native HActivity.isOfType follows IDs through the inheritance chain.
        while (inf != null) {
            if (field(inf, "id") == args[1]) return true;
            var parent = field(inf, "inherit");
            if (parent == null) return false;
            inf = definitions[parent];
        }
        return false;
    }

    public static function call(type:String, name:String, object:Dynamic, ?args:Array<Dynamic>):Dynamic {
        if (type != "st.player.Progress" || name != "hasActivityCompleted") throw "Unexpected native call";
        completionReads++;
        return object.completed == args[0];
    }
}
