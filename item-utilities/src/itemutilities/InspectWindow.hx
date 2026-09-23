package itemutilities;

import itemutilities.InspectAccess as G;
import itemutilities.InspectUi.*;
import itemutilities.InspectMenuContext.InspectTarget;

/** Read-only native item slots. Never constructs InventorySlot or sends item RPCs. */
class InspectWindow {
    var target:InspectTarget;
    var local:Dynamic;
    var window:Dynamic;
    var root:Dynamic;
    var body:Dynamic;
    var container:Dynamic;
    var headingStyle:Dynamic;
    var title:Dynamic;
    var list:Dynamic;
    var status:Dynamic;
    var appearance = false;
    var modeButton:Dynamic;
    var preview:InspectPreview;
    var previewError:Dynamic;
    var previewFailed = false;
    var tooltipFailed = false;
    // Match the character sheet's two equipment columns. Weapons are separate
    // slots, not display category 3 (the unused Defense category).
    static final LEFT_SLOTS = ["Slot_Head", "Slot_Neck", "Slot_Shoulders", "Slot_Chest", "Slot_Back", "Slot_FingerLeft"];
    static final RIGHT_SLOTS = ["Slot_Hands", "Slot_Waist", "Slot_Legs", "Slot_Feet", "Slot_Trinket", "Slot_FingerRight"];
    static final WEAPON_SLOTS = ["Slot_Weapon1", "Slot_OffhandWeapon", "Slot_Weapon2"];
    var slots:Array<String> = LEFT_SLOTS.concat(RIGHT_SLOTS).concat(WEAPON_SLOTS);
    var signature:String;
    var nextRefresh:Float = 0;
    static inline var WIDTH = 1280;
    static inline var HEIGHT = 760;

    public function new() {}

    public function open(target:InspectTarget, local:Dynamic):Void {
        this.target = target;
        this.local = local;
        window = G.create("ui.win.TitleWindow", ["Options", null]);
        var flags = 0;
        for (name in ["PreventCloseOther", "FreeCursor", "AutoRegisterLayer", "BlockInputs", "BlockSkills", "NeedLayer"])
            flags |= 1 << Type.enumIndex(G.enumeration("ui.win.WindowFlags", name));
        G.call("ui.win.BaseWindow", "set_windowFlags", window, [flags]);
        G.call("ui.win.BaseWindow", "rebuild", window);
        root = G.field(target.ui, "root");
        G.call("h2d.Flow", "addChildAt", root, [window, G.call("h2d.Object", "get_numChildren", root)]);
        G.call("ui.BaseUI", "displayWindow", target.ui, [window, null]);
        absolute(root, window); padding(window, 0); size(window, WIDTH, HEIGHT);
        for (child in children(window)) if (G.field(child, "bgMask") != null) {
            absolute(window, child); padding(child, 0); size(child, WIDTH, HEIGHT); position(child, 0, 0);
        }
        var dom = G.field(window, "dom");
        G.set(dom, "component", G.staticCall("domkit.Component", "get", ["options-window", null]));
        var content = G.field(dom, "contentRoot");
        if (content == null) throw "Inspect window content was not initialized";
        var header = G.field(window, "header");
        padding(header, 0); absolute(window, header); size(header, WIDTH - 2, 60); position(header, 0, 0);
        show(G.field(header, "headerTitle"), false);
        var close = G.field(header, "closeBtn");
        show(close, true); absolute(header, close); size(close, 36, 36); position(close, WIDTH - 52, 12);
        G.call("ui.UIElement", "set_onClick", close, [dispose]);
        padding(content, 0); absolute(window, content); size(content, WIDTH - 16, HEIGHT - 68); position(content, 8, 60);

        body = node("options-content", dom, [0], "itemUtilitiesInspectBody");
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
        // Plain Text deliberately avoids interpreting markup in player names.
        title = G.create("h2d.Text", [G.field(headingStyle, "font"), header]);
        absolute(header, title);
        G.call("h2d.Text", "set_text", title, ["Inspecting: " + (target.name == null ? "Player" : target.name)]);
        G.call("h2d.Text", "set_textColor", title, [0x8A5F46]);
        G.call("h2d.Text", "set_textAlign", title, [G.enumeration("h2d.Align", "Left")]);
        G.call("h2d.Text", "set_lineBreak", title, [false]);
        status = label(parent, "This player's equipment is unavailable. Try again when they are nearby.");
        absolute(container, status); position(status, 16, 20); show(status, false);
        G.call("ui.comp.FmtText", "set_maxWidthText", status, [WIDTH - 64]);
        list = node("flow", parent, [], "itemUtilitiesInspectItems", "vertical");
        var listObject = G.field(list, "obj");
        absolute(container, listObject); padding(listObject, 0);
        size(listObject, WIDTH - 48, HEIGHT - 100); position(listObject, 16, 16);
        modeButton = G.field(node("button", parent, ["Appearance"], "itemUtilitiesInspectMode"), "obj");
        absolute(container, modeButton); size(modeButton, 160, 36);
        G.call("ui.UIElement", "set_onClick", modeButton, [toggleAppearance]);
        previewError = label(parent, "Character preview unavailable.");
        absolute(container, previewError); show(previewError, false);
        refresh();
    }

