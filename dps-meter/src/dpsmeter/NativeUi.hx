package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;

/** Shared native DOM layout and formatting for the meter and rift recap. */
class NativeUi {
    public static function node(component:String, parent:Dynamic, args:Array<Dynamic>, id:String, ?layout:String):Dynamic {
        var attributes:Dynamic = {id: id};
        if (layout != null) Reflect.setField(attributes, "layout", layout);
        var result = G.staticCall("domkit.Properties", "createNew", [component, parent, args, attributes]);
        if (result == null) throw "Could not create " + component;
        return result;
    }
    public static function label(parent:Dynamic, value:String):Dynamic {
        // DOMKit's native text component supplies the same fonts as Options.
        var d = node("text", parent, [value], "dpsMeterText");
        var obj = G.field(d, "obj");
        G.call("h2d.Text", "set_textColor", obj, [0x5b4334]);
        return obj;
    }
    public static function flow(dom:Dynamic, method:String, value:Dynamic):Void G.call("h2d.Flow", method, G.field(dom, "obj"), [value]);
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
    public static function setText(obj:Dynamic, value:String):Void { if (obj != null) G.call("ui.comp.FmtText", "set_text", obj, [value]); }
    public static function classColor(name:String):Int return switch (name) {
        // Original dinput8.dll palette at RVA 0x139e0, converted COLORREF -> RGB.
        case "warrior": 0xc95846; case "cleric": 0xd9b054; case "mage": 0x62b2c2; case "rogue": 0xa370be; default: 0xa89884;
    };
    public static function compact(n:Float):String {
        return n >= 1000000 ? Std.string(SkillStats.rounded(n / 1000000, 2)) + "M"
            : n >= 1000 ? Std.string(SkillStats.rounded(n / 1000, 1)) + "k" : Std.string(Math.fround(n));
    }
    public static function duration(n:Float):String return Std.int(n / 60) + ":" + StringTools.lpad(Std.string(Std.int(n) % 60), "0", 2);
}
