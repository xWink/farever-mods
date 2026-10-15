package bettermodsettings;

/** Use normal native flow order: header, tabs, then the settings body. */
class NativeWindowLayout {
    public static inline var WINDOW_WIDTH = 1000;
    public static inline var HEADER_WIDTH = WINDOW_WIDTH - 4;
    public static inline var BODY_LEFT_INSET = 7;
    public static inline var BODY_RIGHT_INSET = 8;
    public static inline var BODY_WIDTH = WINDOW_WIDTH - BODY_LEFT_INSET - BODY_RIGHT_INSET;

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
        style(window, "vspacing", 0);
        call("h2d.Flow", "set_verticalSpacing", window, [0]);
        // The header covers the frame, with a 4px allowance for its native edge.
        // Body insets belong to the body so they do not shorten the header.
        for (side in ["Left", "Right", "Top", "Bottom"]) {
            style(window, "padding-" + side.toLowerCase(), 0);
            call("h2d.Flow", "set_padding" + side, window, [0]);
        }
        var top = HlxRuntime.constructEnum(HlxRuntime.resolveType("h2d.FlowAlign"), "Top", []);
        // valign changes this window's alignment in its parent. Options keeps
        // a centered anchor with a negative offset, so top-aligning that anchor
        // puts the header above the screen. Only align the contents here.
        style(window, "content-valign", top);
        call("h2d.Flow", "set_verticalAlign", window, [top]);
        for (key in ["width", "min-width", "max-width"]) style(header, key, HEADER_WIDTH);
        call("h2d.Flow", "set_minWidth", header, [HEADER_WIDTH]);
        call("h2d.Flow", "set_maxWidth", header, [HEADER_WIDTH]);
        style(header, "fill-width", false);
        call("h2d.Flow", "set_fillWidth", header, [false]);
        // Native title content reserves room for overlaid tabs. Our tabs now
        // occupy their own flow row, so that old top inset must not be counted.
        style(content, "padding-top", 0);
        call("h2d.Flow", "set_paddingTop", content, [0]);
        // Use one explicit horizontal inset on OptionsContent below. Native
        // title-content padding must not be added to that width a second time.
        for (side in ["Left", "Right"]) {
            style(content, "padding-" + side.toLowerCase(), 0);
            call("h2d.Flow", "set_padding" + side, content, [0]);
        }
        if (tabs != null) {
            for (key in ["height", "min-height", "max-height"]) style(tabs, key, 70);
            call("h2d.Flow", "set_minHeight", tabs, [70]);
            call("h2d.Flow", "set_maxHeight", tabs, [70]);
            style(tabs, "padding-top", 10);
            style(tabs, "padding-bottom", 10);
            call("h2d.Flow", "set_paddingTop", tabs, [10]);
            call("h2d.Flow", "set_paddingBottom", tabs, [10]);
        }
        for (child in [header, tabs, content]) {
            if (child == null) continue;
            style(child, "position", false);
            style(child, "offset-x", 0);
            style(child, "offset-y", 0);
            var properties = call("h2d.Flow", "getProperties", window, [child]);
            call("h2d.FlowProperties", "set_isAbsolute", properties, [false]);
            HlxRuntime.setField(properties, "offsetX", 0);
            HlxRuntime.setField(properties, "offsetY", 0);
            // DOMKit margins live in the parent's FlowProperties, separately
            // from the child's padding and height. The native overlay reserves
            // tab/header space here too; reducing the tab height alone leaves it.
            clearMargins(child, properties);
            style(child, "fill-height", false);
            call("h2d.Flow", "set_fillHeight", child, [false]);
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

    public static function compactBody(body:Dynamic):Void {
        if (body == null) return;
        var parent = HlxRuntime.resolveField(body, "parent");
        var properties = parent == null ? null : call("h2d.Flow", "getProperties", parent, [body]);
        clearMargins(body, properties);
        // Leave room for both the decorative side rails and the body's native
        // background/shadow, which paints beyond its layout bounds.
        for (side in ["Left", "Right"]) {
            var inset = side == "Left" ? BODY_LEFT_INSET : BODY_RIGHT_INSET;
            style(body, "margin-" + side.toLowerCase(), inset);
            if (properties != null) HlxRuntime.setField(properties, "padding" + side, inset);
        }
        style(body, "fill-width", false);
        call("h2d.Flow", "set_fillWidth", body, [false]);
        style(body, "padding-top", 0);
        call("h2d.Flow", "set_paddingTop", body, [0]);
        style(body, "fill-height", false);
        call("h2d.Flow", "set_fillHeight", body, [false]);
    }

    static function clearMargins(child:Dynamic, properties:Dynamic):Void {
        for (side in ["Left", "Right", "Top", "Bottom"]) {
            style(child, "margin-" + side.toLowerCase(), 0);
            if (properties != null) HlxRuntime.setField(properties, "padding" + side, 0);
        }
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