    function toggleAppearance():Void {
        appearance = !appearance;
        G.call("ui.comp.Button", "setText", modeButton, [appearance ? "Character" : "Appearance"]);
        signature = null;
        refresh();
    }

    function refresh():Void {
        var hero = PlayerInspect.remoteHero(local, target.uid);
        var loadout = G.field(hero, "loadout");
        var equipment = G.field(loadout, "equipment");
        var available = hero != null && G.field(hero, "removed") != true
            && equipment != null && G.field(equipment, "content") != null;
        var appearanceInventory = G.field(loadout, "appearance");
        var stylesAvailable = available && appearanceInventory != null && G.field(appearanceInventory, "content") != null;
        var styles:Map<String, Dynamic> = [];
        var items:Array<Dynamic> = [];
        var parts:Array<String> = [available ? "ready" : "unavailable"];
        if (available) for (slot in slots) {
            var item = G.call("st.Equipment", "getSlot", equipment, [slot]);
            items.push(item);
            // Rebuild only when equipment or its displayed state changes.
            parts.push(item == null ? "empty" : [G.uid(item), G.text(G.field(item, "kind")),
                G.text(G.field(item, "level")), G.text(G.field(item, "upgradeLevel")),
                G.text(G.field(item, "infusion"))].join(":"));
        }
        parts.push(stylesAvailable ? "styles-ready" : "styles-unavailable");
        if (stylesAvailable) for (rule in NativeAppearance.rules()) {
            var item = G.call("st.Inventory", "getItem", appearanceInventory, [rule.index]);
            styles.set(rule.slot, item);
            parts.push(rule.slot + ":" + (item == null ? "default" : G.uid(item) + ":" + G.text(G.field(item, "kind"))));
        }
        var visualSignature = parts.join("|");
        var shift = appearance ? 156 : 0;
        position(modeButton, 16 + shift + 380, 16 + 612);
        show(modeButton, available);
        updatePreview(available ? hero : null, visualSignature, 16 + shift + 296, 16 + 44);
        var next = (appearance ? "appearance|" : "equipment|") + visualSignature;
        if (signature == next) return;
        signature = next;
        clearTooltip();
        for (child in children(G.field(list, "obj"))) G.call("h2d.Object", "remove", child);
        show(status, !available || (appearance && !stylesAvailable));
        setText(status, !available ? "This player's equipment is unavailable. Try again when they are nearby."
            : "This player's appearances are not available yet.");
        if (!available) return;
        if (appearance) {
            if (!stylesAvailable) return;
            section("Appearance", shift, 4, 920);
            var left = LEFT_SLOTS.filter(slot -> styles.exists(slot));
            var right = RIGHT_SLOTS.filter(slot -> styles.exists(slot));
            for (i in 0...left.length)
                makeItem(left[i], styles.get(left[i]), i, shift, 96 + i * 116, 280, null, appearanceInventory);
            for (i in 0...right.length)
                makeItem(right[i], styles.get(right[i]), i + left.length, shift + 640, 96 + i * 116, 280, null, appearanceInventory);
            return;
        }
        section("Equipment", 0, 4, 920);
        section("Weapons", 936, 4, 296);
        section("Arsenal", 936, 398, 296);
        // Preserve each column's top-to-bottom order instead of interleaving
        // categories in a row-major list. All six rows fit without scrolling.
        for (i in 0...LEFT_SLOTS.length) {
            makeItem(slots[i], items[i], i, 0, 48 + i * 90, 280);
            var right = i + LEFT_SLOTS.length;
            makeItem(slots[right], items[right], right, 640, 48 + i * 90, 280);
        }
        var weapons = LEFT_SLOTS.length + RIGHT_SLOTS.length;
        for (i in 0...WEAPON_SLOTS.length) {
            var index = weapons + i;
            makeItem(slots[index], items[index], index, 936, i == 2 ? 442 : 48 + i * 140, 296,
                i == 0 ? "Main Hand" : i == 1 ? "Off Hand" : "Secondary Weapon");
        }
    }

