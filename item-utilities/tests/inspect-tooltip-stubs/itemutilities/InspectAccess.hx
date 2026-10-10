package itemutilities;

class InspectAccess {
    public static var build:Dynamic->Void;
    public static var fail = false;
    public static var creates = 0;
    public static var lastStacks = -1;
    public static var viewerItem:Dynamic;
    public static function field(object:Dynamic, name:String):Dynamic
        return object == null ? null : Reflect.field(object, name);
    public static function isA(object:Dynamic, type:String):Bool return field(object, "type") == type;
    public static function array(value:Dynamic):Array<Dynamic> return value == null ? [] : cast value;
    public static function integer(value:Dynamic):Int return Std.int(value);
    public static function call(type:String, name:String, object:Dynamic, args:Array<Dynamic>):Dynamic {
        if (type == "st.Equipment" && name == "getSlot") return Reflect.field(object.slots, args[0]);
        throw 'Unexpected call: $type.$name';
    }
    public static function staticCall(type:String, name:String, args:Array<Dynamic>):Dynamic {
        if (type == "ui.Tooltip" && name == "fromItem") {
            if (InspectTooltips.equippedSlot(args[1]) != null) throw "Native comparison lookup must use the viewer's equipment";
            return create("ui.TipItemCompare", [args[1], viewerItem, null]);
        }
        if (type != "HInfusion" || name != "getRankFromStacks") throw 'Unexpected call: $type.$name';
        lastStacks = args[0];
        var rank = 0;
        for (cap in [2, 4, 6]) if (lastStacks >= cap) rank++;
        return rank;
    }
    public static function create(type:String, args:Array<Dynamic>):Dynamic {
        if (type != "ui.TipItemCompare" || args[2] != null) throw "Unexpected tooltip constructor";
        creates++;
        var root:Dynamic = {parent: null, it: args[0], comparisonIt: args[1]};
        if (args[1] != null) {
            var comparison:Dynamic = {parent: root, realItem: args[1]};
            InspectTooltips.begin(comparison);
            if (InspectTooltips.equippedSlot(args[0]) != null
                || InspectTooltips.infusionRank({parent: comparison, inf: {id: "Bee"}}) != null)
                throw "Viewer comparison panel acquired inspected player's context";
            InspectTooltips.end();
            root.comparisonItem = comparison;
        }
        var tip:Dynamic = {parent: root, realItem: args[0]};
        root.currentItm = tip;
        tip.infusionDetails = {parent: {parent: tip}, inf: {id: args[0].infusion}};
        // BaseElement's constructor rebuilds immediately. These model the
        // TipItem.init prefix/postfix around the native tooltip calculations.
        InspectTooltips.begin(tip);
        if (fail) throw "Native tooltip construction failed";
        if (build != null) build(tip);
        InspectTooltips.end();
        return root;
    }
}
