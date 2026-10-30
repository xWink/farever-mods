package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

typedef HistoryChoice = {value:String, name:String, ?color:Int};

/** Native dropdown with detached option values and optional class-coloured text. */
class HistoryDropdown {
    public var object(default, null):Dynamic;
    var choices:Array<HistoryChoice> = [];
    var signature:String = "";
    var selected:String;
    var captionPrefix:String;
    public function new(parent:Dynamic, id:String, choices:Array<HistoryChoice>, selected:String, changed:String->Void,
        captionPrefix:String = "") {
        this.captionPrefix = captionPrefix;
        object = G.field(node("dropdown", parent, [false, false, "dps-history-options"], id), "obj");
        padding(object, 0);
        // The history window is above gameRoot. Native Dropdown.toggle first
        // registers its list under gameRoot, then honours this parent override.
        // Append the list to the same root as history so it draws above it.
        var popupRoot = G.field(G.current("ui.BaseUI", "current"), "root");
        G.set(object, "getListLayout", () -> popupRoot);
        setChoices(choices, selected);
        G.call("ui.UIElement", "set_onClick", G.field(object, "select"), [() -> {
            G.call("ui.comp.Dropdown", "toggle", object, [null]);
            var popup = G.field(object, "listWindow");
            if (popup != null && G.field(popup, "parent") == popupRoot) absolute(popupRoot, popup);
            refreshColors();
        }]);
        G.set(object, "onValueChanged", (value:Dynamic) -> {
            this.selected = G.text(value);
            refreshColors(); changed(this.selected);
        });
    }
    public function setChoices(values:Array<HistoryChoice>, selected:String):Void {
        this.selected = selected;
        var signature = haxe.Json.stringify(values);
        if (this.signature != signature) {
            this.signature = signature; choices = values;
            // Dropdown requires the game's ArrayObj, never a mod ArrayDyn.
            var windows = G.field(G.current("ui.BaseUI", "current"), "windows");
            var options = G.call("hl.types.ArrayObj", "slice", windows, [0, 0]);
            for (choice in choices) G.call("hl.types.ArrayObj", "pushDyn", options,
                [{name: LiteralText.escape(choice.name), value: choice.value, icon: null, group: null}]);
            G.call("ui.comp.Dropdown", "set_options", object, [options]);
        }
        var index = 0;
        for (i in 0...choices.length) if (choices[i].value == selected) { index = i; break; }
        G.call("ui.comp.Dropdown", "initSelectedIndex", object, [index]);
        refreshColors();
    }
    public function select(value:String):Void setChoices(choices, value);
    public function resize(width:Int):Void {
        size(object, width, 34); size(G.field(object, "select"), width, 34);
        G.call("ui.comp.FmtText", "set_maxWidthText", G.field(object, "selectText"), [Std.int(Math.max(1, width - 44))]);
        G.call("ui.comp.FmtText", "set_useEllipsis", G.field(object, "selectText"), [true]);
    }
    public function isOpen():Bool return G.call("ui.comp.Dropdown", "isOpen", object) == true;
    public function close():Void G.call("ui.comp.Dropdown", "close", object, [null]);
    public function refreshColors():Void {
        var index = G.integer(G.field(object, "selectedIndex"));
        if (captionPrefix != "" && index >= 0 && index < choices.length)
            setText(G.field(object, "selectText"), captionPrefix + choices[index].name);
        color(G.field(object, "selectText"), choiceColor(index));
        var items = G.array(G.field(object, "items"));
        for (i in 0...items.length) for (child in children(items[i]))
            if (G.field(child, "font") != null) color(child, choiceColor(i));
    }
    function choiceColor(index:Int):Int return index >= 0 && index < choices.length && choices[index].color != null
        ? choices[index].color : 0x5b4334;
    static function color(text:Dynamic, value:Int):Void {
        if (text == null) return;
        // Pin the native CSS property, including hover/selection recomputation.
        // Correcting glyphs on a timer fights CSS and visibly flickers.
        style(text, "color", value);
        // FmtText inherits HtmlText: colour belongs in its glyph data. Calling
        // Text's base setter instead multiplies that colour by a second tint.
        var tint = G.field(text, "color");
        if (tint != null) for (channel in ["x", "y", "z"]) G.set(tint, channel, 1.0);
        G.call("h2d.HtmlText", "set_textColor", text, [value]);
    }
    public function closeOutside(x:Float, y:Float):Void {
        if (isOpen() && !contains(G.field(object, "select"), x, y)
            && !contains(G.field(object, "listWindow"), x, y)) close();
    }
    static function contains(object:Dynamic, x:Float, y:Float):Bool {
        if (object == null || G.field(object, "parent") == null) return false;
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", object, [point]);
        var px = G.number(G.field(local, "x")); var py = G.number(G.field(local, "y"));
        return px >= 0 && py >= 0 && px < G.number(G.call("h2d.Flow", "get_outerWidth", object))
            && py < G.number(G.call("h2d.Flow", "get_outerHeight", object));
    }
}
