package minimap;

import minimap.GameAccess as G;
import minimap.MainMapFilters.MapFilterCategory;

private typedef MapFilterButton = {
    category:MapFilterCategory, object:Dynamic, icon:Dynamic, slash:Dynamic,
    background:Dynamic, tint:Int, radius:Float, ?roundFace:Dynamic, ?squareFace:Dynamic
};

/** Common category buttons and subfilter popups for both map surfaces. */
class MainMapFilterBar {
    static inline var BUTTON_SIZE = 48;
    static inline var BUTTON_STEP = 54;
    static var BAR_HEIGHT(get, never):Int;
    static function get_BAR_HEIGHT():Int return (MainMapFilters.CATEGORIES.length - 1) * BUTTON_STEP + BUTTON_SIZE;
    static inline var POPUP_X = 72;
    static inline var BACKGROUND = 0xFFE9D9BB;
    static inline var NORMAL_TINT = 0xFFFFFFFF;
    static inline var HOVER_TINT = 0xFFDED4C4;
    static inline var PRESSED_TINT = 0xFFC1B39E;
    var container:Dynamic;
    var root:Dynamic;
    var popup:Dynamic;
    var popupCategory:MapFilterCategory;
    var buttons:Array<MapFilterButton> = [];
    var boxes:Array<{key:String, object:Dynamic, ?art:Dynamic, ?selected:Bool, ?hovered:Bool}> = [];
    var nativeButtons = new haxe.ds.ObjectMap<Dynamic, Bool>();
    var nativeSource:Dynamic;
    var filters:MainMapFilters;
    var revision:Int = -1;
    var width:Float = 0;
    var height:Float = 0;
    var bottom:Float = -1;
    var hud:Bool;
    var gear:MapFilterButton;
    var expanded:Bool = false;
    var circular:Bool = false;
    var mapSize:Float = -1;
    var panelX:Float = Math.NaN;
    var panelY:Float = Math.NaN;

    public function new(container:Dynamic, filters:MainMapFilters, createIcon:(Dynamic, String)->Dynamic, hud:Bool = false) {
        this.container = container; this.filters = filters; this.hud = hud;
        try build(createIcon) catch (error:Dynamic) { dispose(); throw error; }
    }

    function build(createIcon:(Dynamic, String)->Dynamic):Void {
        root = node("flow", container, [], "minimapMainFilters");
        for (i in 0...MainMapFilters.CATEGORIES.length) {
            var category = MainMapFilters.CATEGORIES[i];
            var button = node("button", root, [""], "mainMapFilter_" + category.key);
            size(button, BUTTON_SIZE, BUTTON_SIZE); position(button, 0, i * BUTTON_STEP);
            var faces = hud ? makeFaces(button, createIcon) : null;
            G.call("ui.UIElement", "set_onClick", button, [() -> {
                filters.setEnabled(category.key, null, !filters.enabled(category.key));
                refresh();
            }]);
            var hasSubfilters = category.items.length > 0;
            if (hasSubfilters) G.call("ui.UIElement", "set_onRightClick", button, [() -> openPopup(category)]);
            var icon = createIcon(button, category.icon);
            absolute(button, icon); position(icon, BUTTON_SIZE / 2, BUTTON_SIZE / 2);
            G.call("h2d.Object", "setScale", icon, [1.35]);
            var slash = G.create("h2d.Graphics", [button]);
            absolute(button, slash);
            // A light keyline keeps the dark slash legible over every icon.
            for (outline in [true, false]) {
                G.call("h2d.Graphics", "lineStyle", slash, [outline ? 6. : 3., outline ? 0xf8efdf : 0x75453d, 1.]);
                G.call("h2d.Graphics", "moveTo", slash, [11., 37.]);
                G.call("h2d.Graphics", "lineTo", slash, [37., 11.]);
            }
            G.call("h2d.Object", "set_visible", slash, [false]);
            var entry:MapFilterButton = {category:category, object:button, icon:icon, slash:slash, background:null, tint:0, radius:-1};
            if (faces != null) { entry.roundFace = faces.round; entry.squareFace = faces.square; }
            buttons.push(entry);
            G.call("ui.UIElement", "set_onOver", button, [() -> styleButton(entry)]);
            G.call("ui.UIElement", "set_onOut", button, [() -> styleButton(entry)]);
        }
        if (hud) {
            var button = node("button", container, [""], "minimapFilterGear");
            size(button, BUTTON_SIZE, BUTTON_SIZE);
            var faces = makeFaces(button, createIcon);
            var icon = createIcon(button, "settings");
            absolute(button, icon); position(icon, BUTTON_SIZE / 2, BUTTON_SIZE / 2);
            G.call("h2d.Object", "setScale", icon, [1.35]);
            gear = {category:null, object:button, icon:icon, slash:null, background:null, tint:0, radius:-1};
            gear.roundFace = faces.round; gear.squareFace = faces.square;
            G.call("ui.UIElement", "set_selected", button, [true]);
            G.call("ui.UIElement", "set_onClick", button, [() -> {
                expanded = !expanded;
                G.call("h2d.Object", "set_visible", root, [expanded]);
                if (!expanded) closePopup();
                refresh();
            }]);
            G.call("ui.UIElement", "set_onOver", button, [() -> styleButton(gear)]);
            G.call("ui.UIElement", "set_onOut", button, [() -> styleButton(gear)]);
            G.call("h2d.Object", "set_visible", root, [false]);
        }
    }

