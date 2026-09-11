package dpsmeter;

import dpsmeter.MeterConfig.MeterSettings;
import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;
import dpsmeter.NativeUi.*;

/** Native DOMKit components and game fonts. */
class NativeMeterWindow {
    static inline var HIDE_FADE_SECONDS:Float = 0.4;
    public static var constructing:Bool = false;
    public var window(default, null):Dynamic;
    var owner:Dynamic;
    var root:Dynamic;
    var windowContent:Dynamic;
    var frameBackground:Dynamic;
    var header:Dynamic;
    var toolbar:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var content:Dynamic;
    var chart:NativeDamageChart;
    var timer:Dynamic;
    var bossLabel:Dynamic;
    var bossCaption:String = "";
    var bossLabelWidth:Int = -1;
    var displayed:Null<Fight>;
    var dragSurface:Dynamic;
    var resizeSurface:Dynamic;
    var grip:Dynamic;
    var config:MeterSettings;
    var lastRefresh:Float = -1;
    var width:Int = 0;
    var height:Int = 0;
    var headerHeight:Int = 0;
    var dragging:Bool = false;
    var resizing:Bool = false;
    var startMouseX:Float = 0;
    var startMouseY:Float = 0;
    var startX:Float = 0;
    var startY:Float = 0;
    var startWidth:Int = 0;
    var startHeight:Int = 0;
    var createRetry:Float = 0;
    var outOfCombatSince:Float = -1;
    public function new(config:MeterSettings) this.config = config;

    public function update(model:CombatModel, active:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (owner != null && owner != ui) dispose();
        if (window != null && (G.field(window, "removed") == true
            || !chartBodyIntact(body, container))) dispose();
        // A fresh character or instance has no encounter to show or fade out.
        if (!config.visible || !config.enabled || !active || ui == null
            || (config.hideOutOfCombat && model.displayedFight() == null)) {
            if (window != null) show(window, false);
            outOfCombatSince = -1;
            finishDrag();
            return;
        }
        var opacity:Float = 1;
        // Show the meter when damage starts its timer, not on combat entry alone.
        // One-shot results also get the normal hiding delay before fading.
        if (!config.hideOutOfCombat || model.current != null || model.displayedFight() != displayed) outOfCombatSince = -1;
        else {
            if (outOfCombatSince < 0) outOfCombatSince = now;
            var progress = Math.max(0, Math.min(1, (now - outOfCombatSince - config.hideDelay) / HIDE_FADE_SECONDS));
            opacity = 1 - progress * progress * (3 - 2 * progress);
        }
        if (opacity <= 0) {
            // Invisible windows must also stop receiving mouse input.
            if (window != null) show(window, false);
            finishDrag();
            return;
        }
        if (window == null) {
            if (now < createRetry) return;
            try build(ui) catch (_:Dynamic) {
                constructing = false; dispose(); createRetry = now + 10;
                return;
            }
        }
        G.set(window, "alpha", opacity);
        if (G.field(window, "visible") != true) lastRefresh = -1;
        show(window, true);
        if (width != config.width || height != config.height) layout();
        updateDrag();
        clampToScreen();
        position(window, config.x, config.y);
        if (now - lastRefresh >= 0.20) {
            lastRefresh = now;
            refresh(model, now);
        }
        chart.update(model.displayedFight(), now);
        alignControls();
    }

    function build(ui:Dynamic):Void {
        owner = ui;
        constructing = true;
        try window = G.create("ui.win.TitleWindow", ["Options", null])
        catch (e:Dynamic) { constructing = false; throw e; }
        constructing = false;
        if (window == null) throw "TitleWindow construction returned null";
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [8192]);
        // Keep this persistent HUD out of BaseUI.windows: it must not pause the
        // game, consume skill input, or close inventory/Options when it appears.
        root = attachBelowGameUi(ui, window);
        var dom = G.field(window, "dom");
        // TitleWindow redirects added content into a separate native flow.
        // Resize that wrapper and the decorative frame along with the window.
        windowContent = G.field(dom, "contentRoot");
        if (windowContent == null || windowContent == window) throw "Native window content wrapper was not found";
        frameBackground = null;
        for (child in children(window)) if (G.field(child, "bgMask") != null) { frameBackground = child; break; }
        if (frameBackground != null) absolute(window, frameBackground);
        var component = G.staticCall("domkit.Component", "get", ["options-window", null]);
        if (component != null) G.set(dom, "component", component);
        header = G.field(window, "header");
        G.set(header, "headText", "");
        show(G.field(header, "headerTitle"), false);
        show(G.field(header, "closeBtn"), false);
        var left = G.enumeration("h2d.Align", "Left");

