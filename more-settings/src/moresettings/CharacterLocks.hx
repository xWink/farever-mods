package moresettings;

import haxe.ds.ObjectMap;
import moresettings.GameAccess as G;
import moresettings.AppearanceUi as Ui;

private typedef LockedCharacterRow = {
    var slot:Dynamic;
    var badge:Dynamic;
    var original:Dynamic;
    var click:Void->Void;
}
private class CharacterLockEntry {
    public var button:Dynamic;
    public var header:Dynamic;
    public var background:Dynamic;
    public var deleteButton:Dynamic;
    public var color = -1;
    public var editing = false;
    public var rows:Array<LockedCharacterRow> = [];
    public function new() {}
}

/** Native character-select controls. Locks survive leaving this screen and restarting. */
class CharacterLocks {
    static var store = new CharacterLockStore("hlx/config/more-settings/character-locks.json");
    static var entries = new ObjectMap<Dynamic, CharacterLockEntry>();
    static var deleteButtons = new ObjectMap<Dynamic, Dynamic>();
    static var reported = false;

    public static function report(error:Dynamic):Void {
        if (reported) return;
        reported = true;
        trace("[More Settings] Character locks: " + Std.string(error));
    }
    static function id(info:Dynamic):String {
        // heroID is an I64. Stringify it directly: converting to Float/Int loses bits.
        return G.text(G.field(info, "heroID"));
    }
    public static function blocksDeletion(screen:Dynamic, info:Dynamic):Bool {
        var entry = entries.get(screen);
        if (entry != null && entry.editing) return true;
        if (info == null) return true;
        try return store.locked(id(info)) catch (error:Dynamic) {
            report(error);
            // A failed read must never silently turn a saved lock off.
            return true;
        }
    }
    public static function syncDelete(screen:Dynamic):Void {
        if (!entries.exists(screen)) return;
        var button = G.field(screen, "deleteCharacterButton");
        var enable = G.field(screen, "currentEnable") != false
            && !blocksDeletion(screen, G.field(screen, "currentSelected"));
        if (G.field(button, "enable") != enable) G.call("ui.UIElement", "set_enable", button, [enable]);
    }
    public static function preventEnable(button:Dynamic):Bool {
        var screen = deleteButtons.get(button);
        return screen != null && (G.field(screen, "currentEnable") == false
            || blocksDeletion(screen, G.field(screen, "currentSelected")));
    }

    public static function attach(screen:Dynamic):Void {
        forget(screen);
        var entry = new CharacterLockEntry();
        entries.set(screen, entry);
        try {
            entry.deleteButton = G.field(screen, "deleteCharacterButton");
            if (entry.deleteButton != null) deleteButtons.set(entry.deleteButton, screen);
            entry.header = G.field(screen, "windowHeader");
            if (entry.header == null) throw "Character selection header is unavailable.";
            entry.button = G.field(Ui.node("button", G.field(entry.header, "dom"), [""], "moreSettingsCharacterLocks"), "obj");
            Ui.absolute(entry.header, entry.button);
            Ui.padding(entry.button, 0); Ui.size(entry.button, 32, 32);
            Ui.style(entry.button, "background-alpha", 0.);
            var artwork = G.create("h2d.Object", [entry.button]);
            Ui.absolute(entry.button, artwork);
            CharacterLockIcons.smooth(artwork);
            entry.background = G.create("h2d.Graphics", [artwork]);
            CharacterLockIcons.background(entry.background);
            CharacterLockIcons.draw(G.create("h2d.Graphics", [artwork]));
            G.call("ui.UIElement", "set_onClick", entry.button, [() -> {
                if (entries.get(screen) != entry) return;
                entry.editing = !entry.editing;
                G.call("ui.UIElement", "set_selected", entry.button, [entry.editing]);
                syncDelete(screen);
            }]);
            for (slot in G.array(G.field(screen, "characterBtns"))) {
                var badge = G.create("h2d.Graphics", [slot]);
                Ui.absolute(slot, badge);
                CharacterLockIcons.draw(badge); CharacterLockIcons.smooth(badge);
                G.call("h2d.Object", "setScale", badge, [0.75]);
                var row:LockedCharacterRow = {slot:slot, badge:badge, original:G.field(slot, "onClick"), click:null};
                row.click = () -> clickRow(screen, entry, row);
                entry.rows.push(row);
                G.call("ui.UIElement", "set_onClick", slot, [row.click]);
            }
            refresh(screen, entry);
            G.call("ui.UIElement", "bindUpdate", screen, [(_:Float) -> {
                if (entries.get(screen) == entry) try layout(screen, entry) catch (error:Dynamic) report(error);
            }]);
        } catch (error:Dynamic) {
            forget(screen);
            throw error;
        }
    }
    static function clickRow(screen:Dynamic, entry:CharacterLockEntry, row:LockedCharacterRow):Void {
        if (entries.get(screen) != entry || G.field(row.slot, "parent") == null) return;
        if (!entry.editing) {
            if (row.original != null) row.original();
            return;
        }
        try {
            var key = id(G.field(row.slot, "heroInfo"));
            store.set(key, !store.locked(key));
            refresh(screen, entry);
        } catch (error:Dynamic) {
            report(error);
            var ui = G.call("ui.BaseElement", "get_baseUI", screen);
            if (ui != null) Ui.message(ui, "Character locks", "Could not save this change. Your existing character locks have been kept.");
        }
    }
    static function refresh(screen:Dynamic, entry:CharacterLockEntry):Void {
        for (row in entry.rows) {
            var locked = false;
            try locked = store.locked(id(G.field(row.slot, "heroInfo"))) catch (error:Dynamic) report(error);
            Ui.show(row.badge, locked);
        }
        syncDelete(screen);
    }
    static function layout(screen:Dynamic, entry:CharacterLockEntry):Void {
        var w = G.number(G.field(entry.header, "calculatedWidth"));
        var h = G.number(G.field(entry.header, "calculatedHeight"));
        if (w > 0 && h > 0) place(entry.button, w-44, Math.max(0, (h-32)/2));
        var pressed = G.field(entry.button, "pushed") != null;
        var hover = G.field(entry.button, "hasHover") == true;
        var color = entry.editing ? (pressed ? 0x654627 : hover ? 0x7D5933 : 0x946E40)
            : (pressed ? 0x423B36 : hover ? 0x524A45 : 0x665E59);
        if (color != entry.color) {
            G.call("h3d.Vector4Impl", "setColor", G.field(entry.background, "color"), [color | 0xFF000000]);
            entry.color = color;
        }
        for (row in entry.rows) {
            // Native children inherit the character list's scrolling and clipping.
            var width = G.number(G.field(row.slot, "calculatedWidth"));
            if (width > 0) place(row.badge, width-30, 3);
        }
    }
    static function place(object:Dynamic, x:Float, y:Float):Void {
        if (G.field(object, "x") != x || G.field(object, "y") != y) Ui.position(object, x, y);
    }
    public static function forget(screen:Dynamic):Void {
        var entry = entries.get(screen);
        if (entry == null) return;
        entries.remove(screen);
        if (entry.deleteButton != null) deleteButtons.remove(entry.deleteButton);
        for (row in entry.rows) {
            if (G.field(row.slot, "onClick") == row.click) G.call("ui.UIElement", "set_onClick", row.slot, [row.original]);
            if (G.field(row.badge, "parent") != null) G.call("h2d.Object", "remove", row.badge);
        }
        if (G.field(entry.button, "parent") != null) G.call("h2d.Object", "remove", entry.button);
    }
}
