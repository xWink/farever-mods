package moresettings;

import moresettings.GameAccess as G;

/** Main weapon and arsenal weapon beside a player nameplate. */
class NameplateWeapons {
    public static var enabled:Bool = true;
    static inline var NAME_GAP = 8.0;
    static inline var GAP = 3.0;
    static var reportedError:Bool = false;
    static var plates:Array<Plate> = [];
    static var activeTip:Null<{ui:Dynamic, tip:Dynamic, anchor:Dynamic}>;

    /** Left is the main weapon, right is the arsenal weapon. Null stays in its column. */
    public static function pair(main:Dynamic, arsenal:Dynamic):Array<Dynamic>
        return [main, arsenal];

    public static function colorForRarity(rarity:String):Int {
        var name = rarity == null ? "" : rarity.toLowerCase();
        if (name.indexOf("legendary") >= 0 || name.indexOf("relic") >= 0) return 0xffb020;
        if (name.indexOf("epic") >= 0) return 0xb44cff;
        if (name.indexOf("rare") >= 0) return 0x4aa3ff;
        return -1;
    }

    static function itemRarityColor(item:Dynamic):Int {
        if (item == null) return -1;
        var rarity = G.text(G.field(item, "rarity"));
        if (rarity == "") rarity = G.text(Reflect.field(item, "rarity"));
        if (rarity == "") {
            var inf = definition(item);
            rarity = G.text(G.field(inf, "rarity"));
            if (rarity == "") rarity = G.text(Reflect.field(inf, "rarity"));
        }
        return colorForRarity(rarity);
    }

    public static function shown(item:Dynamic):Bool
        return definition(item) != null;

    public static function attach(widget:Dynamic):Void {
        if (widget == null) return;
        for (plate in plates) if (plate.widget == widget) return;
        var label = G.field(widget, "heroName");
        if (label == null) return;
        var root = G.create("h2d.Object", [widget]);
        keepOutOfFlow(widget, root);
        plates.push({
            widget: widget,
            label: label,
            root: root,
            slots: [emptySlot(), emptySlot()],
            held: null,
            nextRefresh: 0
        });
        G.call("ui.UIElement", "bindUpdate", widget, [(_dt:Float) -> refresh(widget)]);
    }

    static function refresh(widget:Dynamic):Void {
        try refreshPlate(widget) catch (error:Dynamic) reportError(error);
    }

    static function refreshPlate(widget:Dynamic):Void {
        var plate = find(widget);
        if (plate == null) return;
        if (G.field(widget, "removed") == true) {
            removePlate(plate);
            return;
        }
        if (!enabled) {
            G.call("h2d.Object", "set_visible", plate.root, [false]);
            for (slot in plate.slots) if (slot.icon != null) G.call("h2d.Object", "set_visible", slot.icon, [false]);
            for (slot in plate.slots) if (slot.hit != null) hideTip(slot.hit);
        } else {
            G.call("h2d.Object", "set_visible", plate.root, [true]);
            var hero = G.field(widget, "hero");
            var held = G.field(hero, "weaponInHand");
            var now = haxe.Timer.stamp();
            if (held != plate.held || now >= plate.nextRefresh) {
                plate.held = held;
                plate.nextRefresh = now + 0.25;
                var weapons = pair(mainWeapon(hero), arsenalWeapon(hero));
                for (i in 0...weapons.length) syncSlot(plate, i, weapons[i]);
            }
        }
        layout(plate);
    }

    static function mainWeapon(hero:Dynamic):Dynamic {
        var item = weapon(hero, "get_weapon1");
        if (item == null) item = equipmentSlot(hero, "Slot_Weapon1");
        if (item == null) item = unwrap(G.field(hero, "weaponInHand"));
        return item;
    }

    static function arsenalWeapon(hero:Dynamic):Dynamic {
        var item = weapon(hero, "get_weapon2");
        if (item == null) item = equipmentSlot(hero, "Slot_Weapon2");
        return item;
    }

    static function weapon(hero:Dynamic, name:String):Dynamic {
        if (hero == null) return null;
        try {
            return unwrap(G.call("ent.Hero", name, hero));
        } catch (_:Dynamic) {
            return null;
        }
    }

    static function equipmentSlot(hero:Dynamic, slot:String):Dynamic {
        var equipment = G.field(G.field(hero, "loadout"), "equipment");
        if (equipment == null) return null;
        try {
            return unwrap(G.call("st.Equipment", "getSlot", equipment, [slot]));
        } catch (_:Dynamic) {
            return null;
        }
    }

