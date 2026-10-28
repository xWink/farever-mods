package moresettings;

import moresettings.GameAccess as G;
import moresettings.AppearanceUi.*;

/** A normal native window with its own render-to-texture scene and skin draft. */
class AppearanceWindow {
    static inline var WIDTH = 860;
    static inline var HEIGHT = 800;
    static inline var PANEL_X = 372;
    static inline var PANEL_W = 440;
    static inline var PANEL_H = HEIGHT - 240;
    static inline var CONTENT_W = 414;
    static inline var PREVIEW_Y = 14 + (HEIGHT - 750) / 2;
    var ui:Dynamic;
    var draft:AppearanceDraft;
    var window:Dynamic;
    var root:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var controls:Dynamic;
    var viewport:Dynamic;
    var portraits:AppearancePortraits;
    var camera = new AppearanceCamera();
    var title:Dynamic;
    var headingStyle:Dynamic;
    var preview:Dynamic;
    var view:Dynamic;
    var baseHero:Dynamic;
    var models:Array<Dynamic>;
    var parts:Array<Dynamic>;
    var gradients:Array<Dynamic>;
    var choicePages:Map<String, Int> = [];
    var choiceRows:Map<String, Void->Void> = [];
    var dirtyChoiceRows:Map<String, Bool> = [];
    var resetScroll = true;
    var tab = "Body";
    var tabButtons:Map<String, Dynamic> = [];
    var status:Dynamic;
    var saveButton:Dynamic;
    var initialized = false;
    var ready = false;
    var refreshVisuals = false;
    var finishRefresh = false;
    var refitPreview = true;
    var rebuildControls = true;
    var saveRequested = false;
    var closeRequested = false;

    public function new() {}

