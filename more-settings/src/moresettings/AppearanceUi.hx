package moresettings;

import moresettings.GameAccess as G;

/** Shared native UI helpers for friend notes, character locks, and chat. */
class AppearanceUi {
    public static function node(component:String, parent:Dynamic, args:Array<Dynamic>, id:String, ?layout:String):Dynamic {
        // Button labels go through FmtText's XML parser too. A literal "<"
        // must be escaped before construction, not after its first reflow.
        if (component == "button" && args.length > 0) {
            args = args.copy();
            args[0] = escape(G.text(args[0]));
        }
        var attributes:Dynamic = {id: id};
        if (layout != null) Reflect.setField(attributes, "layout", layout);
        var result = G.staticCall("domkit.Properties", "createNew", [component, parent, args, attributes]);
        if (result == null) throw "Could not create " + component;
        return result;
    }
    public static function style(object:Dynamic, property:String, value:Dynamic):Void {
        var dom = G.field(object, "dom");
        if (dom != null) G.call("domkit.Properties", "initStyle", dom, [property, value]);
    }
    public static function padding(object:Dynamic, value:Int):Void {
        G.call("h2d.Flow", "set_padding", object, [value]);
        for (side in ["left", "right", "top", "bottom"]) style(object, "padding-" + side, value);
    }
    public static function size(object:Dynamic, w:Int, h:Int = -1):Void {
        G.call("h2d.Flow", "set_minWidth", object, [w]);
        G.call("h2d.Flow", "set_maxWidth", object, [w]);
        if (h >= 0) {
            G.call("h2d.Flow", "set_minHeight", object, [h]);
            G.call("h2d.Flow", "set_maxHeight", object, [h]);
        }
        var d = G.field(object, "dom");
        if (d != null) {
            for (property in ["width", "min-width", "max-width"]) G.call("domkit.Properties", "initStyle", d, [property, w]);
            if (h >= 0) for (property in ["height", "min-height", "max-height"]) G.call("domkit.Properties", "initStyle", d, [property, h]);
        }
    }
    public static function children(object:Dynamic):Array<Dynamic> {
        var count = G.integer(G.call("h2d.Object", "get_numChildren", object));
        return [for (i in 0...count) G.call("h2d.Object", "getChildAt", object, [i])];
    }
    public static function absolute(parent:Dynamic, child:Dynamic):Void {
        var p = G.call("h2d.Flow", "getProperties", parent, [child]);
        G.call("h2d.FlowProperties", "set_isAbsolute", p, [true]);
        G.set(p, "horizontalAlign", null); G.set(p, "verticalAlign", null);
        G.set(p, "offsetX", 0); G.set(p, "offsetY", 0);
        // Keep native CSS from restoring automatic centering on hover/reflow.
        var dom = G.field(child, "dom");
        if (dom != null) {
            G.call("domkit.Properties", "initStyle", dom, ["position", true]);
            for (key in ["halign", "valign"]) G.call("domkit.Properties", "initStyle", dom, [key, null]);
            for (key in ["offset-x", "offset-y"]) G.call("domkit.Properties", "initStyle", dom, [key, 0]);
        }
    }
    public static function position(obj:Dynamic, x:Float, y:Float):Void G.call("h2d.Object", "setPosition", obj, [x, y]);
    public static function show(obj:Dynamic, visible:Bool):Void { if (obj != null) G.call("h2d.Object", "set_visible", obj, [visible]); }
    public static function escape(value:String):String {
        if (value == null) return "";
        var text = StringTools.htmlEscape(value);
        return StringTools.replace(StringTools.replace(text, "[", "&#91;"), "$", "&#36;");
    }
    public static function message(ui:Dynamic, title:String, text:String):Void {
        var buttons = G.call("hl.types.ArrayObj", "slice", G.field(ui, "windows"), [0, 0]);
        G.call("hl.types.ArrayObj", "pushDyn", buttons, [{ic: "Confirm", input: null, checkEnable: null, onBack: true}]);
        // Parser errors can themselves contain "<". Passing the raw exception
        // to this dialog would fail again while constructing its formatted text.
        var dialog = G.call("ui.BaseUI", "displayDialog", ui,
            [escape(title), escape(text), buttons, (_:String) -> {}]);
        for (button in G.array(G.field(dialog, "buttons"))) G.call("ui.comp.Button", "setText", button, ["OK"]);
    }
}