    static function unwrap(value:Dynamic):Dynamic {
        if (value == null) return null;
        var nested = G.field(value, "item");
        if (nested == null) nested = Reflect.field(value, "item");
        if (nested != null && definition(nested) != null) return nested;
        return definition(value) != null ? value : null;
    }

    static function definition(item:Dynamic):Dynamic {
        if (item == null) return null;
        var inf = G.field(item, "inf");
        if (inf == null) inf = Reflect.field(item, "inf");
        if (inf != null) return inf;
        var kind = G.text(G.field(item, "kind"));
        if (kind == "") kind = G.text(Reflect.field(item, "kind"));
        return kind != "" ? item : null;
    }

    static function syncSlot(plate:Plate, index:Int, item:Dynamic):Void {
        var slot = plate.slots[index];
        if (!shown(item)) {
            slot.item = null;
            if (slot.icon != null) G.call("h2d.Object", "set_visible", slot.icon, [false]);
            if (slot.hit != null) {
                hideTip(slot.hit);
                G.call("h2d.Object", "set_visible", slot.hit, [false]);
            }
            return;
        }
        if (slot.item == item && slot.icon != null) {
            G.call("h2d.Object", "set_visible", slot.icon, [true]);
            if (slot.hit != null) G.call("h2d.Object", "set_visible", slot.hit, [true]);
            return;
        }
        if (slot.icon != null) {
            try G.call("h2d.Object", "remove", slot.icon) catch (_:Dynamic) {}
            slot.icon = null;
        }
        if (slot.hit != null) {
            hideTip(slot.hit);
            try G.call("h2d.Object", "remove", slot.hit) catch (_:Dynamic) {}
            slot.hit = null;
        }
        slot.item = item;
        slot.icon = createBitmap(plate.root, item);
        slot.hit = createHover(plate.root, item);
    }

    static function keepOutOfFlow(widget:Dynamic, child:Dynamic):Void {
        // A normal flow child steals width from the name and shrinks the label.
        try {
            var properties = G.call("h2d.Flow", "getProperties", widget, [child]);
            G.call("h2d.FlowProperties", "set_isAbsolute", properties, [true]);
            G.set(properties, "horizontalAlign", null);
            G.set(properties, "verticalAlign", null);
        } catch (_:Dynamic) {}
    }

    static function createBitmap(parent:Dynamic, item:Dynamic):Dynamic {
        var inf = definition(item);
        var tile = null;
        try {
            tile = G.staticCall("HItem", "getGfx", [inf]);
        } catch (_:Dynamic) {
            tile = null;
        }
        if (tile == null && inf != item) {
            try {
                tile = G.staticCall("HItem", "getGfx", [item]);
            } catch (_:Dynamic) {
                tile = null;
            }
        }
        if (tile == null) return null;
        return G.create("h2d.Bitmap", [tile, parent]);
    }

    static function createHover(parent:Dynamic, item:Dynamic):Dynamic {
        var hit = G.create("h2d.Interactive", [1.0, 1.0, parent, null]);
        G.set(hit, "onOver", function(_:Dynamic) showTip(hit, item));
        G.set(hit, "onOut", function(_:Dynamic) hideTip(hit));
        return hit;
    }

    static function showTip(anchor:Dynamic, item:Dynamic):Void {
        hideTip();
        var ui = G.current("ui.BaseUI", "current");
        if (ui == null) return;
        try {
            var content = G.staticCall("ui.Tooltip", "fromItem", [definition(item), item]);
            if (content == null) return;
            var tip = G.call("ui.BaseUI", "setTip", ui, [content, anchor, null, null]);
            if (tip != null) activeTip = {ui: ui, tip: tip, anchor: anchor};
            else G.call("h2d.Object", "remove", content);
        } catch (error:Dynamic) {
            reportError(error);
        }
    }

    static function hideTip(?anchor:Dynamic):Void {
        if (activeTip == null || (anchor != null && activeTip.anchor != anchor)) return;
        var previous = activeTip;
        activeTip = null;
        try {
            if (G.field(previous.ui, "currentTip") == previous.tip)
                G.call("ui.BaseUI", "removeTip", previous.ui, [null]);
            else if (G.field(previous.tip, "parent") != null)
                G.call("h2d.Object", "remove", previous.tip);
        } catch (_:Dynamic) {}
    }