    public function updateHud(size:Float, round:Bool, screenWidth:Float, screenHeight:Float, x:Float, y:Float):Void {
        if (mapSize != size || circular != round || width != screenWidth || height != screenHeight || panelX != x || panelY != y) {
            mapSize = size; circular = round; width = screenWidth; height = screenHeight; panelX = x; panelY = y;
            var scale = size / (BAR_HEIGHT + BUTTON_STEP);
            G.call("h2d.Object", "setScale", root, [scale]);
            G.call("h2d.Object", "setScale", gear.object, [scale]);
            if (round) {
                var center = size / scale / 2, radius = center + BUTTON_SIZE / 2 + 10;
                var positions = [for (i in 0...buttons.length + 1) {
                    var angle = (230 - 100 * i / buttons.length) * Math.PI / 180;
                    {x:center + Math.cos(angle) * radius - BUTTON_SIZE / 2,
                     y:center + Math.sin(angle) * radius - BUTTON_SIZE / 2};
                }];
                var minX = positions[0].x;
                for (p in positions) minX = Math.min(minX, p.x);
                // Shift the whole arc at the screen edge, preserving its curve.
                var shift = Math.max(0, 4 - panelX - minX * scale);
                position(root, shift, 0);
                position(gear.object, shift + positions[0].x * scale, positions[0].y * scale);
                for (i in 0...buttons.length) position(buttons[i].object, positions[i + 1].x, positions[i + 1].y);
            } else {
                var left = Math.max(4 - panelX, -BUTTON_SIZE * scale - 6);
                position(gear.object, left, 0);
                position(root, left, BUTTON_STEP * scale);
                for (i in 0...buttons.length) position(buttons[i].object, 0, i * BUTTON_STEP);
            }
            placePopup();
        }
        styleButton(gear);
        if (expanded) for (button in buttons) styleButton(button);
        if (revision != filters.revision) refresh();
    }

    public function update(window:Dynamic, w:Float, h:Float, bottomInset:Float = 0):Void {
        var source = G.field(window, "filterButtons");
        if (source != nativeSource) {
            restoreNative(); nativeSource = source;
            for (button in G.array(source)) if (button != null) nativeButtons.set(button, G.field(button, "visible") != false);
        }
        // Native refreshes may run while the window is open.
        for (button in nativeButtons.keys()) if (G.field(button, "visible") != false)
            G.call("ui.UIElement", "set_visible", button, [false]);
        if (width != w || height != h || bottom != bottomInset) {
            width = w; height = h; bottom = bottomInset;
            var availableHeight = Math.max(1, height - bottomInset);
            var scale = Math.max(0.25, Math.min(1, (availableHeight - 24) / BAR_HEIGHT));
            G.call("h2d.Object", "setScale", root, [scale]);
            position(root, 12, Math.max(12, (availableHeight - BAR_HEIGHT * scale) / 2));
            placePopup();
        }
        for (button in buttons) styleButton(button);
        if (revision != filters.revision) refresh();
    }