    function updatePreview(hero:Dynamic, state:String, x:Int, y:Int):Void {
        if (hero == null || (preview != null && !preview.isFor(hero))) {
            if (preview != null) preview.dispose();
            preview = null;
        }
        show(previewError, hero != null && previewFailed);
        position(previewError, x + 40, y + 250);
        if (hero == null || previewFailed) return;
        try {
            if (preview == null) preview = new InspectPreview(G.field(container, "dom"), hero);
            preview.update(state, x, y);
        } catch (error:Dynamic) {
            if (preview != null) preview.dispose();
            preview = null; previewFailed = true;
            show(previewError, true);
            trace("[Item Utilities] Inspect character preview: " + error);
        }
    }

    function section(name:String, x:Int, y:Int, width:Int):Void {
        var text = label(list, name);
        G.call("domkit.Properties", "addClass", G.field(text, "dom"), ["bold-14"]);
        absolute(G.field(list, "obj"), text); position(text, x, y);
        // A native separator gives the weapon/arsenal groups the same visual
        // hierarchy as the character sheet, without editable inventory controls.
        var line = G.create("h2d.Graphics", [G.field(list, "obj")]);
        absolute(G.field(list, "obj"), line);
        G.call("h2d.Graphics", "beginFill", line, [0xA98C7D, 0.65]);
        G.call("h2d.Graphics", "drawRect", line, [x, y + 28, width, 1]);
        G.call("h2d.Graphics", "endFill", line);
    }

    function makeItem(slot:String, item:Dynamic, index:Int, x:Int, y:Int, width:Int, ?captionText:String, ?appearanceInventory:Dynamic):Void {
        var card = node("flow", list, [], "itemUtilitiesInspectSlot" + index);
        var object = G.field(card, "obj");
        padding(object, 0); size(object, width, 94);
        absolute(G.field(list, "obj"), object); position(object, x, y);
        var name = captionText == null ? G.text(G.staticCall("HText", "equipmentSlot", [slot]), slot) : captionText;
        var caption = label(card, name);
        G.call("domkit.Properties", "addClass", G.field(caption, "dom"), ["bold-14"]);
        absolute(object, caption); position(caption, 78, 14);
        G.call("ui.comp.FmtText", "set_maxWidthText", caption, [width - 90]);
        G.call("ui.comp.FmtText", "set_useEllipsis", caption, [true]);
        var itemName = label(card, item == null ? (appearanceInventory != null ? "Equipped appearance" : "Empty") : "");
        absolute(object, itemName); position(itemName, 78, 40);
        G.call("ui.comp.FmtText", "set_maxWidthText", itemName, [width - 90]);
        G.call("ui.comp.FmtText", "set_useEllipsis", itemName, [false]);
        if (item != null)
            G.call("ui.comp.FmtText", "set_text", itemName, [G.call("st.Item", "getColoredName", item)]);
        var stack:Dynamic = item == null ? null : {count: 1, item: item};
        // ItemSlot supplies the native icon/rarity and actual-item tooltip.
        // Unlike InventorySlot it has no equip, transfer, drag or context actions.
        // AppearanceSlot supplies the game's cosmetic-only tooltip (hide-stats)
        // and default/hidden style icons. Its edit action lives in GearAppearance,
        // which we never construct or bind here.
        var icon = G.field(appearanceInventory == null
            ? node("item-slot", card, [stack, G.field(item, "inf")], "itemUtilitiesInspectIcon" + index)
            : node("appearance-slot", card, [appearanceInventory, slot], "itemUtilitiesInspectIcon" + index), "obj");
        // Our refresh owns replacement so a native appearance-slot rebuild
        // cannot discard the fitted mask and the child button's tooltip.
        if (appearanceInventory != null) G.call("ui.UIElement", "clearBinds", icon);
        absolute(object, icon); position(icon, 2, 12); size(icon, 64, 64);
        var inner = G.field(icon, "innerSlot");
        if (inner != null) size(inner, 64, 64);
        var button = G.field(icon, "button");
        if (button != null) {
            // ItemSlot's native frame includes the filled background, so moving
            // it over the item would hide the artwork as well. Confine artwork
            // to the inside of its bevel; even oversized icons cannot cover it.
            var mask = G.field(button, "parent");
            if (mask != null && inner != null) {
                absolute(inner, mask); position(mask, 3, 3);
                G.set(mask, "width", 58); G.set(mask, "height", 58);
                style(mask, "width", 58); style(mask, "height", 58);
                padding(button, 0); size(button, 58, 58); position(button, 0, 0);
            }
            G.call("ui.UIElement", "set_onClick", button, [null]);
            G.call("ui.UIElement", "set_onRightClick", button, [null]);
            // These setters make the child button interactive. It receives the
            // hover before ItemSlot, so it must share ItemSlot's native getter.
            // That getter uses the actual replicated item (level, affixes, etc.).
            G.call("ui.UIElement", "set_getTip", button, [G.field(icon, "getTip")]);
            G.set(button, "showTipOnOver", true);
            style(button, "show-tip-on-over", true);
        }
    }

