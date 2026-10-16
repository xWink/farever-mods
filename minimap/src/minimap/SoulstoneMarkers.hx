package minimap;

import minimap.GameAccess as G;

/** Identify the interaction that consumes a soulstone, not its summoned foe. */
class SoulstoneMarkers {
    public static function name(inf:Dynamic):String {
        // The dispenser points at the actual summoned unit, whose localized
        // name includes the boss identity (the circle's own name does not).
        var props = G.field(inf, "props");
        var id = G.text(G.field(G.field(props, "dispenser"), "targetUnit"));
        if (id != "") {
            var unit = G.call("haxe.ds.StringMap", "get", G.field(G.current("Data", "unit"), "byId"), [id]);
            if (unit != null) {
                var boss = G.text(G.staticCall("HText", "unit", [unit, G.current("ETextKind", "Name")]));
                if (boss != "") return clean(boss) + " Soulstone";
            }
        }
        // Definitions may omit the dispenser. The required stone still has a
        // localized item name; never expose an internal unit/item identifier.
        var stone = requiredStone(inf);
        if (stone != null) {
            var label = G.text(G.staticCall("HText", "item", [stone, G.current("ETextKind", "Name"), null]));
            if (label != "") return clean(label);
        }
        return "Soulstone";
    }
    static function clean(value:String):String
        return StringTools.replace(StringTools.replace(value, "\n", " "), "\r", "");

    public static function isCircle(inf:Dynamic):Bool return requiredStone(inf) != null;

    static function requiredStone(inf:Dynamic):Dynamic {
        var interaction = G.field(G.field(inf, "props"), "interactible");
        var costs = G.field(interaction, "cost");
        if (costs == null) return null;
        var items = G.field(G.current("Data", "item"), "byId");
        if (items == null) return null;
        for (cost in G.array(costs)) {
            var id = G.text(G.field(cost, "item"));
            if (id == "") continue;
            var item = G.call("haxe.ds.StringMap", "get", items, [id]);
            if (G.text(G.field(item, "type")) == "Soulstone") return item;
        }
        return null;
    }
}
