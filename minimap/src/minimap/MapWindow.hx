package minimap;

import minimap.GameAccess as G;

/**
 * The same native options window the DPS meter uses: rounded parchment frame,
 * header band, and a body underneath. The map is drawn over the body.
 */
class MapWindow {
    public static var constructing:Bool = false;
    public static inline var HEADER:Int = 46;
    public static inline var INSET:Int = 8;

    public var window(default, null):Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var windowContent:Dynamic;
    var frameBackground:Dynamic;
    var header:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var width:Int = 0;
    var height:Int = 0;
    var retryAt:Float = 0;

    public function new() {}

    public function ensure(ui:Dynamic):Bool {
        if (window != null && owner == ui && G.field(window, "removed") != true) return true;
        if (haxe.Timer.stamp() < retryAt) return false;
        dispose();
        if (ui == null) return false;
        try build(ui) catch (_:Dynamic) {
            constructing = false;
            dispose();
            retryAt = haxe.Timer.stamp() + 10;
            return false;
        }
        return window != null;
    }

    public function layout(x:Float, y:Float, w:Float, h:Float):Void {
        if (window == null) return;
        var nextW = Std.int(Math.max(1, w));
        var nextH = Std.int(Math.max(1, h));
        if (nextW != width || nextH != height) {
            width = nextW;
            height = nextH;
            var innerWidth = width - INSET * 2;
            var bodyHeight = height - HEADER - INSET;
            size(window, width, height);
            if (frameBackground != null) {
                size(frameBackground, width, height);
                position(frameBackground, 0, 0);
            }
            size(header, width - 2, HEADER);
            position(header, 0, 0);
            size(windowContent, innerWidth, bodyHeight);
            position(windowContent, INSET, HEADER);
            var bodyObject = G.field(body, "obj");
            var options = G.field(bodyObject, "optionsList");
            for (object in [bodyObject, options, container]) {
                size(object, innerWidth, bodyHeight);
                position(object, 0, 0);
            }
        }
        position(window, x, y);
    }

    public function setAlpha(alpha:Float):Void {
        if (window != null) G.set(window, "alpha", alpha);
    }

    public function show(visible:Bool):Void {
        if (window != null) G.call("h2d.Object", "set_visible", window, [visible]);
    }

    public function dispose():Void {
        if (window != null) {
            var old = window;
            window = null;
            try G.call("h2d.Object", "remove", old) catch (_:Dynamic) {}
        }
        owner = null;
        root = null;
        windowContent = null;
        frameBackground = null;
        header = null;
        body = null;
        container = null;
        width = 0;
        height = 0;
    }

