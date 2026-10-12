package itemutilities;

import itemutilities.InspectAccess as G;
import itemutilities.InspectUi.*;

/** A child of the rename dialog, sharing its modal layer and lifetime. */
class BankAffinityWindow {
    public static var constructing = false;
    static inline var WIDTH = 300;
    static inline var HEADER = 52;
    static inline var ROW = 30;
    static inline var ROW_GAP = 6;
    static inline var VISIBLE_ROWS = 13;
    var bank:Dynamic;
    var dialog:Dynamic;
    var panel:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var title:Dynamic;
    var account:String;
    var tab:Int;
    var state:BankAffinityState;
    var changed:Void->Void;
    var checks:Array<{id:String, box:Dynamic}> = [];
    var height:Int;
    var dialogOverflow:Dynamic;

    public function new(bank:Dynamic, dialog:Dynamic, state:BankAffinityState, changed:Void->Void) {
        this.bank = bank; this.dialog = dialog; this.state = state; this.changed = changed;
        try build() catch (error:Dynamic) { dispose(); throw error; }
    }
    function build():Void {
        var me = G.call("ui.BaseElement", "get_myPlayer", bank);
        account = G.text(G.field(me, "uid")); tab = G.integer(G.field(bank, "bankId"), -1);
        if (account == "" || tab < 0) throw "Bank identity is unavailable";
        dialogOverflow = G.field(dialog, "overflow");
        var overflow = G.enumeration("h2d.FlowOverflow", "Limit");
        G.call("h2d.Flow", "set_overflow", dialog, [overflow]); style(dialog, "overflow", overflow);
        var count = Std.int(Math.min(VISIBLE_ROWS, BankAffinityState.CATEGORIES.length));
        height = HEADER + count * ROW + (count - 1) * ROW_GAP + 24;
        // It belongs to the existing dialog, not a second modal window that
        // would steal the rename input's focus or dismiss its parent.
        // BaseWindow's constructor calls autoDisplay before create returns.
        // Suppress it there: changing flags afterwards is too late to stop
        // the native displayWindow path from closing the bank/rename dialog.
        constructing = true;
        try panel = G.create("ui.win.TitleWindow", ["Options", null])
        catch (error:Dynamic) { constructing = false; throw error; }
        constructing = false;
        G.call("ui.win.BaseWindow", "set_windowFlags", panel, [0]);
        G.call("ui.UIElement", "set_isBindLayer", panel, [false]);
        G.call("ui.win.BaseWindow", "rebuild", panel);
        G.call("h2d.Object", "addChild", dialog, [panel]);
        absolute(dialog, panel); padding(panel, 0); size(panel, WIDTH, height);
        for (child in children(panel)) if (G.field(child, "bgMask") != null) {
            absolute(panel, child); padding(child, 0); size(child, WIDTH, height); position(child, 0, 0);
        }
        var dom = G.field(panel, "dom");
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        var content = G.field(dom, "contentRoot");
        // BaseDialog.init (including Rename) uses this same header path.
        // Preserve native #headerTitle styling instead of a custom body label.
        G.call("ui.win.TitleWindow", "setHeader", panel, [null, "Affinities"]);
        var header = G.field(panel, "header");
        padding(header, 0); absolute(panel, header); size(header, WIDTH - 2, HEADER); position(header, 0, 0);
        show(G.field(header, "closeBtn"), false);
        title = G.field(header, "headerTitle");
        var left = G.enumeration("h2d.Align", "Left");
        G.call("h2d.Text", "set_textAlign", title, [left]); style(title, "text-align", left);
        absolute(header, title);
        absolute(panel, content); padding(content, 0); size(content, WIDTH - 16, height - HEADER - 8); position(content, 8, HEADER);
        body = node("options-content", dom, [0], "itemUtilitiesBankAffinities");
        container = prepareBody(body);
        var object = G.field(body, "obj"), options = G.field(object, "optionsList");
        for (entry in [object, options, container]) {
            absolute(G.field(entry, "parent"), entry); padding(entry, 0);
            size(entry, WIDTH - 16, height - HEADER - 8); position(entry, 0, 0);
        }
        // Keep the approved row/font sizes as the category list grows. A
        // vertical Flow with normal children lets native scrolling measure
        // all rows; absolute children would not contribute to contentHeight.
        var listDom = node("flow", G.field(container, "dom"), [], "bankAffinityList", "vertical");
        var list = G.field(listDom, "obj");
        absolute(container, list); padding(list, 8);
        size(list, WIDTH - 16, height - HEADER - 8); position(list, 0, 0);
        G.call("h2d.Flow", "set_verticalSpacing", list, [ROW_GAP]); style(list, "vspacing", ROW_GAP);
        var top = G.enumeration("h2d.FlowAlign", "Top");
        G.call("h2d.Flow", "set_verticalAlign", list, [top]); style(list, "content-valign", top);
        var scroll = G.enumeration("h2d.FlowOverflow", "Scroll");
        G.call("h2d.Flow", "set_overflow", list, [scroll]); style(list, "overflow", scroll);
        // Keep the native scrollbar inside the panel's right gutter.
        var bar = G.field(list, "scrollBar"), cursor = G.field(list, "scrollBarCursor");
        absolute(list, bar); padding(bar, 0); size(bar, 10); size(cursor, 10);
        var barLayout = G.call("h2d.Flow", "getProperties", list, [bar]);
        var right = G.enumeration("h2d.FlowAlign", "Right");
        G.set(barLayout, "horizontalAlign", right); G.set(barLayout, "verticalAlign", top);
        style(bar, "halign", right); style(bar, "valign", top);
        for (i in 0...BankAffinityState.CATEGORIES.length) {
            var category = BankAffinityState.CATEGORIES[i];
            var box = G.field(node("check-box", listDom, [category.label], "bankAffinity" + category.id), "obj");
            var layout = G.call("h2d.Flow", "getProperties", list, [box]);
            G.call("h2d.FlowProperties", "set_isAbsolute", layout, [false]); style(box, "position", false);
            size(box, WIDTH - 44, ROW);
            checks.push({id:category.id, box:box});
            var id = category.id;
            G.set(box, "onValueChange", (value:Bool) -> {
                if (live() && state.set(account, id, tab, value)) changed();
                refresh();
            });
        }
        refresh();
    }
    function live():Bool {
        return G.field(dialog, "removed") != true && G.field(dialog, "parent") != null
            && G.field(bank, "removed") != true && G.field(bank, "parent") != null
            && G.integer(G.field(bank, "bankId"), -1) == tab
            && G.text(G.field(G.call("ui.BaseElement", "get_myPlayer", bank), "uid")) == account;
    }
    function refresh():Void {
        for (entry in checks) {
            var owner = state.owner(account, entry.id);
            G.call("ui.comp.CheckBox", "set_selected", entry.box, [owner == tab]);
            G.call("ui.UIElement", "set_enable", entry.box, [owner < 0 || owner == tab]);
            G.set(entry.box, "alpha", owner >= 0 && owner != tab ? 0.4 : 1.0);
        }
    }
    public function update():Bool {
        if (!live() || !bodyIntact(body, container) || G.field(panel, "parent") != dialog) return false;
        var scene = G.call("h2d.Object", "getScene", dialog);
        if (scene == null) return false;
        var top = point(8, 8), bottom = point(G.number(G.field(scene, "width")) - 8, G.number(G.field(scene, "height")) - 8);
        var width = G.number(G.call("h2d.Flow", "get_outerWidth", dialog));
        var right = bottom.x - width - 12, left = -top.x - 12;
        var useRight = right >= WIDTH || right >= left;
        var scale = Math.max(0.1, Math.min(1, Math.min((useRight ? right : left) / WIDTH, (bottom.y - top.y) / height)));
        G.call("h2d.Object", "setScale", panel, [scale]);
        position(panel, useRight ? width + 12 : -WIDTH * scale - 12,
            Math.max(top.y, Math.min(0, bottom.y - height * scale)));
        G.call("ui.comp.FmtText", "updateScale", title);
        position(title, (WIDTH - G.number(G.call("h2d.Text", "get_textWidth", title)) * G.number(G.field(title, "scaleX"), 1)) / 2,
            (HEADER - G.number(G.call("h2d.Text", "get_textHeight", title)) * G.number(G.field(title, "scaleY"), 1)) / 2);
        return true;
    }
    function point(x:Float, y:Float):{x:Float, y:Float} {
        var p = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(p, "x", x); G.set(p, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", dialog, [p]);
        return {x:G.number(G.field(local, "x")), y:G.number(G.field(local, "y"))};
    }
    public function dispose():Void {
        if (panel != null) { var old = panel; panel = null; G.call("h2d.Object", "remove", old); }
        if (dialog != null && G.field(dialog, "removed") != true && dialogOverflow != null) {
            G.call("h2d.Flow", "set_overflow", dialog, [dialogOverflow]); style(dialog, "overflow", dialogOverflow);
        }
        bank = null; dialog = null; checks = [];
    }
}
