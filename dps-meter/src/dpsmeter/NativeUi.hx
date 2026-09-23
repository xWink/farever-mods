package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;

/** Shared native DOM layout and formatting for the meter and rift recap. */
class NativeUi {
    public static function prepareChartBody(body:Dynamic):Dynamic {
        var object = G.field(body, "obj");
        var options = G.field(object, "optionsList");
        var input = G.field(object, "inputList");
        var container = G.field(options, "container");
        if (container == null) throw "Native Options content container was not found";
        // Keep the native styling ancestry, but stop the settings callbacks:
        // OptionsList watches display mode and otherwise rebuilds over our chart.
        // Do this before adding any of the chart's own controls.
        for (component in [object, options, input])
            if (component != null) G.call("ui.UIElement", "clearBinds", component);
        show(input, false);
        show(G.field(options, "applyBtn"), false);
        for (child in children(container)) show(child, false);
        return container;
    }
    public static function chartBodyIntact(body:Dynamic, container:Dynamic):Bool {
        // A native rebuild can replace children while the outer window survives.
        return container != null && G.field(container, "removed") != true
            && G.field(container, "parent") != null
            && G.field(G.field(G.field(body, "obj"), "optionsList"), "container") == container;
    }
    public static function attachBelowGameUi(ui:Dynamic, window:Dynamic):Dynamic {
        var root = G.field(ui, "root");
        // Stay above rootBG, but below gameRoot's HUD, menus and dialogue.
        // Native tooltips and overlays are on higher scene layers as well.
        var index = G.integer(G.call("h2d.Object", "getChildIndex", root, [G.field(ui, "gameRoot")]));
        // Call Flow's override: Object.addChildAt skips the matching layout
        // entry and leaves the root's children/properties arrays out of sync.
        G.call("h2d.Flow", "addChildAt", root, [window, index]);
        absolute(root, window);
        return root;
    }
    public static function node(component:String, parent:Dynamic, args:Array<Dynamic>, id:String, ?layout:String):Dynamic {
        var attributes:Dynamic = {id: id};
        if (layout != null) Reflect.setField(attributes, "layout", layout);
        var result = G.staticCall("domkit.Properties", "createNew", [component, parent, args, attributes]);
        if (result == null) throw "Could not create " + component;
        // Also covers rows/buttons added after construction, without walking
        // the meter each frame. Recap/history and other windows are unaffected.
        MeterControllerFocus.configureNode(G.field(result, "obj"));
        return result;
    }
    public static function label(parent:Dynamic, value:String):Dynamic {
        // DOMKit's native text component supplies the same fonts as Options.
        var d = node("text", parent, [LiteralText.escape(value)], "dpsMeterText");
        var obj = G.field(d, "obj");
        G.call("h2d.Text", "set_textColor", obj, [0x5b4334]);
        return obj;
    }
    public static function button(parent:Dynamic, value:String, id:String, click:Void->Void):Dynamic {
        var object = G.field(node("button", parent, [LiteralText.escape(value)], id), "obj");
        G.call("ui.UIElement", "set_onClick", object, [click]);
        return object;
    }
    public static function bookButton(parent:Dynamic, click:Void->Void):Dynamic {
        var object = button(parent, "", "dpsMeterHistory", click);
        padding(object, 0); size(object, 34, 30);
        var book = G.create("h2d.Graphics", [object]);
        absolute(object, book); position(book, 5, 5);
        G.call("h2d.Graphics", "lineStyle", book, [1.5, 0x5b4334, 1.0]);
        G.call("h2d.Graphics", "beginFill", book, [0xf3dfbc, 1.0]);
        for (page in [[[12., 3.], [8., 1.], [1., 1.], [1., 17.], [8., 17.], [12., 19.]],
            [[12., 3.], [16., 1.], [23., 1.], [23., 17.], [16., 17.], [12., 19.]]]) {
            G.call("h2d.Graphics", "moveTo", book, [page[0][0], page[0][1]]);
            for (i in 1...page.length) G.call("h2d.Graphics", "lineTo", book, [page[i][0], page[i][1]]);
            G.call("h2d.Graphics", "lineTo", book, [page[0][0], page[0][1]]);
        }
        G.call("h2d.Graphics", "endFill", book);
        G.call("h2d.Graphics", "lineStyle", book, [1.0, 0xb48c50, 1.0]);
        for (y in [6., 10., 14.]) for (x in [4., 15.]) {
            G.call("h2d.Graphics", "moveTo", book, [x, y]);
            G.call("h2d.Graphics", "lineTo", book, [x + 5, y]);
        }
        return object;
    }
    public static function damagePercent(amount:Float, total:Float):String
        return Std.string(SkillStats.rounded(total <= 0 ? 0 : amount * 100 / total, 1));
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
    public static function setText(obj:Dynamic, value:String):Void {
        if (obj != null) G.call("ui.comp.FmtText", "set_text", obj, [LiteralText.escape(value)]);
    }
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
