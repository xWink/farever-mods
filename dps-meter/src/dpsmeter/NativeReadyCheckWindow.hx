package dpsmeter;

import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;
import dpsmeter.MeterConfig.MeterSettings;

/** A small native party popup. Its header always drags, independent of meter lock. */
class NativeReadyCheckWindow {
    public static var constructing = false;
    static inline var WIDTH = 440;
    static inline var HEADER = 58;
    static inline var ROW = 34;
    static var styledData:Dynamic;
    var config:MeterSettings;
    var state:ReadyCheck;
    var send:String->Void;
    var window:Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var frame:Dynamic;
    var content:Dynamic;
    var header:Dynamic;
    var title:Dynamic;
    var timer:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var wrappers:Array<Dynamic> = [];
    var rows:Array<{name:Dynamic, status:Dynamic}> = [];
    var readyButton:Dynamic;
    var notReadyButton:Dynamic;
    var cancelButton:Dynamic;
    var dragSurface:Dynamic;
    var dragging = false;
    var startX = 0.0;
    var startY = 0.0;
    var startMouseX = 0.0;
    var startMouseY = 0.0;
    var height = 0;
    var leaderButtons = false;

    public function new(config:MeterSettings, state:ReadyCheck, send:String->Void) {
        this.config = config; this.state = state; this.send = send;
    }
    public function update(now:Float, hasHero:Bool):Void {
        if (!state.active || !hasHero) { if (window != null) dispose(); return; }
        var ui = G.current("ui.BaseUI", "current");
        if (ui == null) { dispose(); return; }
        if (window != null && (owner != ui || G.field(window, "removed") == true
            || !chartBodyIntact(body, container) || rows.length != state.members.length
            || leaderButtons != state.isLeader())) dispose();
        if (window == null) build(ui);
        setText(timer, state.secondsLeft(now) + "s");
        for (i in 0...rows.length) {
            var member = state.members[i];
            setText(rows[i].name, member.name);
            var ready = state.isReady(member.uid);
            setText(rows[i].status, ready ? "READY" : "NOT READY");
            G.call("h2d.Text", "set_textColor", rows[i].status, [ready ? 0x526b31 : 0x982c24]);
        }
        updateDrag();
        layout();
    }
    function build(ui:Dynamic):Void {
        owner = ui;
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (error:Dynamic) { constructing = false; throw error; }
        constructing = false;
        // Passive HUD, like the meter: the player's cursor toggle controls
        // mouse visibility and camera capture even while a check is open.
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192]);
        MeterControllerFocus.track(window);
        root = G.field(ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        // Keep it out of BaseUI.windows so it cannot force cursor mode or
        // participate in native menu closing/focus management.
        absolute(root, window);
        var dom = G.field(window, "dom");
        content = G.field(dom, "contentRoot");
        for (child in children(window)) if (G.field(child, "bgMask") != null) { frame = child; absolute(window, frame); break; }
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        header = G.field(window, "header");
        G.set(header, "headText", "Ready Check");
        title = G.field(header, "headerTitle"); setText(title, "Ready Check");
        var left = G.enumeration("h2d.Align", "Left");
        G.call("h2d.Text", "set_textAlign", title, [left]); style(title, "text-align", left);
        G.call("ui.comp.FmtText", "set_maxWidthText", title, [WIDTH - 120]);
        show(title, true); absolute(header, title);
        show(G.field(header, "closeBtn"), false);
        timer = label(G.field(header, "dom"), "30s"); absolute(header, timer);
        dragSurface = G.create("h2d.Interactive", [WIDTH * 1.0, HEADER * 1.0, header, null]);
        absolute(header, dragSurface);
        G.set(dragSurface, "onPush", (event:Dynamic) -> beginDrag(event));
        G.set(dragSurface, "cursor", G.enumeration("hxd.Cursor", "Move"));

        body = node("options-content", dom, [0], "dpsReadyCheckBody");
        var bodyObject = G.field(body, "obj");
        container = prepareChartBody(body);
        var options = G.field(bodyObject, "optionsList");
        wrappers = [bodyObject, options, container];
        for (object in [window, frame, content, header, bodyObject, options, container]) {
            if (object == null) continue;
            padding(object, 0);
            var limit = G.enumeration("h2d.FlowOverflow", "Limit");
            G.call("h2d.Flow", "set_overflow", object, [limit]); style(object, "overflow", limit);
        }
        absolute(window, header); absolute(window, content);
        absolute(content, bodyObject); absolute(bodyObject, options); absolute(options, container);
        var parent = G.field(container, "dom");
        for (member in state.members) {
            var name = label(parent, member.name), status = label(parent, "NOT READY");
            for (text in [name, status]) absolute(container, text);
            G.call("ui.comp.FmtText", "set_useEllipsis", name, [true]);
            G.call("ui.comp.FmtText", "set_maxWidthText", name, [WIDTH - 192]);
            rows.push({name:name, status:status});
        }
        readyButton = button(parent, "Ready", "dpsReadyCheckReady", () -> send("r"));
        notReadyButton = button(parent, "Not Ready", "dpsReadyCheckNotReady", () -> send("nr"));
        leaderButtons = state.isLeader();
        if (leaderButtons) cancelButton = button(parent, "Cancel", "dpsReadyCheckCancel", () -> send("cancelrc"));
        styleButtons(ui);
        for (control in [readyButton, notReadyButton, cancelButton]) if (control != null) {
            // Native buttons reserve substantial horizontal padding. At this
            // compact width it wraps "Not Ready" into a second, clipped line.
            absolute(container, control); padding(control, 0); size(control, 116, 36);
            var text = G.field(control, "btnText");
            G.call("h2d.Text", "set_lineBreak", text, [false]);
            style(text, "line-break", false);
        }
        height = HEADER + rows.length * ROW + 76;
        size(window, WIDTH, height);
        if (frame != null) { size(frame, WIDTH, height); position(frame, 0, 0); }
        size(header, WIDTH - 2, HEADER); position(header, 0, 0);
        size(content, WIDTH - 16, height - HEADER - 8); position(content, 8, HEADER);
        for (object in wrappers) { size(object, WIDTH - 16, height - HEADER - 8); position(object, 0, 0); }
        layout();
    }
    function styleButtons(ui:Dynamic):Void {
        var sheet = G.field(ui, "style"), data = G.field(sheet, "data");
        if (data != styledData) {
            var css = "";
            for (theme in [{name:"ready", color:"#527F40", text:"#FFFFFF"},
                {name:"not-ready", color:"#E8BB4D", text:"#433523"},
                {name:"cancel", color:"#B8443A", text:"#FFFFFF"}]) {
                var selector = "button.dps-ready-check-" + theme.name;
                css += selector + " > #background { background: " + theme.color + "; }"
                    + selector + ":hover > #background { background: darken(" + theme.color + ", 8%); }"
                    + selector + ":active > #background { background: darken(" + theme.color + ", 15%); }"
                    + selector + " > #btnText { color: " + theme.text + "; }";
            }
            var rules = G.call("domkit.CssParser", "parseSheet", G.field(sheet, "cssParser"), [css, "dps-ready-check-actions"]);
            G.call("domkit.CssStyle", "add", sheet, [rules]); styledData = data;
        }
        for (entry in [{button:readyButton, name:"ready"}, {button:notReadyButton, name:"not-ready"},
            {button:cancelButton, name:"cancel"}]) if (entry.button != null)
            G.call("domkit.Properties", "addClass", G.field(entry.button, "dom"), ["dps-ready-check-" + entry.name]);
    }
    function layout():Void {
        align(title, 20, HEADER); align(timer, WIDTH - 66, HEADER);
        for (i in 0...rows.length) {
            align(rows[i].name, 16, ROW, i * ROW + 6);
            align(rows[i].status, WIDTH - 158, ROW, i * ROW + 6);
        }
        var left = leaderButtons ? 24 : 88;
        var y = rows.length * ROW + 24;
        position(readyButton, left, y); position(notReadyButton, left + 128, y);
        if (cancelButton != null) position(cancelButton, left + 256, y);
        var scene = G.field(owner, "s2d");
        var top = localPoint(0, 0);
        var bottom = localPoint(G.number(G.field(scene, "width"), 1920), G.number(G.field(scene, "height"), 1080));
        var x = config.readyCheckX == null ? top.x + (bottom.x - top.x - WIDTH) / 2 : config.readyCheckX;
        var y = config.readyCheckY == null ? top.y + (bottom.y - top.y - height) / 2 : config.readyCheckY;
        position(window, Math.max(top.x, Math.min(x, Math.max(top.x, bottom.x - WIDTH))),
            Math.max(top.y, Math.min(y, Math.max(top.y, bottom.y - height))));
    }
    function align(text:Dynamic, x:Float, lineHeight:Float, top:Float = 0):Void {
        G.call("ui.comp.FmtText", "updateScale", text);
        var h = G.number(G.call("h2d.Text", "get_textHeight", text)) * G.number(G.field(text, "scaleY"), 1);
        position(text, x, top + (lineHeight - h) / 2);
    }
    function beginDrag(event:Dynamic):Void {
        if (G.integer(G.field(event, "button")) != 0) return;
        G.set(event, "propagate", false);
        var point = mouse(); startMouseX = point.x; startMouseY = point.y;
        startX = G.number(G.field(window, "x")); startY = G.number(G.field(window, "y"));
        dragging = true;
        G.call("h2d.Interactive", "startDrag", dragSurface, [(event:Dynamic) -> {
            G.set(event, "propagate", false);
            var kind = Type.enumConstructor(G.field(event, "kind"));
            if (kind == "ERelease" || kind == "EReleaseOutside") finishDrag();
        }, () -> finishDrag()]);
    }
    function updateDrag():Void {
        if (!dragging) return;
        if (G.staticCall("hxd.Key", "isDown", [0]) != true) { finishDrag(); return; }
        var point = mouse();
        config.readyCheckX = startX + point.x - startMouseX;
        config.readyCheckY = startY + point.y - startMouseY;
    }
    function finishDrag():Void {
        if (!dragging) return;
        dragging = false;
        config.readyCheckX = G.number(G.field(window, "x")); config.readyCheckY = G.number(G.field(window, "y"));
        if (dragSurface != null) G.call("h2d.Interactive", "stopDrag", dragSurface);
        DpsMeterMod.saveConfig();
    }
    function mouse():{x:Float, y:Float} {
        var scene = G.field(owner, "s2d");
        return localPoint(G.number(G.call("h2d.Scene", "get_mouseX", scene)), G.number(G.call("h2d.Scene", "get_mouseY", scene)));
    }
    function localPoint(x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", root, [point]);
        return {x:G.number(G.field(local, "x")), y:G.number(G.field(local, "y"))};
    }
    public function dispose():Void {
        finishDrag();
        if (window != null) {
            var old = window; window = null;
            MeterControllerFocus.forget(old);
            G.call("h2d.Object", "remove", old);
        }
        owner = null; root = null; rows = []; wrappers = []; frame = null;
        content = null; header = null; title = null; timer = null; body = null; container = null;
        readyButton = null; notReadyButton = null; cancelButton = null; dragSurface = null;
    }
}