    public function open(ui:Dynamic, draft:AppearanceDraft):Void {
        this.ui = ui;
        this.draft = draft;
        if (ui == null) throw "The appearance window is unavailable right now.";
        var unit = G.current("Data", "unit");
        baseHero = G.call("haxe.ds.StringMap", "get", G.field(unit, "byId"), ["BaseHero"]);
        models = G.array(G.field(baseHero, "models"));
        if (models.length < 3) throw "Character customization models are unavailable.";
        parts = G.array(G.field(G.current("Data", "bodyPart"), "all"));
        gradients = G.array(G.field(G.current("Data", "gradient"), "all"));
        window = G.create("ui.win.TitleWindow", ["Options", null]);
        var flags = modui.WindowFlags.resolve(
            ["PreventCloseOther", "FreeCursor", "AutoRegisterLayer", "BlockInputs", "BlockSkills", "NeedLayer"],
            name -> G.enumeration("ui.win.WindowFlags", name));
        if (flags.found > 0) G.call("ui.win.BaseWindow", "set_windowFlags", window, [flags.mask]);
        G.call("ui.win.BaseWindow", "rebuild", window);
        root = G.field(ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        G.call("ui.BaseUI", "displayWindow", ui, [window, null]);
        absolute(root, window); padding(window, 0); size(window, WIDTH, HEIGHT);
        for (child in children(window)) if (G.field(child, "bgMask") != null) {
            absolute(window, child); padding(child, 0); size(child, WIDTH, HEIGHT); position(child, 0, 0);
        }
        var dom = G.field(window, "dom");
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        var content = G.field(dom, "contentRoot");
        if (content == null) throw "The appearance window could not be initialized.";
        var header = G.field(window, "header");
        padding(header, 0); absolute(window, header); size(header, WIDTH - 2, 60); position(header, 0, 0);
        show(G.field(header, "headerTitle"), false);
        var close = G.field(header, "closeBtn");
        show(close, true); absolute(header, close); size(close, 36, 36); position(close, WIDTH - 52, 12);
        G.call("ui.UIElement", "set_onClick", close, [requestClose]);
        padding(content, 0); absolute(window, content); size(content, WIDTH - 16, HEIGHT - 68); position(content, 8, 60);
        body = node("options-content", dom, [0], "moreSettingsAppearanceBody");
        var bodyObject = G.field(body, "obj");
        container = prepareBody(body);
        var options = G.field(bodyObject, "optionsList");
        for (object in [bodyObject, options, container]) {
            padding(object, 0); size(object, WIDTH - 16, HEIGHT - 68);
            var limit = G.enumeration("h2d.FlowOverflow", "Limit");
            G.call("h2d.Flow", "set_overflow", object, [limit]); style(object, "overflow", limit);
        }
        absolute(content, bodyObject); position(bodyObject, 0, 0);
        absolute(bodyObject, options); position(options, 0, 0);
        absolute(options, container); position(container, 0, 0);
        var parent = G.field(container, "dom");
        headingStyle = label(parent, "");
        G.call("domkit.Properties", "addClass", G.field(headingStyle, "dom"), ["bold-14"]);
        show(headingStyle, false);
        title = G.create("h2d.Text", [G.field(headingStyle, "font"), header]);
        absolute(header, title);
        G.call("h2d.Text", "set_text", title, ["Change Appearance"]);
        G.call("h2d.Text", "set_textColor", title, [0x8A5F46]);
        G.call("h2d.Text", "set_lineBreak", title, [false]);

        // No game object is passed: even the animation player and gear are private.
        preview = G.field(node("unit-scene", parent, [null, baseHero], "moreSettingsAppearancePreview"), "obj");
        absolute(container, preview); padding(preview, 0); size(preview, 340, 560); position(preview, 12, PREVIEW_Y);
        G.set(preview, "autoFit", true); style(preview, "auto-fit", true);
        G.set(preview, "viewPadding", 0.12); style(preview, "view-padding", 0.12);
        var scene = G.field(preview, "unitScene");
        absolute(preview, scene); padding(scene, 0); size(scene, 340, 560); position(scene, 0, 0);
        textAt(container, "Drag the preview to rotate", 48, Std.int(PREVIEW_Y + 566), 288);
        textAt(container, "Changes apply only when you Save.", 30, Std.int(PREVIEW_Y + 598), 322);
        var names = ["Body", "Hair", "Face"];
        for (i in 0...names.length) {
            var name = names[i];
            var button = buttonAt(container, name, PANEL_X + i * 148, 16, 140, () -> {
                tab = name; rebuildControls = true; resetScroll = true;
            });
            tabButtons[name] = button;
        }
        viewport = G.field(node("block", parent, [], "moreSettingsAppearanceViewport"), "obj");
        absolute(container, viewport); padding(viewport, 0); size(viewport, PANEL_W, PANEL_H); position(viewport, PANEL_X, 70);
        var panelBackground = G.field(viewport, "bgMask");
        absolute(viewport, panelBackground); size(panelBackground, PANEL_W, PANEL_H); position(panelBackground, 0, 0);
        // Block defaults to Stack. With a fixed height, native Stack layout
        // clamps contentHeight before Scroll can detect overflow, disabling
        // both the scrollbar and wheel input even when the list is taller.
        var vertical = G.enumeration("h2d.FlowLayout", "Vertical");
        G.call("h2d.Flow", "set_layout", viewport, [vertical]); style(viewport, "layout", vertical);
        G.call("h2d.Flow", "set_multiline", viewport, [false]); style(viewport, "multiline", false);
        var scroll = G.enumeration("h2d.FlowOverflow", "Scroll");
        G.call("h2d.Flow", "set_overflow", viewport, [scroll]); style(viewport, "overflow", scroll);
        controls = G.field(node("flow", G.field(viewport, "dom"), [], "moreSettingsAppearanceControls"), "obj");
        padding(controls, 0); size(controls, CONTENT_W, PANEL_H);
        // A tall group list must begin at the top, not inherit the native
        // centered alignment that puts its first heading above the clip area.
        var top = G.enumeration("h2d.FlowAlign", "Top");
        var middle = G.enumeration("h2d.FlowAlign", "Middle");
        G.call("h2d.Flow", "set_verticalAlign", viewport, [top]);
        G.call("h2d.Flow", "set_horizontalAlign", viewport, [middle]);
        style(viewport, "content-valign", top);
        style(viewport, "content-halign", middle);
        var contentLayout = G.call("h2d.Flow", "getProperties", viewport, [controls]);
        G.call("h2d.FlowProperties", "set_isAbsolute", contentLayout, [false]); style(controls, "position", false);
        G.set(contentLayout, "verticalAlign", top);
        G.set(contentLayout, "horizontalAlign", middle);
        style(controls, "valign", top);
        // The content column leaves room for the scrollbar. Center that column
        // so the separator text AND both ornaments align with the viewport.
        style(controls, "halign", middle);
        // Native scrollbar styling can offset it beyond this clipped block.
        // Keep the bar inside the right gutter, including after hover/reflow.
        // Flow still owns its visibility, thumb height and scrolling behavior.
        var scrollBar = G.field(viewport, "scrollBar");
        var cursor = G.field(viewport, "scrollBarCursor");
        var right = G.enumeration("h2d.FlowAlign", "Right");
        absolute(viewport, scrollBar); padding(scrollBar, 0);
        size(scrollBar, 10); size(cursor, 10);
        var scrollLayout = G.call("h2d.Flow", "getProperties", viewport, [scrollBar]);
        G.set(scrollLayout, "horizontalAlign", right);
        G.set(scrollLayout, "verticalAlign", top);
        style(scrollBar, "halign", right);
        style(scrollBar, "valign", top);
        G.call("h2d.Object", "addChild", viewport, [scrollBar]);
        status = textAt(container, "Loading character preview...", PANEL_X, HEIGHT - 160, PANEL_W);
        buttonAt(container, "Cancel", PANEL_X + 140, HEIGHT - 118, 140, requestClose, false);
        saveButton = buttonAt(container, "Save", PANEL_X + 292, HEIGHT - 118, 148, save);
    }

    function usable():Bool {
        return ready && !saveRequested && !closeRequested && window != null && G.field(window, "parent") != null && G.field(window, "allocated") == true
            && draft != null && draft.valid(currentHero()) && G.current("ui.BaseUI", "current") == ui;
    }

    function currentHero():Dynamic {
        var controller = G.current("client.PlayerController", "inst");
        return controller == null ? null : G.call("client.PlayerController", "get_hero", controller);
    }

    function guard(action:Void->Void):Void {
        if (!usable()) return;
        try action() catch (error:Dynamic) {
            ready = false;
            setText(status, "Could not update the preview. Close this window and try again.");
            AppearanceEditor.report(error);
        }
    }

    function buttonAt(parent:Dynamic, text:String, x:Int, y:Int, w:Int, action:Void->Void, edit = true):Dynamic {
        var object = G.field(node("button", G.field(parent, "dom"), [text], "moreSettingsAppearanceButton"), "obj");
        absolute(parent, object); padding(object, 0); size(object, w, 36); position(object, x, y);
        G.call("ui.UIElement", "set_onClick", object, [edit ? () -> guard(action) : action]);
        if (edit) G.call("ui.UIElement", "set_checkEnable", object, [usable]);
        return object;
    }

    function textAt(parent:Dynamic, text:String, x:Int, y:Int, w:Int):Dynamic {
        var object = label(G.field(parent, "dom"), text);
        absolute(parent, object); position(object, x, y);
        G.call("ui.comp.FmtText", "set_maxWidthText", object, [w]);
        return object;
    }

    function changed(model = false):Void {
        ready = false;
        if (model) {
            refitPreview = true;
            var index = G.integer(G.field(draft.skin, "template"));
            G.call("client.UnitView", "applyModelInfo", view, [models[index]]);
        }
        refreshVisuals = true;
        rebuildControls = true;
    }

    function groupTitle(value:String, y:Int):Void {
        var heading = G.field(node("separator", G.field(controls, "dom"), [escape(value)],
            "moreSettingsAppearanceGroup"), "obj");
        absolute(controls, heading); size(heading, CONTENT_W, 24); position(heading, 0, y);
    }

    function choices(title:String, key:String, values:Array<Dynamic>, selected:Int, y:Int,
            component:String, choose:Dynamic->Void, body = false):Int {
        groupTitle(title, y);
        var perPage = body ? 3 : 4;
        var width = body ? 122 : 92;
        var gap = 10;
        var pages = Std.int(Math.max(1, Math.ceil(values.length / perPage)));
        var row = G.field(node("flow", G.field(controls, "dom"), [], "moreSettingsAppearanceChoiceRow"), "obj");
        absolute(controls, row); padding(row, 0);
        size(row, CONTENT_W, width + (pages > 1 ? 54 : 24)); position(row, 0, y + 32);
        var render:Void->Void = () -> {
            // Preserve other groups' controls, textures and queued captures.
            portraits.clear(row);
            for (child in children(row)) G.call("h2d.Object", "remove", child);
            var page = choicePages.exists(key) ? choicePages[key] : Std.int(Math.max(0, selected) / perPage);
            page = Std.int(Math.max(0, Math.min(pages - 1, page)));
            var changePage = (next:Int) -> {
                if (next == page) return;
                choicePages[key] = next;
                dirtyChoiceRows[key] = true;
            };
            var startX = Std.int((CONTENT_W - (perPage * width + (perPage - 1) * gap)) / 2);
            for (i in page * perPage...Std.int(Math.min(values.length, (page + 1) * perPage))) {
                var value = values[i];
                portraits.add(row, component, value, startX + (i % perPage) * (width + gap), 0, width,
                    i == selected, usable, () -> guard(() -> { choicePages[key] = page; choose(value); }));
            }
            if (values.length == 0) textAt(row, "Unavailable", 150, 13, 180);
            if (pages > 1) {
                var pageY = 6 + width;
                var previous = buttonAt(row, "<", startX, pageY, 32,
                    () -> changePage((page + pages - 1) % pages));
                var next = buttonAt(row, ">", CONTENT_W - startX - 32, pageY, 32,
                    () -> changePage((page + 1) % pages));
                size(previous, 32, 28); size(next, 32, 28);
                for (i in 0...pages) {
                    var dot = G.field(node("element", G.field(row, "dom"), [], "moreSettingsAppearancePage"), "obj");
                    absolute(row, dot); padding(dot, 0); size(dot, 22, 28);
                    position(dot, (CONTENT_W - pages * 22) / 2 + i * 22, pageY);
                    var graphic = G.create("h2d.Graphics", [dot]);
                    absolute(dot, graphic);
                    G.call("h2d.Graphics", "beginFill", graphic, [i == page ? 0x6F4934 : 0xB9A28C, 1.0]);
                    G.call("h2d.Graphics", "drawCircle", graphic, [11.0, 14.0, i == page ? 4.0 : 3.0, 0]);
                    G.call("h2d.Graphics", "endFill", graphic);
                    G.call("ui.UIElement", "set_onClick", dot, [() -> guard(() -> changePage(i))]);
                }
            }
        };
        choiceRows[key] = render;
        render();
        return y + width + (pages > 1 ? 86 : 56);
    }

    function part(title:String, field:String, type:Int, y:Int):Int {
        var values = AppearanceDraft.parts(parts, type);
        var current = G.text(G.field(draft.skin, field));
        var selected = -1;
        for (i in 0...values.length) if (G.text(G.field(values[i], "id")) == current) selected = i;
        return choices(title, field, values, selected, y, "body-part-pick-button", value -> {
            G.set(draft.skin, field, G.field(value, "id")); changed();
        });
    }

    function shape(category:String, y:Int):Int {
        var values:Array<Dynamic> = [{category: category, name: null}];
        var selected = 0;
        for (value in G.array(G.call("client.UnitView", "getBlendShapes", view))) {
            if (G.call("client.UnitView", "blendShapeHasCategory", view, [value, category]) != true) continue;
            values.push({category: category, name: value});
            if (G.call("client.UnitView", "isBlendShapeActive", view, [value]) == true) selected = values.length - 1;
        }
        return choices(category, category, values, selected, y, "blend-shape-pick-button", value -> {
            var name = G.field(value, "name");
            if (name != null) G.call("client.UnitView", "toggleBlendShape", view, [name, 1.0]);
            else if (G.field(draft.skin, "shapes") != null) G.call("client.UnitView", "removeBlendShape", view, [category]);
            changed();
        });
    }

    function palette(title:String, field:String, mask:Int, y:Int):Int {
        var values = AppearanceDraft.colors(gradients, mask);
        groupTitle(title, y);
        for (i in 0...values.length) {
            var choice = values[i];
            var selected = G.field(choice, "id") == G.field(draft.skin, field);
            var swatch = G.field(node("button", G.field(controls, "dom"), [""], "moreSettingsAppearanceColor"), "obj");
            absolute(controls, swatch); padding(swatch, 0); size(swatch, 34, 34);
            position(swatch, 14 + (i % 9) * 44, y + 32 + Std.int(i / 9) * 42);
            AppearanceSwatches.paint(swatch, choice, selected);
            G.call("ui.UIElement", "set_selected", swatch, [selected]);
            G.call("ui.UIElement", "set_checkEnable", swatch, [usable]);
            G.call("ui.UIElement", "set_onClick", swatch, [() -> guard(() -> {
                G.set(draft.skin, field, G.field(choice, "id"));
                if (field == "hairColor") G.set(draft.skin, "hairColorSecondary", G.field(choice, "id"));
                changed();
            })]);
        }
        return y + 52 + Std.int(Math.ceil(values.length / 9)) * 42;
    }

    function buildControls():Void {
        choiceRows = []; dirtyChoiceRows = [];
        var model = models[G.integer(G.field(draft.skin, "template"))];
        if (portraits == null) portraits = new AppearancePortraits(ui, draft.skin, model);
        else portraits.prepare(draft.skin, model);
        for (child in children(controls)) G.call("h2d.Object", "remove", child);
        for (name => button in tabButtons) G.call("ui.UIElement", "set_selected", button, [name == tab]);
        var y = 8;
        switch tab {
            case "Body":
                y = choices("Body", "template", [0, 1, 2], G.integer(G.field(draft.skin, "template"), -1), y,
                    "template-pick-button", value -> { G.set(draft.skin, "template", value); changed(true); }, true);
                y = palette("Skin Color", "skinColor", 4, y);
            case "Face":
                y = palette("Eye Color", "eyeColor", 2, y);
                y = part("Eyebrows", "eyebrows", 2, y);
                for (category in ["Face", "Eyes", "Lips", "Nose"]) y = shape(category, y);
            case "Hair":
                y = part("Hair Style", "hair", 0, y);
                y = part("Facial Hair", "facialHair", 3, y);
                y = palette("Hair Color", "hairColor", 1, y);
        }
        size(controls, CONTENT_W, Std.int(Math.max(PANEL_H, y)));
        if (resetScroll) G.call("h2d.Flow", "set_scrollPosY", viewport, [0.0]);
        resetScroll = false;
        rebuildControls = false;
    }

    public function update(currentUI:Dynamic, hero:Dynamic):Bool {
        if (closeRequested || window == null || draft == null || ui != currentUI || !draft.valid(hero) || G.field(window, "removed") == true
            || G.field(window, "parent") == null || G.field(window, "allocated") != true || !bodyIntact(body, container)) return false;
        // Native input/update traversal may still hold references to these
        // controls. Commit, tear down GPU previews and rebuild the live model
        // only here, before the next GameApp update/render traversal.
        if (saveRequested) {
            saveRequested = false;
            return commit(hero);
        }
        fitWindow();
        view = G.field(preview, "unitView");
        if (view == null || G.call("client.UnitView", "isReady", view) != true) return true;
        if (!initialized) {
            G.set(view, "overrideSkinData", draft.skin);
            var model = G.integer(G.field(draft.skin, "template"));
            if (model < 0 || model >= models.length) throw "This character's body type is unavailable.";
            G.call("client.UnitView", "applyModelInfo", view, [models[model]]);
            initialized = true; refreshVisuals = true;
            return true;
        }
        if (refreshVisuals) {
            G.call("client.UnitView", "updateDynamicVisuals", view, [null]);
            refreshVisuals = false; finishRefresh = true;
            return true;
        }
        if (finishRefresh) {
            // Only initial loading and body-type changes need new camera bounds
            // and idle setup. Hair, face and color changes keep the current
            // framing instead of restarting the native full-body fit countdown.
            if (refitPreview) {
                var rotation = G.call("h3d.scene.Object", "getRotationQuat", view);
                var postInit:Void->Void = G.field(preview, "postInitUnitView");
                postInit();
                // Live's post-init adds viewAngle again; keep the user's rotation.
                G.call("h3d.scene.Object", "setRotationQuat", view, [rotation]);
                camera.invalidate();
                refitPreview = false;
            }
            finishRefresh = false; ready = true;
            setText(status, "");
        }
        if (ready) {
            if (rebuildControls) buildControls();
            else if (dirtyChoiceRows.iterator().hasNext()) {
                var dirty = dirtyChoiceRows; dirtyChoiceRows = [];
                for (key in dirty.keys()) if (choiceRows.exists(key)) choiceRows[key]();
            }
            portraits.update(draft.skin);
            camera.update(preview, tab != "Body");
        }
        return true;
    }

    function fitWindow():Void {
        var scene = G.field(ui, "s2d");
        var top = point(0, 0), bottom = point(G.number(G.field(scene, "width")), G.number(G.field(scene, "height")));
        var scale = Math.max(0.1, Math.min(1, Math.min((bottom.x - top.x - 32) / WIDTH, (bottom.y - top.y - 32) / HEIGHT)));
        G.call("h2d.Object", "setScale", window, [scale]);
        position(window, top.x + (bottom.x - top.x - WIDTH * scale) / 2, top.y + (bottom.y - top.y - HEIGHT * scale) / 2);
        G.call("ui.comp.FmtText", "updateScale", headingStyle);
        var font = G.field(headingStyle, "font");
        if (font != null && font != G.field(title, "font")) G.call("h2d.Text", "set_font", title, [font]);
        var titleScale = G.number(G.field(headingStyle, "scaleX"), 1) * 1.75;
        G.call("h2d.Object", "setScale", title, [titleScale]);
        position(title, 24, (60 - G.number(G.call("h2d.Text", "get_textHeight", title)) * titleScale) / 2);
    }

    function point(x:Float, y:Float):{x:Float, y:Float} {
        var p = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(p, "x", x); G.set(p, "y", y);
        var result = G.call("h2d.Object", "globalToLocal", root, [p]);
        return {x: G.number(G.field(result, "x")), y: G.number(G.field(result, "y"))};
    }

    function save():Void saveRequested = true;

    function requestClose():Void {
        closeRequested = true;
        saveRequested = false;
    }

    function commit(hero:Dynamic):Bool {
        // Commit errors leave the draft open; after commit, a preview refresh
        // error must never claim that the replicated change was cancelled.
        try draft.commit(hero) catch (error:Dynamic) { AppearanceEditor.report(error); return true; }
        dispose();
        try {
            AppearanceDraft.refreshHero(hero);
        } catch (error:Dynamic) AppearanceEditor.report("Appearance saved, but the character model could not refresh: " + Std.string(error));
        return false;
    }

    public function dispose():Void {
        ready = false;
        saveRequested = false; closeRequested = true;
        var old = window;
        if (old != null) {
            // Detach drawables before releasing textures they reference.
            show(old, false);
            if (ui != null) G.call("ui.BaseUI", "removeWindow", ui, [old]);
        }
        window = null;
        if (portraits != null) { portraits.dispose(); portraits = null; }
        // UnitScene.onRemove disposes its render texture and scene through the
        // native window lifecycle. No restoration of the live hero is needed.
        preview = null; view = null; draft = null; controls = null; container = null; body = null;
        title = null; headingStyle = null; status = null; saveButton = null; root = null; ui = null;
        parts = []; gradients = []; models = []; baseHero = null; tabButtons = []; choicePages = []; viewport = null;
        choiceRows = []; dirtyChoiceRows = [];
    }
}