    function refresh():Void {
        revision = filters.revision;
        for (button in buttons) {
            var on = filters.enabled(button.category.key);
            // Keep the native inset border in both states. The slash alone
            // communicates disabled categories; selection is purely styling.
            G.call("ui.UIElement", "set_selected", button.object, [true]);
            G.call("h2d.Object", "set_visible", button.slash, [!on]);
        }
        if (popupCategory != null) for (box in boxes) {
            var value = filters.enabled(popupCategory.key, box.key);
            if (box.art == null) G.call("ui.comp.CheckBox", "set_selected", box.object, [value]);
            else if (box.selected != value) { box.selected = value; drawCheckRow(box.art, value, box.hovered == true); }
        }
    }

    function styleButton(button:MapFilterButton):Void {
        var background = G.field(button.object, "background");
        if (hud) {
            // HUDs do not inherit MapWindow's button skin. Draw our own cached
            // faces and only retain the native button's input handling.
            if (background != null && G.field(background, "visible") != false)
                G.call("h2d.Object", "set_visible", background, [false]);
            var shape = circular ? 24. : 6.;
            if (button.radius != shape) {
                G.call("h2d.Object", "set_visible", button.roundFace, [circular]);
                G.call("h2d.Object", "set_visible", button.squareFace, [!circular]);
                button.radius = shape;
            }
            var tint = G.field(button.object, "pushed") != null ? PRESSED_TINT
                : G.field(button.object, "hasHover") == true ? HOVER_TINT : NORMAL_TINT;
            if (button.tint != tint) {
                for (face in [button.roundFace, button.squareFace])
                    G.call("h3d.Vector4Impl", "setColor", G.field(face, "color"), [tint]);
                button.tint = tint;
            }
            return;
        }
        if (background == null || G.field(background, "shader") == null) return;
        if (background != button.background) {
            button.background = background;
            button.tint = 0;
            button.radius = -1;
            // Keep the native rounded border and smoothing. Override the
            // background's own color so selected/hover CSS cannot flash white.
            var dom = G.field(background, "dom");
            if (dom != null) G.call("domkit.Properties", "initStyle", dom, ["background", BACKGROUND]);
            G.call("shiro.ui.DynamicBackground", "set_background", background, [BACKGROUND]);
        }
        var tint = G.field(button.object, "pushed") != null ? PRESSED_TINT
            : G.field(button.object, "hasHover") == true ? HOVER_TINT : NORMAL_TINT;
        if (tint != button.tint) {
            G.call("h3d.Vector4Impl", "setColor", G.field(background, "color"), [tint]);
            button.tint = tint;
        }
    }

    function openPopup(category:MapFilterCategory):Void {
        if (category.items.length == 0) return;
        if (popupCategory == category) { closePopup(); return; }
        closePopup();
        try buildPopup(category) catch (error:Dynamic) {
            closePopup();
            trace("[Minimap] Main map filters: " + Std.string(error));
        }
    }

