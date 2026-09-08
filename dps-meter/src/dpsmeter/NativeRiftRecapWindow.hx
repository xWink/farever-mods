package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.RiftTracker.RiftRecap;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** One dismissible native window containing both finalized rift charts. */
class NativeRiftRecapWindow {
    public static var constructing:Bool = false;
    var window:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var windowContent:Dynamic;
    var frameBackground:Dynamic;
    var header:Dynamic;
    var title:Dynamic;
    var close:Dynamic;
    var wrappers:Array<Dynamic> = [];
    var sections:Array<Dynamic> = [];
    var width:Int = 0;
    var height:Int = 0;
    var retryAt:Float = 0;

    public function new() {}

    public function update(model:CombatModel, enabled:Bool, active:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (owner != null && owner != ui) dispose();
        if (window != null && G.field(window, "removed") == true) dispose();
        if (!enabled) { model.recaps = []; dispose(); return; }
        if (!active || ui == null) { dispose(); return; }
        if (model.recaps.length > 0 && now >= retryAt) {
            dispose();
            try {
                build(ui, model.recaps[model.recaps.length - 1]);
                model.recaps = [];
            } catch (_:Dynamic) {
                constructing = false; dispose(); retryAt = now + 10;
                return;
            }
        }
        if (window == null) return;
        layout();
        for (section in sections) {
            var chart:NativeDamageChart = section.chart;
            chart.update(section.fight, now);
        }
        alignLabels();
    }

    function build(ui:Dynamic, result:RiftRecap):Void {
        owner = ui;
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (e:Dynamic) { constructing = false; throw e; }
        constructing = false;
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192]);
        // Place the recap above the game UI without pausing or closing menus.
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
        G.set(header, "headText", "Rift Recap");
        title = G.field(header, "headerTitle");
        setText(title, "Rift Recap");
        var left = G.enumeration("h2d.Align", "Left");
        G.call("h2d.Text", "set_textAlign", title, [left]);
        style(title, "text-align", left);
        show(title, true);
        absolute(header, title);
        close = G.field(header, "closeBtn");
        show(close, true);
        absolute(header, close);
        // This HUD is outside BaseUI.windows; remove it directly with the native X.
        G.call("ui.UIElement", "set_onClick", close, [() -> dispose()]);

        var body = node("options-content", dom, [0], "dpsRiftRecapBody");
        var bodyObject = G.field(body, "obj");
        show(G.field(bodyObject, "inputList"), false);
        var options = G.field(bodyObject, "optionsList");
        show(G.field(options, "applyBtn"), false);
        var container = G.field(options, "container");
        for (child in children(container)) show(child, false);
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
        addSection(container, RiftTracker.GATES_PHASE, result.gate, "dpsRiftGate");
        addSection(container, result.boss.phase, result.boss, "dpsRiftBoss");
        layout();
    }

    function addSection(parent:Dynamic, caption:String, fight:Null<Fight>, id:String):Void {
        var panel = node("flow", G.field(parent, "dom"), [], id, "vertical");
        var object = G.field(panel, "obj");
        padding(object, 0);
        flow(panel, "set_verticalSpacing", 0);
        style(object, "vspacing", 0);
        var limit = G.enumeration("h2d.FlowOverflow", "Limit");
        flow(panel, "set_overflow", limit);
        style(object, "overflow", limit);
        absolute(parent, object);
        var heading = node("flow", panel, [], id + "Header", "horizontal");
        var headingObject = G.field(heading, "obj");
        padding(headingObject, 0);
        var name = label(heading, caption);
        var time = label(heading, fight == null ? "" : duration(fight.duration()));
        absolute(headingObject, name);
        absolute(headingObject, time);
        for (text in [name, time]) {
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", text, [left]);
            style(text, "text-align", left);
        }
        var chart = new NativeDamageChart(panel, id + "Rows", "No damage recorded");
        sections.push({obj: object, heading: headingObject, name: name, time: time,
            chart: chart, fight: fight, width: 0});
    }

    function layout():Void {
        var scene = G.field(owner, "s2d");
        var top = localPoint(0, 0);
        var bottom = localPoint(G.number(G.field(scene, "width"), 1920), G.number(G.field(scene, "height"), 1080));
        var w = Std.int(Math.min(980, bottom.x - top.x - 40));
        var columns = w >= 840;
        var h = Std.int(Math.min(columns ? 540 : 680, bottom.y - top.y - 80));
        if (width != w || height != h) {
            width = w; height = h;
            size(window, width, height);
            if (frameBackground != null) { size(frameBackground, width, height); position(frameBackground, 0, 0); }
            size(header, width - 2, 60);
            position(header, 0, 0);
            size(close, 36, 36);
            position(close, width - 52, 12);
            G.call("ui.comp.FmtText", "set_maxWidthText", title, [width - 112]);
            var bodyHeight = height - 68;
            size(windowContent, width - 16, bodyHeight);
            position(windowContent, 8, 60);
            for (object in wrappers) { size(object, width - 16, bodyHeight); position(object, 0, 0); }
            var panelWidth = columns ? Std.int((width - 72) / 2) : width - 48;
            var panelHeight = columns ? bodyHeight - 24 : Std.int((bodyHeight - 48) / 2);
            for (i in 0...sections.length) {
                var section = sections[i];
                section.width = panelWidth;
                size(section.obj, panelWidth, panelHeight);
                position(section.obj, 16 + (columns ? i * (panelWidth + 24) : 0),
                    12 + (columns ? 0 : i * (panelHeight + 24)));
                size(section.heading, panelWidth, 40);
                G.call("ui.comp.FmtText", "set_maxWidthText", section.name,
                    [Std.int(Math.max(1, panelWidth - textWidth(section.time) - 12))]);
                var chart:NativeDamageChart = section.chart;
                chart.resize(panelWidth, panelHeight - 40);
            }
        }
        position(window, top.x + (bottom.x - top.x - width) / 2, top.y + (bottom.y - top.y - height) / 2);
    }

    function alignLabels():Void {
        G.call("ui.comp.FmtText", "updateScale", title);
        position(title, (width - textWidth(title)) / 2, (60 - textHeight(title)) / 2);
        for (section in sections) {
            G.call("ui.comp.FmtText", "updateScale", section.name);
            position(section.name, 0, 4);
            position(section.time, section.width - textWidth(section.time), 4);
        }
    }
    function textWidth(text:Dynamic):Float return G.number(G.call("h2d.Text", "get_textWidth", text)) * G.number(G.field(text, "scaleX"), 1);
    function textHeight(text:Dynamic):Float return G.number(G.call("h2d.Text", "get_textHeight", text)) * G.number(G.field(text, "scaleY"), 1);
    function localPoint(x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", root, [point]);
        return {x: G.number(G.field(local, "x")), y: G.number(G.field(local, "y"))};
    }
    public function dispose():Void {
        if (window != null) { var old = window; window = null; G.call("h2d.Object", "remove", old); }
        owner = null; sections = []; wrappers = []; frameBackground = null;
        width = 0; height = 0;
    }
}
