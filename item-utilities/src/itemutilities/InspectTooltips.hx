package itemutilities;

import haxe.ds.ObjectMap;
import itemutilities.InspectAccess as G;

private typedef InspectItemContext = {
    var equipment:Dynamic;
    var item:Dynamic;
    var slot:String;
}

/** Supply inspected equipment only to native item-tooltip calculations. */
class InspectTooltips {
    static var contexts:ObjectMap<Dynamic, InspectItemContext> = new ObjectMap();
    static var active:InspectItemContext;
    static var building:InspectItemContext;
    static var scopes:Array<InspectItemContext> = [];

    public static function create(hero:Dynamic, item:Dynamic, slot:String):Dynamic {
        var equipment = G.field(G.field(hero, "loadout"), "equipment");
        if (hero == null || G.field(hero, "removed") == true || equipment == null || item == null
            || G.call("st.Equipment", "getSlot", equipment, [slot]) != item) return null;
        var previous = active;
        var previousBuilding = building;
        var depth = scopes.length;
        var context:InspectItemContext = {equipment: equipment, item: item, slot: slot};
        building = context;
        active = null;
        var tip:Dynamic;
        try {
            // Keep the native comparison panel and the actual replicated item.
            // Only the inspected panel's init receives the remote slot context.
            tip = G.staticCall("ui.Tooltip", "fromItem", [G.field(item, "inf"), item]);
        } catch (error:Dynamic) {
            for (element in contexts.keys()) if (contexts.get(element) == context) contexts.remove(element);
            active = previous;
            building = previousBuilding;
            scopes.resize(depth);
            throw error;
        }
        active = previous;
        building = previousBuilding;
        scopes.resize(depth);
        return tip;
    }

    public static function begin(tip:Dynamic):Void {
        var context = find(tip);
        if (context == null && building != null && G.field(tip, "realItem") == building.item) {
            context = building;
            contexts.set(tip, context);
        }
        scopes.push(active);
        active = context;
    }

    public static function end():Void active = scopes.pop();

    static function find(element:Dynamic):InspectItemContext {
        if (!contexts.iterator().hasNext()) return null;
        while (element != null) {
            var context = contexts.get(element);
            if (context != null) return context;
            element = G.field(element, "parent");
        }
        return null;
    }

    /** Null leaves ordinary game equipment queries untouched. */
    public static function equippedSlot(item:Dynamic):String {
        return active != null && item == active.item ? active.slot : null;
    }

    public static function infusionRank(description:Dynamic):Null<Int> {
        var context = find(description);
        if (context == null) return null;
        var infusion = G.field(G.field(description, "inf"), "id");
        if (infusion == null) return 0;
        var stacks = 0;
        // Match Hero.refreshInfusions using replicated gear, without relying on
        // another hero's client-side infusion cache or private player progress.
        for (stack in G.array(G.field(context.equipment, "content"))) {
            var gear = G.field(stack, "item");
            if (G.isA(gear, "st.item.Gear") && G.field(gear, "infusion") == infusion) stacks++;
        }
        return G.integer(G.staticCall("HInfusion", "getRankFromStacks", [stacks]));
    }

    public static function forget(element:Dynamic):Void contexts.remove(element);
    public static function clear():Void {
        contexts = new ObjectMap();
        scopes = [];
        active = null;
        building = null;
    }
}