    function buildPopup(category:MapFilterCategory):Void {
        popupCategory = category;
        popup = node("flow", container, [], "mainMapSubfilters");
        var h = 56 + category.items.length * 32;
        size(popup, 286, h);
        var background = G.create("h2d.Graphics", [popup]);
        absolute(popup, background);
        G.call("h2d.Graphics", "beginFill", background, [0x8a5f46, 1.]);
        G.call("h2d.Graphics", "drawRoundedRect", background, [0., 0., 286., h * 1., 8., 16]);
        G.call("h2d.Graphics", "endFill", background);
        G.call("h2d.Graphics", "beginFill", background, [0xeadbc1, 1.]);
        G.call("h2d.Graphics", "drawRoundedRect", background, [2., 2., 282., h - 4., 6., 16]);
        G.call("h2d.Graphics", "endFill", background);
        // Swallow map drag/zoom/right-click inside the panel, even between rows.
        var blocker = G.create("h2d.Interactive", [286., h * 1., popup, null]);
        absolute(popup, blocker);
        G.set(blocker, "enableRightButton", true);
        G.set(blocker, "propagateEvents", false);
        if (hud) { buildHudPopup(category); placePopup(); return; }
        var heading = node("text", popup, [category.label], "mainMapFilterTitle");
        position(heading, 14, 12);
        G.call("domkit.Properties", "addClass", G.field(heading, "dom"), ["bold-16"]);
        G.call("h2d.Text", "set_textColor", heading, [0x5b4334]);
        var close = node("button", popup, [""], "mainMapFilterClose");
        size(close, 28, 28); position(close, 246, 8);
        // A centered vector cross does not depend on the button font's bearings
        // or the native label flow's baseline/padding.
        var cross = G.create("h2d.Graphics", [close]);
        absolute(close, cross); position(cross, 14, 14);
        G.call("h2d.Graphics", "lineStyle", cross, [2., 0xfff3e1, 1.]);
        for (direction in [-1., 1.]) {
            G.call("h2d.Graphics", "moveTo", cross, [-5., -5. * direction]);
            G.call("h2d.Graphics", "lineTo", cross, [5., 5. * direction]);
        }
        G.call("ui.UIElement", "set_onClick", close, [closePopup]);
        for (i in 0...category.items.length) {
            var item = category.items[i];
            var box = node("check-box", popup, [item.label], "mainMapSubfilter_" + item.key);
            size(box, 260, 28); position(box, 12, 44 + i * 32);
            G.call("domkit.Properties", "initStyle", G.field(box, "dom"), ["padding-left", 8]);
            G.call("h2d.Flow", "set_paddingLeft", box, [8]);
            G.call("ui.comp.CheckBox", "set_selected", box, [filters.enabled(category.key, item.key)]);
            G.set(box, "onValueChange", (value:Bool) -> filters.setEnabled(category.key, item.key, value));
            boxes.push({key:item.key, object:box});
        }
        placePopup();
    }

    function buildHudPopup(category:MapFilterCategory):Void {
        var font = MapFonts.find(G.field(G.current("ui.BaseUI", "current"), "gameRoot"), 6);
        if (font == null) font = G.staticCall("hxd.res.DefaultFont", "get", []);
        var textScale = 16 / Math.max(1, G.number(G.field(font, "size"), 16));
        var label = (caption:String, x:Float, y:Float) -> {
            var text = G.create("h2d.Text", [font, popup]);
            absolute(popup, text);
            G.call("h2d.Text", "set_text", text, [caption]);
            G.call("h2d.Text", "set_textColor", text, [0x503a2d]);
            G.call("h2d.Object", "setScale", text, [textScale]);
            position(text, x, y);
        };
        label(category.label, 14, 14);
        var closeArt = G.create("h2d.Graphics", [popup]);
        absolute(popup, closeArt); position(closeArt, 246, 8);
        G.call("h2d.Graphics", "beginFill", closeArt, [0x89644b, 1.]);
        G.call("h2d.Graphics", "drawRoundedRect", closeArt, [0., 0., 28., 28., 5., 16]);
        G.call("h2d.Graphics", "endFill", closeArt);
        G.call("h2d.Graphics", "lineStyle", closeArt, [2., 0xfff3e1, 1.]);
        for (direction in [-1., 1.]) {
            G.call("h2d.Graphics", "moveTo", closeArt, [9., 14. - 5 * direction]);
            G.call("h2d.Graphics", "lineTo", closeArt, [19., 14. + 5 * direction]);
        }
        var close = hudInput(28, 28, 246, 8);
        G.set(close, "onClick", (_:Dynamic) -> closePopup());
        for (i in 0...category.items.length) {
            var item = category.items[i], y = 44 + i * 32;
            var art = G.create("h2d.Graphics", [popup]);
            absolute(popup, art); position(art, 12, y);
            label(item.label, 48, y + 5);
            var input = hudInput(260, 28, 12, y);
            var box = {key:item.key, object:input, art:art, selected:filters.enabled(category.key, item.key), hovered:false};
            boxes.push(box); drawCheckRow(art, box.selected, false);
            G.set(input, "onClick", (_:Dynamic) -> {
                filters.setEnabled(category.key, item.key, !filters.enabled(category.key, item.key));
                refresh();
            });
            G.set(input, "onOver", (_:Dynamic) -> { box.hovered = true; drawCheckRow(art, box.selected, true); });
            G.set(input, "onOut", (_:Dynamic) -> { box.hovered = false; drawCheckRow(art, box.selected, false); });
        }
    }

