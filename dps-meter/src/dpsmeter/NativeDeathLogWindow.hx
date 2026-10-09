package dpsmeter;

import dpsmeter.DeathLog;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

typedef DeathRow = {
    root:Dynamic,
    time:Dynamic,
    bar:Dynamic,
    amount:Dynamic,
    icon:Dynamic,
    spell:Dynamic,
    source:Dynamic
};

/** Timeline of the last 10 seconds before death: time, health, amount, spell, and source. */
class NativeDeathLogWindow {
    public static var constructing:Bool = false;
    static inline var WIDTH:Int = 760;
    static inline var HEADER:Int = 48;
    static inline var COLUMNS:Int = 34;
    static inline var ROW:Int = 22;
    static inline var VISIBLE:Int = 16;
    static inline var TIME_X:Float = 12;
    static inline var BAR_X:Float = 86;
    static inline var BAR_W:Float = 92;
    static inline var BAR_H:Float = 8;
    static inline var AMOUNT_X:Float = 190;
    static inline var SPELL_X:Float = 300;
    static inline var ICON:Float = 16;
    static inline var SOURCE_X:Float = 530;

    var window:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var windowContent:Dynamic;
    var frameBackground:Dynamic;
    var header:Dynamic;
    var title:Dynamic;
    var close:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var wrappers:Array<Dynamic> = [];
    var columns:Array<Dynamic> = [];
    var rows:Array<DeathRow> = [];
    var mask:Dynamic;
    var content:Dynamic;
    var wheel:Dynamic;
    var report:Null<DeathReport>;
    var rowCount:Int = 0;
    var scroll:Float = 0;
    var maxScroll:Float = 0;
    var width:Int = 0;
    var height:Int = 0;
    var retryAt:Float = 0;

    public function new() {}

    public function present(next:DeathReport):Void {
        pending = next;
        if (window != null) dispose();
    }

    var pending:Null<DeathReport>;

    public function isOpen():Bool return window != null || pending != null;

    public function dismiss():Void {
        pending = null;
        dispose();
    }

    public function update(enabled:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (owner != null && owner != ui) dispose();
        if (window != null && G.field(window, "removed") == true) dispose();
        if (!enabled) { pending = null; dispose(); return; }
        if (ui == null) { dispose(); return; }
        if (pending != null && now >= retryAt) {
            var next = pending;
            try {
                dispose();
                build(ui, next);
                pending = null;
            } catch (error:Dynamic) {
                constructing = false;
                dispose();
                pending = next;
                retryAt = now + 1;
                trace("[DPS Meter] Death log: " + Std.string(error));
                return;
            }
        }
        if (window != null) layout();
    }