    function build(ui:Dynamic):Void {
        owner = ui;
        root = G.field(ui, "root");
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (e:Dynamic) {
            constructing = false;
            throw e;
        }
        constructing = false;
        if (window == null) throw "TitleWindow construction returned null";
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192]);
        // Stay out of BaseUI.windows so the map does not pause the game.
        var index = G.integer(G.call("h2d.Object", "getChildIndex", root, [G.field(ui, "gameRoot")]));
        G.call("h2d.Flow", "addChildAt", root, [window, index]);
        absolute(root, window);
        var dom = G.field(window, "dom");
        windowContent = G.field(dom, "contentRoot");
        if (windowContent == null || windowContent == window) throw "Native window content wrapper was not found";
        frameBackground = null;
        var count = G.integer(G.call("h2d.Object", "get_numChildren", window));
        for (i in 0...count) {
            var child = G.call("h2d.Object", "getChildAt", window, [i]);
            if (G.field(child, "bgMask") != null) { frameBackground = child; break; }
        }
        if (frameBackground != null) absolute(window, frameBackground);
        var component = G.staticCall("domkit.Component", "get", ["options-window", null]);
        if (component != null) G.set(dom, "component", component);
        header = G.field(window, "header");
        G.set(header, "headText", "");
        showChild(G.field(header, "headerTitle"), false);
        showChild(G.field(header, "closeBtn"), false);
        body = node("options-content", dom, [0], "minimapMapBody");
        container = prepareBody(body);
        var bodyObject = G.field(body, "obj");
        var options = G.field(bodyObject, "optionsList");
        var limit = G.current("h2d.FlowOverflow", "Limit");
        for (object in [window, frameBackground, windowContent, header, bodyObject, options, container]) {
            if (object == null) continue;
            padding(object, 0);
            if (limit != null) {
                try {
                    G.call("h2d.Flow", "set_overflow", object, [limit]);
                    style(object, "overflow", limit);
                } catch (_:Dynamic) {}
            }
        }
        absolute(window, windowContent);
        absolute(window, header);
        absolute(windowContent, bodyObject);
        absolute(bodyObject, options);
        absolute(options, container);
        width = 0;
        height = 0;
        show(false);
    }

    /** OptionsList rebuilds itself unless its settings binds are cleared. */
    function prepareBody(bodyDom:Dynamic):Dynamic {
        var object = G.field(bodyDom, "obj");
        var options = G.field(object, "optionsList");
        var input = G.field(object, "inputList");
        var host = G.field(options, "container");
        if (host == null) throw "Native options content container was not found";
        for (component in [object, options, input])
            if (component != null) G.call("ui.UIElement", "clearBinds", component);
        showChild(input, false);
        showChild(G.field(options, "applyBtn"), false);
        var count = G.integer(G.call("h2d.Object", "get_numChildren", host));
        for (i in 0...count) showChild(G.call("h2d.Object", "getChildAt", host, [i]), false);
        return host;
    }

    function node(component:String, parent:Dynamic, args:Array<Dynamic>, id:String):Dynamic {
        var result = G.staticCall("domkit.Properties", "createNew", [component, parent, args, {id: id}]);
        if (result == null) throw "Could not create " + component;
        return result;
    }

    function absolute(parent:Dynamic, child:Dynamic):Void {
        var properties = G.call("h2d.Flow", "getProperties", parent, [child]);
        G.call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
        G.set(properties, "horizontalAlign", null);
        G.set(properties, "verticalAlign", null);
        G.set(properties, "offsetX", 0);
        G.set(properties, "offsetY", 0);
        var dom = G.field(child, "dom");
        if (dom != null) {
            G.call("domkit.Properties", "initStyle", dom, ["position", true]);
            for (key in ["halign", "valign"]) G.call("domkit.Properties", "initStyle", dom, [key, null]);
            for (key in ["offset-x", "offset-y"]) G.call("domkit.Properties", "initStyle", dom, [key, 0]);
        }
    }

    function padding(object:Dynamic, value:Int):Void {
        G.call("h2d.Flow", "set_padding", object, [value]);
        for (side in ["left", "right", "top", "bottom"]) style(object, "padding-" + side, value);
    }

    function size(object:Dynamic, w:Int, h:Int = -1):Void {
        G.call("h2d.Flow", "set_minWidth", object, [w]);
        G.call("h2d.Flow", "set_maxWidth", object, [w]);
        if (h >= 0) {
            G.call("h2d.Flow", "set_minHeight", object, [h]);
            G.call("h2d.Flow", "set_maxHeight", object, [h]);
        }
        var dom = G.field(object, "dom");
        if (dom != null) {
            for (property in ["width", "min-width", "max-width"]) G.call("domkit.Properties", "initStyle", dom, [property, w]);
            if (h >= 0) for (property in ["height", "min-height", "max-height"]) G.call("domkit.Properties", "initStyle", dom, [property, h]);
        }
    }

    function style(object:Dynamic, property:String, value:Dynamic):Void {
        var dom = G.field(object, "dom");
        if (dom != null) G.call("domkit.Properties", "initStyle", dom, [property, value]);
    }

    function showChild(object:Dynamic, visible:Bool):Void {
        if (object != null) G.call("h2d.Object", "set_visible", object, [visible]);
    }

    static function position(object:Dynamic, x:Float, y:Float):Void
        G.call("h2d.Object", "setPosition", object, [x, y]);
}