        toolbar = node("flow", G.field(header, "dom"), [], "dpsMeterToolbar", "horizontal");
        timer = label(toolbar, "0:00");
        absolute(G.field(toolbar, "obj"), timer);
        G.call("h2d.Text", "set_textAlign", timer, [left]);
        style(timer, "text-align", left);
        bossLabel = label(toolbar, "");
        absolute(G.field(toolbar, "obj"), bossLabel);
        G.call("h2d.Text", "set_textAlign", bossLabel, [left]);
        style(bossLabel, "text-align", left);
        G.call("ui.comp.FmtText", "set_useEllipsis", bossLabel, [true]);
        bossLabelWidth = -1;
        absolute(header, G.field(toolbar, "obj"));

        body = node("options-content", dom, [0], "dpsMeterBody");
        var bodyObject = G.field(body, "obj");
        container = prepareChartBody(body);
        var options = G.field(bodyObject, "optionsList");
        var parent = G.field(container, "dom");
        content = node("flow", parent, [], "dpsMeterContent", "vertical");
        flow(content, "set_verticalSpacing", 12);
        style(G.field(content, "obj"), "vspacing", 12);
        chart = new NativeDamageChart(content, "dpsMeterRows");
        for (object in [window, frameBackground, windowContent, header, bodyObject, options, container, G.field(content, "obj"), G.field(toolbar, "obj")]) {
            if (object == null) continue;
            padding(object, 0);
            G.call("h2d.Flow", "set_overflow", object, [G.enumeration("h2d.FlowOverflow", "Limit")]);
            style(object, "overflow", G.enumeration("h2d.FlowOverflow", "Limit"));
        }
        absolute(window, windowContent);
        absolute(window, header);
        absolute(windowContent, bodyObject);
        absolute(bodyObject, options);
        absolute(options, container);
        absolute(container, G.field(content, "obj"));
        grip = G.create("h2d.Graphics", [window]);
        G.call("h2d.Graphics", "beginFill", grip, [0x866342, 1.0]);
        G.call("h2d.Graphics", "moveTo", grip, [0.0, 18.0]);
        G.call("h2d.Graphics", "lineTo", grip, [18.0, 0.0]);
        G.call("h2d.Graphics", "lineTo", grip, [18.0, 18.0]);
        G.call("h2d.Graphics", "endFill", grip);
        absolute(window, grip);
        dragSurface = G.create("h2d.Interactive", [100.0, 46.0, window, null]);
        resizeSurface = G.create("h2d.Interactive", [22.0, 22.0, window, null]);
        absolute(window, dragSurface);
        absolute(window, resizeSurface);
        G.set(dragSurface, "onPush", (event:Dynamic) -> beginDrag(event, false));
        G.set(resizeSurface, "onPush", (event:Dynamic) -> beginDrag(event, true));
        G.set(dragSurface, "cursor", G.enumeration("hxd.Cursor", "Move"));
        G.set(resizeSurface, "cursor", G.enumeration("hxd.Cursor", "ResizeNWSE"));
        width = 0; height = 0;
        layout();
    }
    function alignControls():Void {
        // Measure after native styles apply, keeping the timer against the right
        // edge as the window is resized or the number of digits changes.
        var textWidth = G.number(G.call("h2d.Text", "get_textWidth", timer)) * G.number(G.field(timer, "scaleX"), 1);
        var textHeight = G.number(G.call("h2d.Text", "get_textHeight", timer)) * G.number(G.field(timer, "scaleY"), 1);
        position(timer, width - 32 - textWidth, Math.max(0, (34 - textHeight) / 2));
        var nameInset = 12; // Clear the native circular corner decoration.
        var available = Std.int(Math.max(1, width - 32 - textWidth - 12 - nameInset));
        if (available != bossLabelWidth) {
            bossLabelWidth = available;
            G.call("ui.comp.FmtText", "set_maxWidthText", bossLabel, [available]);
            setText(bossLabel, bossCaption);
            G.call("ui.comp.FmtText", "updateScale", bossLabel);
        }
        var bossHeight = G.number(G.call("h2d.Text", "get_textHeight", bossLabel)) * G.number(G.field(bossLabel, "scaleY"), 1);
        position(bossLabel, nameInset, Math.max(0, (34 - bossHeight) / 2));
    }
    function layout():Void {
        width = config.width; height = config.height;
        var innerWidth = width - 16;
        var toolbarObject = G.field(toolbar, "obj");
        size(toolbarObject, innerWidth - 16, 34);
        headerHeight = 46;
        var bodyHeight = height - headerHeight - 8;
        size(window, width, height);
        if (frameBackground != null) { size(frameBackground, width, height); position(frameBackground, 0, 0); }
        // Keep the background just inside the frame's right edge.
        var headerWidth = width - 2;
        size(header, headerWidth, headerHeight);
        position(header, 0, 0);
        position(toolbarObject, 16, 9);
        G.call("ui.comp.FmtText", "set_maxWidthText", timer, [innerWidth - 62]);
        alignControls();
        size(windowContent, innerWidth, bodyHeight);
        position(windowContent, 8, headerHeight);
        var bodyObject = G.field(body, "obj");
        var options = G.field(bodyObject, "optionsList");
        for (object in [bodyObject, options, container]) { size(object, innerWidth, bodyHeight); position(object, 0, 0); }
        size(G.field(content, "obj"), innerWidth - 16, bodyHeight - 24);
        position(G.field(content, "obj"), 8, 12);
        chart.resize(width - 32, Std.int(Math.max(20, bodyHeight - 24)));
        // With no header buttons, the whole header can be used to drag.
        G.set(dragSurface, "width", headerWidth * 1.0);
        G.set(dragSurface, "height", headerHeight * 1.0);
        position(dragSurface, 0, 0);
        position(resizeSurface, width - 22, height - 22);
        position(grip, width - 18, height - 18);
        lastRefresh = -1;
    }
    function refresh(model:CombatModel, now:Float):Void {
        show(dragSurface, config.unlocked);
        show(resizeSurface, config.unlocked); show(grip, config.unlocked);
        var fight = model.displayedFight();
        displayed = fight;
        // Pair the rows and clock with one encounter. Closed fights retain their
        // frozen duration until a new fight replaces the entire view.
        var elapsed = fight == null ? 0 : fight.duration(now);
        setText(timer, duration(elapsed));
        var bossName = fight == null ? "" : fight.phase != "" ? fight.phase : fight.bossName;
        if (bossName != bossCaption) { bossCaption = bossName; bossLabelWidth = -1; }
        show(bossLabel, bossCaption != "");
    }
    function beginDrag(event:Dynamic, resize:Bool):Void {
        if (!config.unlocked || G.integer(G.field(event, "button")) != 0) return;
        G.set(event, "propagate", false);
        var point = mouse(); startMouseX = point.x; startMouseY = point.y;
        startX = config.x; startY = config.y; startWidth = config.width; startHeight = config.height;
        dragging = !resize; resizing = resize;
        var surface = resize ? resizeSurface : dragSurface;
        G.call("h2d.Interactive", "startDrag", surface, [(e:Dynamic) -> {
            G.set(e, "propagate", false);
            var kind = Type.enumConstructor(G.field(e, "kind"));
            if (kind == "ERelease" || kind == "EReleaseOutside") finishDrag();
        }, () -> finishDrag()]);
    }
    function updateDrag():Void {
        if (!dragging && !resizing) return;
        if (!config.unlocked || G.staticCall("hxd.Key", "isDown", [0]) != true) { finishDrag(); return; }
        var p = mouse();
        if (dragging) { config.x = startX + p.x - startMouseX; config.y = startY + p.y - startMouseY; }
        else {
            config.width = Std.int(Math.max(360, Math.min(1200, startWidth + p.x - startMouseX)));
            config.height = Std.int(Math.max(MeterConfig.MIN_HEIGHT, Math.min(1000, startHeight + p.y - startMouseY)));
            if (config.width != width || config.height != height) layout();
        }
    }
    function mouse():{x:Float, y:Float} {
        // Object-local coordinates handle game UI scaling and resolution changes.
        var scene = G.field(owner, "s2d");
        return localPoint(G.number(G.call("h2d.Scene", "get_mouseX", scene)), G.number(G.call("h2d.Scene", "get_mouseY", scene)));
    }
    function localPoint(x:Float, y:Float):{x:Float, y:Float} {
        var point = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(point, "x", x); G.set(point, "y", y);
        var local = G.call("h2d.Object", "globalToLocal", root, [point]);
        return {x: G.number(G.field(local, "x")), y: G.number(G.field(local, "y"))};
    }
    function clampToScreen():Void {
        var scene = G.field(owner, "s2d");
        var top = localPoint(0, 0);
        var bottom = localPoint(G.number(G.field(scene, "width"), 1920), G.number(G.field(scene, "height"), 1080));
        config.x = Math.max(top.x, Math.min(config.x, Math.max(top.x, bottom.x - width)));
        config.y = Math.max(top.y, Math.min(config.y, Math.max(top.y, bottom.y - height)));
    }
    function finishDrag():Void {
        if (!dragging && !resizing) return;
        var surface = resizing ? resizeSurface : dragSurface;
        dragging = false; resizing = false;
        if (surface != null) G.call("h2d.Interactive", "stopDrag", surface);
        DpsMeterMod.saveConfig();
    }
    public function dispose():Void {
        finishDrag();
        if (window != null) { var old = window; window = null; G.call("h2d.Object", "remove", old); }
        owner = null; chart = null; displayed = null;
        body = null; container = null; bossCaption = "";
        outOfCombatSince = -1;
    }
}
