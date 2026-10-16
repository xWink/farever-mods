package minimap;

import minimap.GameAccess as G;
import minimap.MainMapFilters.MapFilterCategory;

private typedef MapFilterButton = {
    category:MapFilterCategory, object:Dynamic, icon:Dynamic, slash:Dynamic,
    background:Dynamic, tint:Int, face:Dynamic
};

/** Native buttons and checkboxes, confined to the map that owns them. */
class MainMapFilterBar {
    static inline var BUTTON_SIZE = 48;
    static inline var BUTTON_STEP = 54;
    static inline var BAR_HEIGHT = 7 * BUTTON_STEP + BUTTON_SIZE;
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
    var boxes:Array<{key:String, object:Dynamic}> = [];
    var nativeButtons = new haxe.ds.ObjectMap<Dynamic, Bool>();
    var nativeSource:Dynamic;
    var filters:MapFilterPreferences;
    var hudParent:Dynamic;
    var round:Bool = false;
    var hudX:Float = Math.NaN;
    var hudY:Float = Math.NaN;
    var hudSize:Int = 0;
    public static inline var HUD_MARGIN = 36;
    static inline var HUD_BUTTON = 32;
    var revision:Int = -1;
    var width:Float = 0;
    var height:Float = 0;
    var bottom:Float = -1;

    public function new(container:Dynamic, filters:MapFilterPreferences, createIcon:(Dynamic, String)->Dynamic, ?hudParent:Dynamic) {
        this.container = container; this.filters = filters; this.hudParent = hudParent;
        try build(createIcon) catch (error:Dynamic) { dispose(); throw error; }
    }

    function build(createIcon:(Dynamic, String)->Dynamic):Void {
        root = node("flow", container, [], "minimapMainFilters");
        if (hudParent != null) G.call("h2d.Object", "addChild", hudParent, [root]);
        for (i in 0...MainMapFilters.CATEGORIES.length) {
            var category = MainMapFilters.CATEGORIES[i];
            var button = node("button", root, [""], "mainMapFilter_" + category.key);
            var buttonSize = hudParent == null ? BUTTON_SIZE : HUD_BUTTON;
            size(button, buttonSize, buttonSize); position(button, 0, i * BUTTON_STEP);
            var face = hudParent == null ? null : G.create("h2d.Graphics", [button]);
            if (face != null) absolute(button, face);
            G.call("ui.UIElement", "set_onClick", button, [() -> {
                filters.setEnabled(category.key, null, !filters.enabled(category.key));
                refresh();
            }]);
            var hasSubfilters = category.items.length > 0;
            if (hasSubfilters) G.call("ui.UIElement", "set_onRightClick", button, [() -> openPopup(category)]);
            var icon = createIcon(button, category.icon);
            absolute(button, icon); position(icon, buttonSize / 2, buttonSize / 2);
            G.call("h2d.Object", "setScale", icon, [hudParent == null ? 1.35 : 1.0]);
            var slash = G.create("h2d.Graphics", [button]);
            absolute(button, slash);
            // A light keyline keeps the dark slash legible over every icon.
            for (outline in [true, false]) {
                G.call("h2d.Graphics", "lineStyle", slash, [outline ? 6. : 3., outline ? 0xf8efdf : 0x75453d, 1.]);
                G.call("h2d.Graphics", "moveTo", slash, [11., 37.]);
                G.call("h2d.Graphics", "lineTo", slash, [37., 11.]);
            }
            G.call("h2d.Object", "set_visible", slash, [false]);
            if (hudParent != null) G.call("h2d.Object", "setScale", slash, [HUD_BUTTON / BUTTON_SIZE]);
            var entry:MapFilterButton = {category:category, object:button, icon:icon, slash:slash, background:null, tint:0, face:face};
            buttons.push(entry);
            G.call("ui.UIElement", "set_onOver", button, [() -> styleButton(entry)]);
            G.call("ui.UIElement", "set_onOut", button, [() -> styleButton(entry)]);
        }
    }