    function hudInput(w:Float, h:Float, x:Float, y:Float):Dynamic {
        var input = G.create("h2d.Interactive", [w, h, popup, null]);
        absolute(popup, input); position(input, x, y);
        G.set(input, "propagateEvents", false);
        G.set(input, "enableRightButton", true);
        G.call("h2d.Interactive", "set_cursor", input, [G.current("hxd.Cursor", "Button")]);
        return input;
    }

    static function drawCheckRow(g:Dynamic, selected:Bool, hovered:Bool):Void {
        G.call("h2d.Graphics", "clear", g);
        G.call("h2d.Graphics", "lineStyle", g, [0., 0, 0.]);
        G.call("h2d.Graphics", "beginFill", g, [hovered ? 0xe0ccaa : 0xf3e6ce, 1.]);
        G.call("h2d.Graphics", "drawRoundedRect", g, [0., 0., 260., 28., 4., 12]);
        G.call("h2d.Graphics", "endFill", g);
        G.call("h2d.Graphics", "lineStyle", g, [1.5, 0x89644b, 1.]);
        G.call("h2d.Graphics", "beginFill", g, [selected ? 0x89644b : 0xfff6e5, 1.]);
        G.call("h2d.Graphics", "drawRoundedRect", g, [8., 5., 18., 18., 3., 12]);
        G.call("h2d.Graphics", "endFill", g);
        if (selected) {
            G.call("h2d.Graphics", "lineStyle", g, [2., 0xfff3e1, 1.]);
            G.call("h2d.Graphics", "moveTo", g, [11., 14.]);
            G.call("h2d.Graphics", "lineTo", g, [15., 18.]);
            G.call("h2d.Graphics", "lineTo", g, [23., 10.]);
        }
    }

    function placePopup():Void {
        if (popup == null) return;
        var h = 56 + popupCategory.items.length * 32;
        if (hud) {
            var scale = Math.min(1, Math.min((height - 16) / h, (width - 16) / 286));
            var buttonScale = mapSize / (BAR_HEIGHT + BUTTON_STEP);
            var anchor = buttons[MainMapFilters.CATEGORIES.indexOf(popupCategory)].object;
            var ax = G.number(G.field(root, "x")) + G.number(G.field(anchor, "x")) * buttonScale;
            var ay = G.number(G.field(root, "y")) + G.number(G.field(anchor, "y")) * buttonScale;
            var preferred = ax - 286 * scale - 8;
            if (preferred + panelX < 8) preferred = ax + BUTTON_SIZE * buttonScale + 8;
            G.call("h2d.Object", "setScale", popup, [scale]);
            position(popup, Math.max(8 - panelX, Math.min(preferred, width - panelX - 286 * scale - 8)),
                Math.max(8 - panelY, Math.min(ay, height - panelY - h * scale - 8)));
            return;
        }
        var scale = Math.max(0.25, Math.min(1, Math.min((height - 24) / h, (width - POPUP_X - 12) / 286)));
        G.call("h2d.Object", "setScale", popup, [scale]);
        position(popup, POPUP_X, Math.max(12, Math.min(height - h * scale - 12, G.number(G.field(root, "y")))));
    }

    public function contains(x:Float, y:Float):Bool {
        var s = G.number(G.field(root, "scaleX"), G.number(G.field(root, "scale"), 1));
        var ry = G.number(G.field(root, "y"));
        if (x >= 12 && x <= 12 + BUTTON_SIZE * s && y >= ry && y <= ry + BAR_HEIGHT * s) return true;
        if (popup == null) return false;
        var ps = G.number(G.field(popup, "scaleX"), G.number(G.field(popup, "scale"), 1));
        var py = G.number(G.field(popup, "y"));
        return x >= POPUP_X && x <= POPUP_X + 286 * ps && y >= py && y <= py + (56 + popupCategory.items.length * 32) * ps;
    }

