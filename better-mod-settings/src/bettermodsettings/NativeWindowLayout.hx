package bettermodsettings;

/** Use normal native flow order: header, tabs, then the settings body. */
class NativeWindowLayout {
    public static function headerFirst(window:Dynamic, ?tabs:Dynamic):Void {
        var header = HlxRuntime.resolveField(window, "header");
        var content = HlxRuntime.resolveField(window, "titleWindowContent");
        if (header == null || content == null) return;
        // TitleWindow constructs its header last for native overlay styling.
        // BMS adds its own tabs after construction. Make the reading order explicit
        // instead of relying on that overlay CSS or pinning pixel coordinates.
        var vertical = HlxRuntime.constructEnum(HlxRuntime.resolveType("h2d.FlowLayout"), "Vertical", []);
        style(window, "layout", vertical);
        style(window, "reverse", false);
        call("h2d.Flow", "set_layout", window, [vertical]);
        call("h2d.Flow", "set_reverse", window, [false]);
        for (child in [header, tabs, content]) {
            if (child == null) continue;
            style(child, "position", false);
            style(child, "offset-x", 0);
            style(child, "offset-y", 0);
            var properties = call("h2d.Flow", "getProperties", window, [child]);
            call("h2d.FlowProperties", "set_isAbsolute", properties, [false]);
            HlxRuntime.setField(properties, "offsetX", 0);
            HlxRuntime.setField(properties, "offsetY", 0);
        }
        var index:Int = call("h2d.Object", "getChildIndex", window, [content]);
        var headerIndex:Int = call("h2d.Object", "getChildIndex", window, [header]);
        index = Std.int(Math.min(index, headerIndex));
        moveChild(window, header, index);
        if (tabs != null) {
            index = call("h2d.Object", "getChildIndex", window, [header]);
            moveChild(window, tabs, index + 1);
        }
        call("h2d.Flow", "set_needReflow", window, [true]);
    }

    static function moveChild(window:Dynamic, child:Dynamic, index:Int):Void {
        // Flow owns a parallel properties array. Its override preserves those
        // properties during reordering; Object.addChildAt alone would lose them.
        // Flow's public indices exclude its internal background and interactive.
        if (HlxRuntime.resolveField(window, "background") != null) index--;
        if (HlxRuntime.resolveField(window, "interactive") != null) index--;
        call("h2d.Flow", "addChildAt", window, [child, index]);
    }

    static function style(object:Dynamic, key:String, value:Dynamic):Void {
        var dom = HlxRuntime.resolveField(object, "dom");
        if (dom != null) call("domkit.Properties", "initStyle", dom, [key, value]);
    }
    static function call(type:String, name:String, object:Dynamic, args:Array<Dynamic>):Dynamic {
        return HlxRuntime.callResolved(HlxRuntime.resolveMember(HlxRuntime.resolveType(type), name), [object].concat(args));
    }
}