    function build(ui:Dynamic, shown:DeathReport):Void {
        owner = ui;
        report = shown;
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (error:Dynamic) { constructing = false; throw error; }
        constructing = false;
        if (window == null) throw "TitleWindow construction returned null";
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192]);
        root = G.field(ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        absolute(root, window);
        var dom = G.field(window, "dom");
        windowContent = G.field(dom, "contentRoot");
        for (child in children(window)) if (G.field(child, "bgMask") != null) {
            frameBackground = child;
            absolute(window, frameBackground);
            break;
        }
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        header = G.field(window, "header");
        G.set(header, "headText", "Death Log");
        title = G.field(header, "headerTitle");
        setText(title, "Death Log");
        var left = G.enumeration("h2d.Align", "Left");
        G.call("h2d.Text", "set_textAlign", title, [left]);
        style(title, "text-align", left);
        show(title, true);
        absolute(header, title);
        close = G.field(header, "closeBtn");
        show(close, true);
        absolute(header, close);
        G.call("ui.UIElement", "set_onClick", close, [() -> dismiss()]);

        body = node("options-content", dom, [0], "dpsDeathLogBody");
        var bodyObject = G.field(body, "obj");
        container = prepareChartBody(body);
        var options = G.field(bodyObject, "optionsList");
        wrappers = [bodyObject, options, container];
        for (object in [window, frameBackground, windowContent, header, bodyObject, options, container]) {
            if (object == null) continue;
            padding(object, 0);
            var limit = G.enumeration("h2d.FlowOverflow", "Limit");
            G.call("h2d.Flow", "set_overflow", object, [limit]);
            style(object, "overflow", limit);
        }
        absolute(window, header);
        absolute(window, windowContent);
        absolute(windowContent, bodyObject);
        absolute(bodyObject, options);
        absolute(options, container);

        var fontParent = label(G.field(container, "dom"), "");
        show(fontParent, false);
        var font = G.field(fontParent, "font");
        columns = [
            text(font, container, "Time", 0x8a5f46),
            text(font, container, "HP", 0x8a5f46),
            text(font, container, "Amount", 0x8a5f46),
            text(font, container, "Spell", 0x8a5f46),
            text(font, container, "Source", 0x8a5f46)
        ];
        for (heading in columns) absolute(container, heading);
        var viewRows = shown.rows.length < 1 ? 1 : shown.rows.length > VISIBLE ? VISIBLE : shown.rows.length;
        var viewW = (WIDTH - 32) * 1.0;
        var viewH = viewRows * ROW * 1.0;
        mask = G.create("h2d.Mask", [viewW, viewH, container]);
        try absolute(container, mask) catch (_:Dynamic) {}
        content = G.create("h2d.Object", [mask]);
        var icons:Map<String, Dynamic> = [];
        for (row in shown.rows) {
            var line = G.create("h2d.Object", [content]);
            var amountColor = row.death ? 0x5b4334 : row.heal ? 0x2f7a45 : 0x8d3b32;
            var bitmap = null;
            var icon = iconFor(row.skillId, icons);
            if (icon != null) try {
                bitmap = G.create("h2d.Bitmap", [icon, line]);
                var tile = Math.max(G.number(G.field(icon, "width"), 1), G.number(G.field(icon, "height"), 1));
                G.call("h2d.Object", "setScale", bitmap, [ICON / Math.max(1, tile)]);
            } catch (_:Dynamic) bitmap = null;
            var life = null;
            try life = bar(line, DeathLog.fraction(row.hp, shown.healthScale)) catch (_:Dynamic) {}
            rows.push({
                root: line,
                time: text(font, line, row.timeText, 0x8a5f46),
                bar: life,
                amount: text(font, line, row.amountText, amountColor),
                icon: bitmap,
                spell: text(font, line, row.spell, 0x5b4334),
                source: text(font, line, row.source, row.className != "" ? classColor(row.className) : 0x8d3b32)
            });
            rowCount++;
        }
        // The shape argument is required. Omitting it aborts the whole window.
        try {
            wheel = G.create("h2d.Interactive", [viewW, viewH, container, null]);
            try absolute(container, wheel) catch (_:Dynamic) {}
            G.set(wheel, "onWheel", onWheel);
        } catch (error:Dynamic) {
            wheel = null;
            trace("[DPS Meter] Death log scroll: " + Std.string(error));
        }
        layout();
    }

    function iconFor(id:String, icons:Map<String, Dynamic>):Dynamic {
        if (id == null || id == "") return null;
        if (icons.exists(id)) return icons[id];
        var tile = null;
        try tile = NativeCombatMetadata.skillIcon(id) catch (_:Dynamic) {}
        icons[id] = tile;
        return tile;
    }

    function text(font:Dynamic, parent:Dynamic, value:String, color:Int):Dynamic {
        var label = G.create("h2d.Text", [font, parent]);
        G.call("h2d.Text", "set_text", label, [value]);
        G.call("h2d.Text", "set_textColor", label, [color]);
        G.call("h2d.Text", "set_lineBreak", label, [false]);
        return label;
    }

    function bar(parent:Dynamic, fraction:Float):Dynamic {
        var graphic = G.create("h2d.Graphics", [parent]);
        G.call("h2d.Graphics", "beginFill", graphic, [0xe4d2bc, 1.0]);
        G.call("h2d.Graphics", "drawRect", graphic, [0.0, 0.0, BAR_W, BAR_H]);
        G.call("h2d.Graphics", "endFill", graphic);
        var fill = BAR_W * fraction;
        if (fill > 0.5) {
            G.call("h2d.Graphics", "beginFill", graphic, [0xc23b32, 1.0]);
            G.call("h2d.Graphics", "drawRect", graphic, [0.0, 0.0, fill, BAR_H]);
            G.call("h2d.Graphics", "endFill", graphic);
        }
        return graphic;
    }

    function onWheel(event:Dynamic):Void {
        var dy = G.number(G.field(event, "dy"), G.number(G.field(event, "wheelDelta")));
        if (dy == 0 || content == null) return;
        scroll = Math.max(0, Math.min(maxScroll, scroll + dy * ROW));
        position(content, 0, -scroll);
    }

    function layout():Void {
        var scene = G.field(owner, "s2d");
        var top = localPoint(0, 0);
        var bottom = localPoint(G.number(G.field(scene, "width"), 1920), G.number(G.field(scene, "height"), 1080));
        var w = Std.int(Math.min(WIDTH, bottom.x - top.x - 40));
        var shown = rowCount < 1 ? 1 : rowCount > VISIBLE ? VISIBLE : rowCount;
        var h = Std.int(Math.min(HEADER + COLUMNS + shown * ROW + 16, bottom.y - top.y - 40));
        if (width == w && height == h) return;
        width = w;
        height = h;
        size(window, width, height);
        if (frameBackground != null) { size(frameBackground, width, height); position(frameBackground, 0, 0); }
        size(header, width - 2, HEADER);
        position(header, 0, 0);
        size(close, 36, 36);
        position(close, width - 52, 6);
        G.call("ui.comp.FmtText", "set_maxWidthText", title, [width - 120]);
        position(title, 16, 12);
        var bodyHeight = height - HEADER - 8;
        size(windowContent, width - 16, bodyHeight);
        position(windowContent, 8, HEADER);
        for (object in wrappers) { size(object, width - 16, bodyHeight); position(object, 0, 0); }
        var headings = [TIME_X, BAR_X, AMOUNT_X, SPELL_X, SOURCE_X];
        for (i in 0...columns.length) position(columns[i], headings[i], 8);
        var viewH = shown * ROW;
        if (mask != null) {
            G.set(mask, "width", width - 32);
            G.set(mask, "height", viewH);
            position(mask, 0, COLUMNS);
        }
        if (wheel != null) {
            G.set(wheel, "width", width - 32);
            G.set(wheel, "height", viewH);
            position(wheel, 0, COLUMNS);
        }
        placeRows();
        place(top, bottom);
    }

    function placeRows():Void {
        for (i in 0...rows.length) {
            var row = rows[i];
            position(row.root, 0, i * ROW);
            position(row.time, TIME_X, 2);
            if (row.bar != null) position(row.bar, BAR_X, (ROW - BAR_H) / 2);
            position(row.amount, AMOUNT_X, 2);
            if (row.icon != null) position(row.icon, SPELL_X, (ROW - ICON) / 2);
            position(row.spell, SPELL_X + (row.icon != null ? ICON + 4 : 0), 2);
            position(row.source, SOURCE_X, 2);
        }
        var viewH = (rowCount > VISIBLE ? VISIBLE : rowCount) * ROW;
        maxScroll = Math.max(0, rowCount * ROW - viewH);
        scroll = maxScroll;
        if (content != null) position(content, 0, -scroll);
    }

    function place(top:{x:Float, y:Float}, bottom:{x:Float, y:Float}):Void {
        position(window, top.x + (bottom.x - top.x - width) / 2, top.y + Math.max(24, (bottom.y - top.y - height) / 5));
    }

    function localPoint(x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", root, [point]);
        return {x: G.number(G.field(local, "x")), y: G.number(G.field(local, "y"))};
    }

    public function dispose():Void {
        if (window != null) { var old = window; window = null; G.call("h2d.Object", "remove", old); }
        owner = null; root = null; columns = []; rows = []; wrappers = [];
        frameBackground = null; body = null; container = null;
        header = null; title = null; close = null; windowContent = null;
        mask = null; content = null; wheel = null; report = null;
        rowCount = 0; scroll = 0; maxScroll = 0;
        width = 0; height = 0;
    }
}