    /** Two banks follow the outside edge, leaving the clock and footer clear. */
    public function updateMinimap(x:Float, y:Float, mapSize:Int, circular:Bool, screenWidth:Float, screenHeight:Float):Void {
        if (hudSize != mapSize || round != circular || width != screenWidth || height != screenHeight || hudX != x || hudY != y) {
            hudSize = mapSize; round = circular; width = screenWidth; height = screenHeight;
            hudX = x; hudY = y;
            for (i in 0...buttons.length) {
                var point = minimapButtonPosition(i, mapSize, circular);
                position(buttons[i].object, point.x, point.y);
                buttons[i].tint = 0;
            }
            placePopup();
        }
        for (button in buttons) styleButton(button);
        if (revision != filters.revision) refresh();
    }

    public static function minimapButtonPosition(index:Int, mapSize:Int, circular:Bool):{x:Float, y:Float} {
        var right = index >= 4, row = index % 4, outer = mapSize + 6;
        var x:Float, y:Float;
        if (circular) {
            var angle = (right ? -40 + row * 80 / 3 : -140 - row * 80 / 3) * Math.PI / 180;
            var radius = outer / 2 + 18;
            x = outer / 2 + Math.cos(angle) * radius;
            y = outer / 2 + Math.sin(angle) * radius;
        } else {
            x = right ? outer + 18 : -18;
            y = outer * (row + 1) / 5;
        }
        return {x:Math.round(x - HUD_BUTTON / 2), y:Math.round(y - HUD_BUTTON / 2)};
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
        if (popupCategory != null) for (box in boxes)
            G.call("ui.comp.CheckBox", "set_selected", box.object, [filters.enabled(popupCategory.key, box.key)]);
    }

    function styleButton(button:MapFilterButton):Void {
        var background = G.field(button.object, "background");
        if (hudParent != null) {
            if (background != null && G.field(background, "visible") != false)
                G.call("h2d.Object", "set_visible", background, [false]);
            var color = G.field(button.object, "pushed") != null ? 0xc5b69a
                : G.field(button.object, "hasHover") == true ? 0xd9c9ad : 0xe9d9bb;
            if (button.tint != color) {
                button.tint = color;
                G.call("h2d.Graphics", "clear", button.face);
                drawFace(button.face, 0, 0x75533e);
                drawFace(button.face, 2, color);
                drawFace(button.face, 4, 0xb89c78);
                drawFace(button.face, 5, color);
            }
            var interactive = G.field(button.object, "interactive");
            if (interactive != null && G.field(interactive, "isEllipse") != round) G.set(interactive, "isEllipse", round);
            return;
        }
        if (background == null || G.field(background, "shader") == null) return;
        if (background != button.background) {
            button.background = background;
            button.tint = 0;
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

    function drawFace(graphics:Dynamic, inset:Float, color:Int):Void {
        G.call("h2d.Graphics", "beginFill", graphics, [color, 1.]);
        if (round) G.call("h2d.Graphics", "drawCircle", graphics, [HUD_BUTTON / 2., HUD_BUTTON / 2., HUD_BUTTON / 2 - inset, 48]);
        else G.call("h2d.Graphics", "drawRoundedRect", graphics, [inset, inset, HUD_BUTTON - inset * 2, HUD_BUTTON - inset * 2, 3., 12]);
        G.call("h2d.Graphics", "endFill", graphics);
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
        if (hudParent != null) G.call("h2d.Object", "addChild", hudParent, [popup]);
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

    function placePopup():Void {
        if (popup == null) return;
        var h = 56 + popupCategory.items.length * 32;
        if (hudParent != null) {
            var scale = Math.max(0.1, Math.min(1, Math.min((height - 16) / h, (width - 16) / 286)));
            G.call("h2d.Object", "setScale", popup, [scale]);
            var x = hudX > width / 2 ? hudX - HUD_MARGIN - 286 * scale - 8 : hudX + hudSize + 6 + HUD_MARGIN + 8;
            position(popup, Math.max(8, Math.min(width - 286 * scale - 8, x)) - hudX,
                Math.max(8, Math.min(height - h * scale - 8, hudY)) - hudY);
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
    public function setVisible(visible:Bool):Void {
        if (root != null) G.call("h2d.Object", "set_visible", root, [visible]);
        if (!visible) closePopup();
    }
    function restoreNative():Void {
        for (button => visible in nativeButtons) if (G.field(button, "removed") != true)
            G.call("ui.UIElement", "set_visible", button, [visible]);
        nativeButtons.clear(); nativeSource = null;
    }
    public function dispose():Void {
        closePopup(); restoreNative();
        if (root != null) G.call("h2d.Object", "remove", root);
        root = null;
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
