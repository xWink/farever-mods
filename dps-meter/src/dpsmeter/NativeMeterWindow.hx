package dpsmeter;

import dpsmeter.CombatModel;
import dpsmeter.GameAccess as G;

/** Native DOMKit components and game fonts; no ImGui or external overlay window. */
class NativeMeterWindow {
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
    var title:Dynamic;
    var subtitle:Dynamic;
    var footer:Dynamic;
    var modeButton:Dynamic;
    var uploadButton:Dynamic;
    var lockButton:Dynamic;
    var dragSurface:Dynamic;
    var resizeSurface:Dynamic;
    var grip:Dynamic;
    var rows:Array<Dynamic> = [];
    var config:MeterConfig;
    var mode:Int = 0;
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
    public function new(config:MeterConfig) this.config = config;

    public function update(model:CombatModel, writer:RunWriter, active:Bool, now:Float):Void {
        var ui = G.current("ui.BaseUI", "current");
        if (owner != null && owner != ui) dispose();
        if (window != null && G.field(window, "removed") == true) dispose();
        if (!config.visible || !config.enabled || !active || ui == null) {
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
        show(window, true);
        if (width != config.width || height != config.height || headerHeight != measuredHeaderHeight()) layout();
        updateDrag();
        clampToScreen();
        position(window, config.x, config.y);
        if (now - lastRefresh >= 0.20) {
            lastRefresh = now;
            refresh(model, writer, now);
        }
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
        G.set(header, "headText", "DPS Meter");
        title = G.field(header, "headerTitle");
        setText(title, "DPS Meter");
        absolute(header, title);
        var close = G.field(header, "closeBtn");
        if (close != null) absolute(header, close);
        if (close != null) G.call("ui.UIElement", "set_onClick", close, [() -> {
            config.visible = false; config.save(); show(window, false);
        }]);

        toolbar = node("flow", G.field(header, "dom"), [], "dpsMeterToolbar", "horizontal");
        flow(toolbar, "set_horizontalSpacing", 5);
        flow(toolbar, "set_verticalSpacing", 5);
        flow(toolbar, "set_multiline", true);
        modeButton = button(toolbar, "Current", () -> { mode = (mode + 1) % 4; selectedPlayer = ""; lastRefresh = -1; });
        uploadButton = button(toolbar, "Upload: On", () -> { config.sendLogs = !config.sendLogs; config.save(); lastRefresh = -1; });
        lockButton = button(toolbar, "Locked", () -> { config.unlocked = !config.unlocked; config.save(); lastRefresh = -1; });
        var reset = button(toolbar, "Reset", () -> { modelResetRequested = true; selectedPlayer = ""; });
        for (control in [modeButton, uploadButton, lockButton, reset]) padding(control, 6);
        size(modeButton, 88, 34); size(uploadButton, 112, 34); size(lockButton, 100, 34); size(reset, 60, 34);
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
        flow(content, "set_verticalSpacing", 5);
        subtitle = label(content, "Waiting for combat");
        rowsRoot = node("flow", content, [], "dpsMeterRows", "vertical");
        flow(rowsRoot, "set_verticalSpacing", 5);
        flow(rowsRoot, "set_overflow", G.enumeration("h2d.FlowOverflow", "Scroll"));
        footer = label(content, "");
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
    public var modelResetRequested:Bool = false;
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
    function measuredHeaderHeight():Int {
        return 44 + Std.int(Math.max(34, G.integer(G.call("h2d.Flow", "get_outerHeight", G.field(toolbar, "obj"))))) + 6;
    }
    function layout():Void {
        width = config.width; height = config.height;
        var innerWidth = width - 16;
        var toolbarObject = G.field(toolbar, "obj");
        size(toolbarObject, innerWidth - 16);
        headerHeight = measuredHeaderHeight();
        var bodyHeight = height - headerHeight - 8;
        size(window, width, height);
        if (frameBackground != null) { size(frameBackground, width, height); position(frameBackground, 0, 0); }
        size(header, innerWidth, headerHeight);
        position(header, 8, 0);
        G.call("ui.comp.FmtText", "set_maxWidthText", title, [innerWidth - 52]);
        G.call("ui.comp.FmtText", "set_useEllipsis", title, [true]);
        position(title, 8, 6);
        var close = G.field(header, "closeBtn");
        if (close != null) position(close, innerWidth - 32, 4);
        position(toolbarObject, 8, 44);
        size(windowContent, innerWidth, bodyHeight);
        position(windowContent, 8, headerHeight);
        var bodyObject = G.field(body, "obj");
        var options = G.field(bodyObject, "optionsList");
        for (object in [bodyObject, options, container]) { size(object, innerWidth, bodyHeight); position(object, 0, 0); }
        size(G.field(content, "obj"), innerWidth - 16, bodyHeight - 16);
        position(G.field(content, "obj"), 8, 8);
        size(G.field(rowsRoot, "obj"), width - 48, Std.int(Math.max(20, bodyHeight - 70)));
        for (label in [subtitle, footer]) {
            G.call("ui.comp.FmtText", "set_maxWidthText", label, [width - 48]);
            G.call("ui.comp.FmtText", "set_useEllipsis", label, [true]);
        }
        G.set(dragSurface, "width", width - 65.0);
        // This surface covers only the title row, above the clickable toolbar.
        position(dragSurface, 12, 5);
        position(resizeSurface, width - 22, height - 22);
        position(grip, width - 18, height - 18);
        for (row in rows) sizeRow(row);
        lastRefresh = -1;
    }
    function sizeRow(row:Dynamic):Void {
        for (label in [row.name, row.details]) {
            G.call("ui.comp.FmtText", "set_maxWidthText", label, [width - 75]);
            G.call("ui.comp.FmtText", "set_useEllipsis", label, [true]);
        }
        G.call("ui.comp.BaseGauge", "set_barWidth", row.bar, [width - 70]);
        size(row.bar, width - 70, 9);
    }
    function makeRow(index:Int):Dynamic {
        var d = node("element", rowsRoot, [], "dpsMeterRow" + index, "vertical");
        var name = label(d, "");
        var details = label(d, "");
        var barDom = node("base-gauge", d, [], "dpsMeterBar" + index);
        var bar = G.field(barDom, "obj");
        G.call("ui.comp.BaseGauge", "set_barHeight", bar, [7]);
        G.call("ui.comp.BaseGauge", "set_showValues", bar, [false]);
        var obj = G.field(d, "obj");
        var row:Dynamic = {obj: obj, name: name, details: details, bar: bar, uid: ""};
        G.call("ui.UIElement", "set_onClick", obj, [() -> { selectedPlayer = row.uid; lastRefresh = -1; }]);
        sizeRow(row);
        return row;
    }
    function refresh(model:CombatModel, writer:RunWriter, now:Float):Void {
        if (modelResetRequested) {
            modelResetRequested = false;
            model.session = new Fight(now);
        }
        var modes = ["Current", "Last", "Boss", "Session"];
        G.call("ui.comp.Button", "setText", modeButton, [modes[mode]]);
        G.call("ui.comp.Button", "setText", uploadButton, [config.sendLogs ? "Upload: On" : "Upload: Off"]);
        G.call("ui.comp.Button", "setText", lockButton, [config.unlocked ? "Unlocked" : "Locked"]);
        show(dragSurface, config.unlocked);
        show(resizeSurface, config.unlocked); show(grip, config.unlocked);
        var fight:Null<Fight> = switch (mode) {
            case 0: model.boss != null ? model.boss : model.current != null ? model.current : model.lastCombat;
            case 1: model.lastCombat;
            case 2: model.boss != null ? model.boss : model.lastBoss;
            default: model.session;
        };
        var ranked = fight == null ? [] : fight.ranked();
        var seconds = fight == null ? 0.0 : fight.duration(fight == model.current || fight == model.boss ? now : null);
        var total = 0.0;
        for (p in ranked) total += p.damage;
        var caption = fight == null ? "Waiting for combat" : (fight.bossKind != "" ? fight.bossKind : modes[mode])
            + "  ·  " + duration(seconds) + "  ·  " + compact(total) + " damage";
        setText(subtitle, caption);
        var selected = fight == null ? null : fight.players[selectedPlayer];
        var skillIds:Array<String> = [];
        if (selected != null) {
            skillIds = [for (id in selected.skills.keys()) id];
            skillIds.sort((a, b) -> Reflect.compare(selected.skills[b].damage, selected.skills[a].damage));
            setText(subtitle, selected.info.name + "  ·  " + duration(seconds) + "  ·  click a row to return");
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
                label = (i + 1) + ". " + p.info.name + (p.info.isMe ? " (you)" : "")
                    + (p.info.className == "" ? "" : "  ·  " + p.info.className);
                detail = compact(p.damage) + " damage  ·  " + compact(seconds > 0 ? p.damage / seconds : 0)
                    + " DPS  ·  " + Std.int(total > 0 ? p.damage * 100 / total : 0) + "%";
            } else {
                var id = skillIds[i]; var s = selected.skills[id]; row.uid = "";
                amount = s.damage; color = classColor(selected.info.className); label = id;
                detail = compact(s.damage) + " damage  ·  " + s.casts + " casts  ·  " + s.hits + " hits  ·  " + s.crits + " crits";
            }
            setText(row.name, label); setText(row.details, detail);
            G.call("h2d.Text", "set_textColor", row.name, [color]);
            G.set(row.bar, "color", color); G.set(row.bar, "fullColor", color);
            G.call("ui.comp.BaseGauge", "set_max", row.bar, [Math.max(1, selected == null ? total : selected.damage)]);
            G.call("ui.comp.BaseGauge", "set_value", row.bar, [amount]);
        }
        setText(footer, (config.sendLogs ? writer.status : "Upload disabled") + (config.unlocked ? "  ·  drag title / resize corner" : ""));
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
        owner = null; rows = []; selectedPlayer = "";
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
        case "warrior": 0xb34432; case "cleric": 0x9a781c; case "mage": 0x476cb0; case "rogue": 0x537d38; default: 0x5b4334;
    };
    static function compact(n:Float):String {
        return n >= 1000000 ? Std.string(SkillStats.rounded(n / 1000000, 2)) + "M"
            : n >= 1000 ? Std.string(SkillStats.rounded(n / 1000, 1)) + "k" : Std.string(Math.fround(n));
    }
    static function duration(n:Float):String return Std.int(n / 60) + ":" + StringTools.lpad(Std.string(Std.int(n) % 60), "0", 2);
}
