package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;

/** Native DOMKit components and game fonts; no ImGui or external overlay window. */
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
    var rowsRoot:Dynamic;
    var timer:Dynamic;
    var bossLabel:Dynamic;
    var bossCaption:String = "";
    var bossLabelWidth:Int = -1;
    var displayed:Null<Fight>;
    var lockButton:Dynamic;
    var lockIcon:Dynamic;
    var lockIconUnlocked:Null<Bool>;
    var dragSurface:Dynamic;
    var resizeSurface:Dynamic;
    var grip:Dynamic;
    var rows:Array<Dynamic> = [];
    var config:MeterConfig;
    var selectedPlayer:String = "";
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
    public function new(config:MeterConfig) this.config = config;

    public function update(model:CombatModel, active:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (owner != null && owner != ui) dispose();
        if (window != null && G.field(window, "removed") == true) dispose();
        if (!config.visible || !config.enabled || !active || ui == null) {
            if (window != null) show(window, false);
            outOfCombatSince = -1;
            finishDrag();
            return;
        }
        var opacity:Float = 1;
        // Current exists only during confirmed combat. Re-entry cancels both
        // the delay and the fade, restoring the entire window immediately.
        if (!config.hideOutOfCombat || model.current != null) outOfCombatSince = -1;
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
            try build(ui) catch (e:Dynamic) {
                constructing = false; dispose(); createRetry = now + 10;
                trace("[DpsMeter] Native window could not be created: " + e);
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
        root = G.field(ui, "rootOverlay");
        if (root == null) root = G.field(ui, "root");
        G.call("h2d.Object", "addChild", root, [window]);
        absolute(root, window);
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
        lockButton = button(toolbar, "", () -> { config.unlocked = !config.unlocked; config.save(); lastRefresh = -1; });
        absolute(G.field(toolbar, "obj"), lockButton);
        // Draw with the game's vector renderer, avoiding missing font glyphs/assets.
        lockIcon = G.create("h2d.Graphics", [lockButton]);
        absolute(lockButton, lockIcon);
        position(lockIcon, 7, 6);
        lockIconUnlocked = null;
        padding(lockButton, 6);
        size(lockButton, 34, 34);
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
        show(G.field(bodyObject, "inputList"), false);
        var options = G.field(bodyObject, "optionsList");
        show(G.field(options, "applyBtn"), false);
        container = G.field(options, "container");
        if (container == null) throw "Native Options content container was not found";
        // Preserve OptionsList > Block ancestry, but remove its stock settings rows.
        for (child in children(container)) show(child, false);
        var parent = G.field(container, "dom");
        content = node("flow", parent, [], "dpsMeterContent", "vertical");
        flow(content, "set_verticalSpacing", 12);
        style(G.field(content, "obj"), "vspacing", 12);
        rowsRoot = node("flow", content, [], "dpsMeterRows", "vertical");
        padding(G.field(rowsRoot, "obj"), 0);
        flow(rowsRoot, "set_verticalSpacing", 12);
        style(G.field(rowsRoot, "obj"), "vspacing", 12);
        flow(rowsRoot, "set_overflow", G.enumeration("h2d.FlowOverflow", "Scroll"));
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
        dragSurface = G.create("h2d.Interactive", [100.0, 34.0, window, null]);
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
    function node(component:String, parent:Dynamic, args:Array<Dynamic>, id:String, ?layout:String):Dynamic {
        var attributes:Dynamic = {id: id};
        if (layout != null) Reflect.setField(attributes, "layout", layout);
        var result = G.staticCall("domkit.Properties", "createNew", [component, parent, args, attributes]);
        if (result == null) throw "Could not create " + component;
        return result;
    }
    function label(parent:Dynamic, value:String):Dynamic {
        // DOMKit's native text component supplies the same fonts as Options.
        var d = node("text", parent, [value], "dpsMeterText");
        var obj = G.field(d, "obj");
        G.call("h2d.Text", "set_textColor", obj, [0x5b4334]);
        return obj;
    }
    function button(parent:Dynamic, text:String, click:Void->Void):Dynamic {
        var d = node("button", parent, [text], "dpsMeterButton");
        var obj = G.field(d, "obj");
        G.call("ui.UIElement", "set_onClick", obj, [click]);
        return obj;
    }
    function updateLockIcon():Void {
        if (lockIconUnlocked == config.unlocked) return;
        lockIconUnlocked = config.unlocked;
        G.call("h2d.Graphics", "clear", lockIcon);
        G.call("h2d.Graphics", "lineStyle", lockIcon, [2.0, 0xffffff, 1.0]);
        // The unlocked shackle lifts clear of the right side of the body.
        var top = config.unlocked ? 1.0 : 4.0;
        G.call("h2d.Graphics", "moveTo", lockIcon, [6.0, 11.0]);
        G.call("h2d.Graphics", "lineTo", lockIcon, [6.0, top + 4]);
        G.call("h2d.Graphics", "curveTo", lockIcon, [6.0, top, 10.0, top]);
        G.call("h2d.Graphics", "curveTo", lockIcon, [14.0, top, 14.0, top + 4]);
        G.call("h2d.Graphics", "lineTo", lockIcon, [14.0, config.unlocked ? 7.0 : 11.0]);
        G.call("h2d.Graphics", "drawRect", lockIcon, [3.0, 11.0, 14.0, 10.0]);
        G.call("h2d.Graphics", "moveTo", lockIcon, [10.0, 15.0]);
        G.call("h2d.Graphics", "lineTo", lockIcon, [10.0, 18.0]);
        G.call("ui.UIElement", "set_textTip", lockButton, [config.unlocked
            ? "Unlocked — click to lock the window" : "Locked — click to move and resize the window"]);
    }
    function flow(dom:Dynamic, method:String, value:Dynamic):Void G.call("h2d.Flow", method, G.field(dom, "obj"), [value]);
    function style(object:Dynamic, property:String, value:Dynamic):Void {
        var dom = G.field(object, "dom");
        if (dom != null) G.call("domkit.Properties", "initStyle", dom, [property, value]);
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
        var d = G.field(object, "dom");
        if (d != null) {
            for (property in ["width", "min-width", "max-width"]) G.call("domkit.Properties", "initStyle", d, [property, w]);
            if (h >= 0) for (property in ["height", "min-height", "max-height"]) G.call("domkit.Properties", "initStyle", d, [property, h]);
        }
    }
    function alignControls():Void {
        // Measure after native styles apply, keeping the timer against the right
        // edge as the window is resized or the number of digits changes.
        var textWidth = G.number(G.call("h2d.Text", "get_textWidth", timer)) * G.number(G.field(timer, "scaleX"), 1);
        var textHeight = G.number(G.call("h2d.Text", "get_textHeight", timer)) * G.number(G.field(timer, "scaleY"), 1);
        position(lockButton, 0, 0);
        position(timer, width - 32 - textWidth, Math.max(0, (34 - textHeight) / 2));
        var left = 34 + 12;
        var right = width - 32 - textWidth - 12;
        var available = Std.int(Math.max(1, right - left));
        if (available != bossLabelWidth) {
            bossLabelWidth = available;
            G.call("ui.comp.FmtText", "set_maxWidthText", bossLabel, [available]);
            setText(bossLabel, bossCaption);
            G.call("ui.comp.FmtText", "updateScale", bossLabel);
        }
        var bossWidth = G.number(G.call("h2d.Text", "get_textWidth", bossLabel)) * G.number(G.field(bossLabel, "scaleX"), 1);
        var bossHeight = G.number(G.call("h2d.Text", "get_textHeight", bossLabel)) * G.number(G.field(bossLabel, "scaleY"), 1);
        position(bossLabel, (left + right - bossWidth) / 2, Math.max(0, (34 - bossHeight) / 2));
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
        size(header, innerWidth, headerHeight);
        position(header, 8, 0);
        position(toolbarObject, 8, 6);
        G.call("ui.comp.FmtText", "set_maxWidthText", timer, [innerWidth - 62]);
        alignControls();
        size(windowContent, innerWidth, bodyHeight);
        position(windowContent, 8, headerHeight);
        var bodyObject = G.field(body, "obj");
        var options = G.field(bodyObject, "optionsList");
        for (object in [bodyObject, options, container]) { size(object, innerWidth, bodyHeight); position(object, 0, 0); }
        size(G.field(content, "obj"), innerWidth - 16, bodyHeight - 24);
        position(G.field(content, "obj"), 8, 12);
        size(G.field(rowsRoot, "obj"), width - 32, Std.int(Math.max(20, bodyHeight - 24)));
        // The boss/timer row is also the drag handle. Leave the lock button's
        // full hit area clear so it stays clickable when the window is unlocked.
        G.set(dragSurface, "width", width - 76.0);
        position(dragSurface, 60, 6);
        position(resizeSurface, width - 22, height - 22);
        position(grip, width - 18, height - 18);
        for (row in rows) sizeRow(row);
        lastRefresh = -1;
    }
    function availableRowWidth():Int {
        var list = G.field(rowsRoot, "obj");
        var available = G.integer(G.call("h2d.Flow", "get_innerWidth", list), width - 32);
        var scrollbar = G.field(list, "scrollBar");
        // Use the full body width, reserving room only for a visible scrollbar.
        if (scrollbar != null && G.field(scrollbar, "visible") == true)
            available -= G.integer(G.call("h2d.Flow", "get_outerWidth", scrollbar)) + 4;
        return Std.int(Math.max(1, available));
    }
    function sizeRow(row:Dynamic):Void {
        var rowWidth = availableRowWidth();
        if (row.width != rowWidth) {
            row.width = rowWidth;
            size(row.obj, rowWidth);
            size(row.heading, rowWidth);
            G.call("ui.comp.FmtText", "set_maxWidthText", row.details, [Std.int(Math.max(1, rowWidth - 60))]);
            G.call("ui.comp.FmtText", "set_maxWidthText", row.extra, [rowWidth]);
            G.call("ui.comp.BaseGauge", "set_barWidth", row.bar, [rowWidth]);
            size(row.bar, rowWidth, 9);
        }
        alignRow(row);
    }
    function alignRow(row:Dynamic):Void {
        var rowWidth:Int = row.width;
        // Measure native text, not spaces: numbers keep a common right edge.
        G.call("ui.comp.FmtText", "updateScale", row.details);
        var detailWidth = G.number(G.call("h2d.Text", "get_textWidth", row.details)) * G.number(G.field(row.details, "scaleX"), 1);
        G.call("ui.comp.FmtText", "set_maxWidthText", row.name, [Std.int(Math.max(1, rowWidth - detailWidth - 12))]);
        // Restore the full name when widening a previously ellipsized row.
        setText(row.name, row.caption);
        G.call("ui.comp.FmtText", "updateScale", row.name);
        var lineHeight = 0.0;
        for (text in [row.name, row.details]) lineHeight = Math.max(lineHeight,
            G.number(G.call("h2d.Text", "get_textHeight", text)) * G.number(G.field(text, "scaleY"), 1));
        var h = Std.int(Math.ceil(Math.max(18, lineHeight)));
        if (row.lineHeight != h) { row.lineHeight = h; size(row.heading, rowWidth, h); }
        position(row.name, 0, 0);
        position(row.details, rowWidth - detailWidth, 0);
    }
    function makeRow(index:Int):Dynamic {
        var d = node("element", rowsRoot, [], "dpsMeterRow" + index, "vertical");
        padding(G.field(d, "obj"), 0);
        flow(d, "set_verticalSpacing", 4);
        style(G.field(d, "obj"), "vspacing", 4);
        var heading = node("flow", d, [], "dpsMeterRowHeading" + index, "horizontal");
        var headingObject = G.field(heading, "obj");
        padding(headingObject, 0);
        var name = label(heading, "");
        var details = label(heading, "");
        for (text in [name, details]) {
            absolute(headingObject, text);
            var left = G.enumeration("h2d.Align", "Left");
            G.call("h2d.Text", "set_textAlign", text, [left]);
            style(text, "text-align", left);
        }
        G.call("ui.comp.FmtText", "set_useEllipsis", name, [true]);
        var extra = label(d, "");
        G.call("ui.comp.FmtText", "set_useEllipsis", extra, [true]);
        show(extra, false);
        var barDom = node("base-gauge", d, [], "dpsMeterBar" + index);
        var bar = G.field(barDom, "obj");
        G.call("ui.comp.BaseGauge", "set_barHeight", bar, [7]);
        G.call("ui.comp.BaseGauge", "set_showValues", bar, [false]);
        var obj = G.field(d, "obj");
        var row:Dynamic = {obj: obj, heading: headingObject, name: name, details: details,
            extra: extra, bar: bar, uid: "", caption: "", lineHeight: 0, color: -1, width: 0};
        G.call("ui.UIElement", "set_onClick", obj, [() -> { selectedPlayer = row.uid; lastRefresh = -1; }]);
        sizeRow(row);
        return row;
    }
    function refresh(model:CombatModel, now:Float):Void {
        updateLockIcon();
        show(dragSurface, config.unlocked);
        show(resizeSurface, config.unlocked); show(grip, config.unlocked);
        var fight = model.displayedFight();
        if (fight != displayed) { displayed = fight; selectedPlayer = ""; }
        var ranked = fight == null ? [] : fight.ranked();
        // Pair the rows and clock with one encounter. Closed fights retain their
        // frozen duration until a new fight replaces the entire view.
        var elapsed = fight == null ? 0 : fight.duration(now);
        setText(timer, duration(elapsed));
        var bossName = fight == null ? "" : fight.bossName;
        if (bossName != bossCaption) { bossCaption = bossName; bossLabelWidth = -1; }
        show(bossLabel, bossCaption != "");
        // A single instant hit should not display thousands of times its damage as DPS.
        var seconds = Math.max(1, elapsed);
        var total = 0.0;
        for (p in ranked) total += p.damage;
        var selected = fight == null ? null : fight.players[selectedPlayer];
        var skillIds:Array<String> = [];
        if (selected != null) {
            skillIds = [for (id in selected.skills.keys()) id];
            skillIds.sort((a, b) -> Reflect.compare(selected.skills[b].damage, selected.skills[a].damage));
        }
        var count = selected == null ? ranked.length : skillIds.length;
        while (rows.length < count) rows.push(makeRow(rows.length));
        for (i in 0...rows.length) {
            var row = rows[i]; show(row.obj, i < count);
            if (i >= count) continue;
            var amount:Float; var color:Int; var label:String; var detail:String;
            if (selected == null) {
                var p = ranked[i]; row.uid = p.info.uid; amount = p.damage;
                color = classColor(p.info.className);
                label = (i + 1) + ". " + p.info.name;
                detail = compact(p.damage) + " (" + compact(seconds > 0 ? p.damage / seconds : 0)
                    + ", " + Std.int(total > 0 ? p.damage * 100 / total : 0) + "%)";
            } else {
                var id = skillIds[i]; var s = selected.skills[id]; row.uid = "";
                amount = s.damage; color = classColor(selected.info.className); label = id;
                detail = compact(s.damage) + " damage";
                setText(row.extra, s.casts + " casts  ·  " + s.hits + " hits  ·  " + s.crits + " crits");
            }
            row.caption = label;
            setText(row.details, detail);
            show(row.extra, selected != null);
            sizeRow(row);
            if (row.color != color) {
                row.color = color;
                G.set(row.bar, "color", color); G.set(row.bar, "fullColor", color);
                // Inline styles preserve the class tint through native CSS updates.
                style(row.bar, "color", color); style(row.bar, "full-color", color);
            }
            G.call("ui.comp.BaseGauge", "set_max", row.bar, [Math.max(1, selected == null ? total : selected.damage)]);
            G.call("ui.comp.BaseGauge", "set_value", row.bar, [amount]);
        }
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
            config.height = Std.int(Math.max(220, Math.min(1000, startHeight + p.y - startMouseY)));
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
        config.save();
    }
    public function dispose():Void {
        finishDrag();
        if (window != null) { var old = window; window = null; G.call("h2d.Object", "remove", old); }
        owner = null; rows = []; selectedPlayer = ""; displayed = null;
        outOfCombatSince = -1;
    }
    static function children(object:Dynamic):Array<Dynamic> {
        var count = G.integer(G.call("h2d.Object", "get_numChildren", object));
        return [for (i in 0...count) G.call("h2d.Object", "getChildAt", object, [i])];
    }
    static function absolute(parent:Dynamic, child:Dynamic):Void {
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
    static function position(obj:Dynamic, x:Float, y:Float):Void G.call("h2d.Object", "setPosition", obj, [x, y]);
    static function show(obj:Dynamic, visible:Bool):Void { if (obj != null) G.call("h2d.Object", "set_visible", obj, [visible]); }
    static function setText(obj:Dynamic, value:String):Void { if (obj != null) G.call("ui.comp.FmtText", "set_text", obj, [value]); }
    static function classColor(name:String):Int return switch (name) {
        // Original dinput8.dll palette at RVA 0x139e0, converted COLORREF -> RGB.
        case "warrior": 0xc95846; case "cleric": 0xd9b054; case "mage": 0x62b2c2; case "rogue": 0xa370be; default: 0xa89884;
    };
    static function compact(n:Float):String {
        return n >= 1000000 ? Std.string(SkillStats.rounded(n / 1000000, 2)) + "M"
            : n >= 1000 ? Std.string(SkillStats.rounded(n / 1000, 1)) + "k" : Std.string(Math.fround(n));
    }
    static function duration(n:Float):String return Std.int(n / 60) + ":" + StringTools.lpad(Std.string(Std.int(n) % 60), "0", 2);
}
