package bettermodsettings;

/** Pin the native title/close chrome above tabs independently of Options CSS. */
class NativeSettingsChrome {
    public static function layout(window:Dynamic, tabs:Dynamic):Void {
        var header = field(window, "header"), content = field(window, "titleWindowContent");
        var count:Int = call("h2d.Object", "get_numChildren", window, []);
        for (i in 0...count) {
            var child = call("h2d.Object", "getChildAt", window, [i]);
            if (field(child, "bgMask") != null) { pin(window, child); size(child, 1000, 646); at(child, 0, 0); }
        }
        if (header == null || content == null || tabs == null) throw "Mod Settings window chrome is unavailable.";
        size(window, 1000, 646);
        for (child in [header, tabs, content]) pin(window, child);
        size(header, 1000, 60); size(tabs, 990, 50); size(content, 1000, 520);
        var title = field(header, "headerTitle"), close = field(header, "closeBtn");
        pin(header, title); pin(header, close); size(close, 36, 36);
        var position = function():Void {
            at(header, 0, 0); at(tabs, 5, 60); at(content, 0, 110);
            at(title, 32, 14); at(close, 948, 12);
        };
        // Native reflows may run after GameApp.update, including tab changes.
        var previous = field(window, "onAfterReflow");
        HlxRuntime.setField(window, "onAfterReflow", function():Void {
            if (previous != null) Reflect.callMethod(window, previous, []);
            position();
        });
        position();
    }
    static function pin(parent:Dynamic, child:Dynamic):Void {
        if (child == null) return;
        var properties = call("h2d.Flow", "getProperties", parent, [child]);
        call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
        for (key in ["horizontalAlign", "verticalAlign"]) HlxRuntime.setField(properties, key, null);
        for (key in ["offsetX", "offsetY"]) HlxRuntime.setField(properties, key, 0);
        style(child, "position", true);
        for (key in ["halign", "valign"]) style(child, key, null);
        for (key in ["offset-x", "offset-y"]) style(child, key, 0);
    }
    static function size(object:Dynamic, width:Int, height:Int):Void {
        for (key in ["width", "min-width", "max-width"]) style(object, key, width);
        for (key in ["height", "min-height", "max-height"]) style(object, key, height);
        for (key in ["set_minWidth", "set_maxWidth"]) call("h2d.Flow", key, object, [width]);
        for (key in ["set_minHeight", "set_maxHeight"]) call("h2d.Flow", key, object, [height]);
    }
    static function at(object:Dynamic, x:Float, y:Float):Void {
        if (object != null) call("h2d.Object", "setPosition", object, [x, y]);
    }
    static function style(object:Dynamic, key:String, value:Dynamic):Void {
        var dom = field(object, "dom");
        if (dom != null) call("domkit.Properties", "initStyle", dom, [key, value]);
    }
    static function field(object:Dynamic, key:String):Dynamic return object == null ? null : HlxRuntime.resolveField(object, key);
    static function call(type:String, name:String, object:Dynamic, args:Array<Dynamic>):Dynamic {
        return HlxRuntime.callResolved(HlxRuntime.resolveMember(HlxRuntime.resolveType(type), name), [object].concat(args));
    }
}