    public function closePopup():Void {
        if (popup != null) G.call("h2d.Object", "remove", popup);
        popup = null; popupCategory = null; boxes = [];
    }
    function restoreNative():Void {
        for (button => visible in nativeButtons) if (G.field(button, "removed") != true)
            G.call("ui.UIElement", "set_visible", button, [visible]);
        nativeButtons.clear(); nativeSource = null;
    }
    public function dispose():Void {
        closePopup(); restoreNative();
        if (root != null) G.call("h2d.Object", "remove", root);
        if (gear != null) G.call("h2d.Object", "remove", gear.object);
        gear = null;
        root = null;
    }

    public static function drawGear(g:Dynamic):Void {
        G.call("h2d.Graphics", "lineStyle", g, [3., 0x5b4334, 1.]);
        for (i in 0...8) {
            var a = i * Math.PI / 4;
            G.call("h2d.Graphics", "moveTo", g, [Math.cos(a) * 6.5, Math.sin(a) * 6.5]);
            G.call("h2d.Graphics", "lineTo", g, [Math.cos(a) * 9.5, Math.sin(a) * 9.5]);
        }
        G.call("h2d.Graphics", "drawCircle", g, [0., 0., 6., 32]);
        G.call("h2d.Graphics", "lineStyle", g, [2., 0x5b4334, 1.]);
        G.call("h2d.Graphics", "drawCircle", g, [0., 0., 2., 24]);
    }

    function makeFaces(button:Dynamic, createIcon:(Dynamic, String)->Dynamic):{round:Dynamic, square:Dynamic} {
        var round = createIcon(button, "filterRound"), square = createIcon(button, "filterSquare");
        for (face in [round, square]) {
            absolute(button, face); position(face, 24, 24);
            G.call("h2d.Object", "setScale", face, [1.5]);
        }
        return {round:round, square:square};
    }

    public static function drawButtonFace(g:Dynamic, round:Bool):Void {
        for (i in 0...3) {
            var radius = 15. - i;
            var color = i == 0 ? 0x89644b : i == 1 ? 0xfff2da : 0xe9d9bb;
            G.call("h2d.Graphics", "beginFill", g, [color, 1.]);
            if (round) G.call("h2d.Graphics", "drawCircle", g, [0., 0., radius, 64]);
            else G.call("h2d.Graphics", "drawRoundedRect", g, [-radius, -radius, radius * 2, radius * 2, 4. - i * 0.5, 16]);
            G.call("h2d.Graphics", "endFill", g);
        }
    }

    static function node(component:String, parent:Dynamic, args:Array<Dynamic>, id:String):Dynamic {
        var dom = G.staticCall("domkit.Properties", "createNew", [component, G.field(parent, "dom"), args, {id:id}]);
        var object = G.field(dom, "obj");
        if (object == null) throw "Could not create main map " + component;
        absolute(parent, object);
        return object;
    }
    static function absolute(parent:Dynamic, child:Dynamic):Void {
        var p = G.call("h2d.Flow", "getProperties", parent, [child]);
        G.call("h2d.FlowProperties", "set_isAbsolute", p, [true]);
        G.set(p, "horizontalAlign", null); G.set(p, "verticalAlign", null);
        G.set(p, "offsetX", 0); G.set(p, "offsetY", 0);
        var dom = G.field(child, "dom");
        if (dom != null) {
            G.call("domkit.Properties", "initStyle", dom, ["position", true]);
            for (key in ["halign", "valign"]) G.call("domkit.Properties", "initStyle", dom, [key, null]);
            for (key in ["offset-x", "offset-y", "padding-left", "padding-right", "padding-top", "padding-bottom"])
                G.call("domkit.Properties", "initStyle", dom, [key, 0]);
        }
    }
    static function size(object:Dynamic, w:Int, h:Int):Void {
        for (name in ["minWidth", "maxWidth"]) G.call("h2d.Flow", "set_" + name, object, [w]);
        for (name in ["minHeight", "maxHeight"]) G.call("h2d.Flow", "set_" + name, object, [h]);
        var dom = G.field(object, "dom");
        for (name in ["width", "min-width", "max-width"]) G.call("domkit.Properties", "initStyle", dom, [name, w]);
        for (name in ["height", "min-height", "max-height"]) G.call("domkit.Properties", "initStyle", dom, [name, h]);
    }
    static function position(object:Dynamic, x:Float, y:Float):Void G.call("h2d.Object", "setPosition", object, [x,y]);
}
