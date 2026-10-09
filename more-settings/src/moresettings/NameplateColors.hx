package moresettings;

import moresettings.GameAccess as G;

/** Paints each player nameplate with that hero's class color. */
class NameplateColors {
    public static var enabled:Bool = true;
    static var reportedError:Bool = false;
    static var plates:Array<Plate> = [];

    public static function attach(widget:Dynamic):Void {
        if (widget == null) return;
        for (plate in plates) if (plate.widget == widget) return;
        var label = G.field(widget, "heroName");
        if (label == null) return;
        plates.push({
            widget: widget,
            label: label,
            original: G.integer(G.field(label, "textColor"), 0xFFFFFF),
            applied: -1,
            className: "",
            checkedAt: 0
        });
        G.call("ui.UIElement", "bindUpdate", widget, [(_dt:Float) -> refresh(widget)]);
    }

    static function refresh(widget:Dynamic):Void {
        var plate = find(widget);
        if (plate == null) return;
        if (G.field(widget, "removed") == true) {
            plates.remove(plate);
            return;
        }
        if (!enabled) {
            if (plate.applied != plate.original) paint(plate, plate.original);
            return;
        }
        var now = haxe.Timer.stamp();
        if (plate.className == "" || now - plate.checkedAt > 1) {
            plate.className = heroClass(G.field(widget, "hero"));
            plate.checkedAt = now;
        }
        var color = ClassColors.color(plate.className);
        if (color < 0) {
            if (plate.applied != plate.original) paint(plate, plate.original);
            return;
        }
        // FmtText sync can put the native white back, so reapply while enabled.
        paint(plate, color);
    }

    static function heroClass(hero:Dynamic):String {
        if (hero == null) return "";
        // Replicated unit id, e.g. Class_Warrior / Class_Priest. Prefer this over skills.
        var name = ClassColors.fromId(G.text(G.field(hero, "kind")));
        if (name != "") return name;
        var ids:Array<String> = [];
        for (key in ["attackComboSkill", "secondarySkill", "dashSkill"]) addSkill(ids, G.field(hero, key));
        for (key in ["attackSkills", "skillSlots"]) addList(ids, G.field(hero, key));
        var spec = G.field(hero, "specialization");
        addList(ids, G.field(spec, "skillSlots"));
        var player = G.field(hero, "player");
        var kind = G.text(G.field(G.field(player, "heroData"), "kind"));
        name = ClassColors.identify(ids, kind);
        if (name != "") return name;
        try {
            if (G.call("ent.Hero", "get_mage", hero) != null) return "mage";
            if (G.call("ent.Hero", "get_priest", hero) != null) return "cleric";
        } catch (_:Dynamic) {}
        return "";
    }

    static function addList(ids:Array<String>, value:Dynamic):Void {
        if (value == null) return;
        var items:Array<Dynamic> = [];
        try items = G.array(value) catch (_:Dynamic) items = [];
        if (items.length == 0) try items = G.array(value, true) catch (_:Dynamic) items = [];
        for (skill in items) addSkill(ids, skill);
    }

    static function addSkill(ids:Array<String>, skill:Dynamic):Void {
        var id = Std.isOfType(skill, String) ? G.text(skill) : G.text(G.field(skill, "kind"));
        if (id != "" && ids.indexOf(id) < 0) ids.push(id);
    }

    static function paint(plate:Plate, color:Int):Void {
        var label = plate.label;
        var dom = G.field(label, "dom");
        if (dom != null && plate.applied != color)
            G.call("domkit.Properties", "initStyle", dom, ["color", color]);
        // The name is HtmlText. Its drawable tint multiplies textColor, which muddies the class color.
        var tint = G.field(label, "color");
        if (tint != null) for (channel in ["x", "y", "z"]) G.set(tint, channel, 1.0);
        G.call("h2d.HtmlText", "set_textColor", label, [color]);
        plate.applied = color;
    }

    static function find(widget:Dynamic):Plate {
        for (plate in plates) if (plate.widget == widget) return plate;
        return null;
    }

    public static function reportError(error:Dynamic):Void {
        if (!reportedError) {
            reportedError = true;
            trace("[More Settings] Class nameplates: " + Std.string(error));
        }
    }
}

private typedef Plate = {
    var widget:Dynamic;
    var label:Dynamic;
    var original:Int;
    var applied:Int;
    var className:String;
    var checkedAt:Float;
}