    static function layout(plate:Plate):Void {
        var label = plate.label;
        var place = labelOffset(plate.label, plate.widget);
        var textWidth = G.number(G.call("h2d.Text", "get_textWidth", label));
        var textHeight = G.number(G.call("h2d.Text", "get_textHeight", label), 14);
        if (textHeight < 10) textHeight = 16;
        var iconSize = textHeight;
        var originX = place.x + textWidth + NAME_GAP;
        var originY = place.y;
        G.call("h2d.Object", "setPosition", plate.root, [originX, originY]);
        var x = 0.0;
        for (slot in plate.slots) {
            var visible = shown(slot.item) && slot.icon != null;
            if (slot.icon != null) {
                G.call("h2d.Object", "set_visible", slot.icon, [visible && enabled]);
                if (visible && enabled) fitIcon(slot.icon, x, iconSize);
            }
            paintRarity(plate, slot, x, iconSize, visible && enabled);
            if (slot.hit != null) {
                G.call("h2d.Object", "set_visible", slot.hit, [visible && enabled]);
                if (visible && enabled) {
                    G.set(slot.hit, "width", iconSize);
                    G.set(slot.hit, "height", iconSize);
                    G.call("h2d.Object", "setPosition", slot.hit, [x, 0.0]);
                }
            }
            if (visible && enabled) x += iconSize + GAP;
        }
    }

    /** Fit the weapon art into the name height. Never scale from a zero-size tile. */
    static function fitIcon(bitmap:Dynamic, x:Float, size:Float):Void {
        var tile = G.field(bitmap, "tile");
        var tileW = G.number(G.field(tile, "width"));
        var tileH = G.number(G.field(tile, "height"));
        if (!(tileW > 1 && tileH > 1)) {
            G.call("h2d.Object", "setScale", bitmap, [0.0]);
            return;
        }
        var scale = size / Math.max(tileW, tileH);
        if (!Math.isFinite(scale) || scale <= 0 || scale > 2) scale = 0;
        G.call("h2d.Object", "setScale", bitmap, [scale]);
        G.call("h2d.Object", "setPosition", bitmap, [x + (size - tileW * scale) / 2, (size - tileH * scale) / 2]);
    }

    static function paintRarity(plate:Plate, slot:WeaponSlot, x:Float, size:Float, visible:Bool):Void {
        var color = visible ? itemRarityColor(slot.item) : -1;
        if (color < 0) {
            if (slot.frame != null) G.call("h2d.Object", "set_visible", slot.frame, [false]);
            return;
        }
        if (slot.frame == null) slot.frame = G.create("h2d.Graphics", [plate.root]);
        G.call("h2d.Object", "set_visible", slot.frame, [true]);
        G.call("h2d.Graphics", "clear", slot.frame);
        var thickness = Math.max(1.0, size * 0.12);
        G.call("h2d.Graphics", "beginFill", slot.frame, [color, 1.0]);
        G.call("h2d.Graphics", "drawRect", slot.frame, [x - thickness, -thickness, size + thickness * 2, thickness]);
        G.call("h2d.Graphics", "drawRect", slot.frame, [x - thickness, size, size + thickness * 2, thickness]);
        G.call("h2d.Graphics", "drawRect", slot.frame, [x - thickness, 0.0, thickness, size]);
        G.call("h2d.Graphics", "drawRect", slot.frame, [x + size, 0.0, thickness, size]);
        G.call("h2d.Graphics", "endFill", slot.frame);
    }

    static function labelOffset(label:Dynamic, widget:Dynamic):{x:Float, y:Float} {
        var x = 0.0;
        var y = 0.0;
        var current = label;
        while (current != null && current != widget) {
            x += G.number(G.field(current, "x"));
            y += G.number(G.field(current, "y"));
            current = G.field(current, "parent");
        }
        return {x: x, y: y};
    }

    static function emptySlot():WeaponSlot
        return {item: null, icon: null, hit: null, frame: null};

    static function find(widget:Dynamic):Plate {
        for (plate in plates) if (plate.widget == widget) return plate;
        return null;
    }

    static function removePlate(plate:Plate):Void {
        plates.remove(plate);
        for (slot in plate.slots) if (slot.hit != null) hideTip(slot.hit);
        if (plate.root != null) try G.call("h2d.Object", "remove", plate.root) catch (_:Dynamic) {}
    }

    public static function reportError(error:Dynamic):Void {
        if (!reportedError) {
            reportedError = true;
            trace("[More Settings] Nameplate weapons: " + Std.string(error));
        }
    }
}

private typedef WeaponSlot = {
    var item:Dynamic;
    var icon:Dynamic;
    var hit:Dynamic;
    var frame:Dynamic;
}

private typedef Plate = {
    var widget:Dynamic;
    var label:Dynamic;
    var root:Dynamic;
    var slots:Array<WeaponSlot>;
    var held:Dynamic;
    var nextRefresh:Float;
}