    public function update(ui:Dynamic, local:Dynamic):Bool {
        if (window == null || target.ui != ui || this.local != local || local == null
            || G.field(window, "removed") == true || G.field(window, "parent") == null
            || !bodyIntact(body, container)) return false;
        var now = haxe.Timer.stamp();
        if (now >= nextRefresh) { nextRefresh = now + 0.5; refresh(); }
        var scene = G.field(ui, "s2d");
        var top = point(0, 0), bottom = point(G.number(G.field(scene, "width")), G.number(G.field(scene, "height")));
        var scale = Math.max(0.25, Math.min(1, Math.min((bottom.x - top.x - 32) / WIDTH, (bottom.y - top.y - 32) / HEIGHT)));
        G.call("h2d.Object", "setScale", window, [scale]);
        position(window, top.x + (bottom.x - top.x - WIDTH * scale) / 2, top.y + (bottom.y - top.y - HEIGHT * scale) / 2);
        G.call("ui.comp.FmtText", "updateScale", headingStyle);
        var font = G.field(headingStyle, "font");
        if (font != null && font != G.field(title, "font")) G.call("h2d.Text", "set_font", title, [font]);
        var titleScale = Math.min(G.number(G.field(headingStyle, "scaleX"), 1) * 1.75,
            (WIDTH - 92) / Math.max(1, G.number(G.call("h2d.Text", "get_textWidth", title))));
        G.call("h2d.Object", "setScale", title, [titleScale]);
        position(title, 24, (60 - G.number(G.call("h2d.Text", "get_textHeight", title)) * titleScale) / 2);
        return true;
    }
    function ownsTooltip(tip:Dynamic):Bool {
        if (window == null || tip == null) return false;
        var anchor = G.field(tip, "anchor");
        // Also recognize nested tips whose anchor is another Inspect tooltip.
        for (_ in 0...8) {
            if (anchor == null) return false;
            if (anchor == window || G.call("h2d.Object", "contains", window, [anchor]) == true) return true;
            anchor = G.field(anchor, "anchor");
        }
        return false;
    }

    public function fitTooltip(tip:Dynamic):Void {
        if (tooltipFailed) return;
        try {
            if (!ownsTooltip(tip)) return;
            var parent = G.field(tip, "parent");
            var scene = G.call("h2d.Object", "getScene", tip);
            if (parent == null || scene == null) return;
            // getSize() uses layout bounds. getBounds(tip) also includes the
            // comparison's negative offset and its Equipped label above it.
            var bounds = G.call("h2d.Object", "getBounds", tip, [tip, null]);
            var top = point(8, 8, parent);
            var bottom = point(G.number(G.field(scene, "width")) - 8, G.number(G.field(scene, "height")) - 8, parent);
            var fit = InspectTooltipPlacement.fit(G.number(G.field(tip, "x")), G.number(G.field(tip, "y")), {
                xMin: G.number(G.field(bounds, "xMin")), yMin: G.number(G.field(bounds, "yMin")),
                xMax: G.number(G.field(bounds, "xMax")), yMax: G.number(G.field(bounds, "yMax"))
            }, {xMin: top.x, yMin: top.y, xMax: bottom.x, yMax: bottom.y});
            G.call("h2d.Object", "setScale", tip, [fit.scale]);
            position(tip, fit.x, fit.y);
        } catch (error:Dynamic) {
            tooltipFailed = true;
            trace("[Item Utilities] Inspect tooltip positioning: " + error);
        }
    }

    function clearTooltip():Void {
        if (target == null) return;
        var tip = G.field(target.ui, "currentTip");
        if (ownsTooltip(tip)) G.call("ui.BaseUI", "removeTip", target.ui, [null]);
    }

    function point(x:Float, y:Float, ?relative:Dynamic):{x:Float, y:Float} {
        var p = HlxRuntime.allocInstance(HlxRuntime.resolveType("h2d.col.PointImpl"));
        G.set(p, "x", x); G.set(p, "y", y);
        var result = G.call("h2d.Object", "globalToLocal", relative == null ? root : relative, [p]);
        return {x: G.number(G.field(result, "x")), y: G.number(G.field(result, "y"))};
    }
    public function dispose():Void {
        clearTooltip();
        if (preview != null) preview.dispose();
        preview = null;
        var old = window; window = null;
        if (old != null && target != null) G.call("ui.BaseUI", "removeWindow", target.ui, [old]);
        target = null; local = null; root = null; body = null; container = null;
        headingStyle = null; title = null; list = null; status = null; slots = [];
        modeButton = null; previewError = null;
    }
}
