import minimap.SoulstoneMarkers;
import minimap.GameAccess as G;

class SoulstoneMarkersTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function circle(cost:Array<Dynamic>):Dynamic
        return {id: "UnrelatedInternalName", props: {interactible: {cost: cost}}};

    static function main():Void {
        G.items["Soulstone_Z1_1"] = {type: "Soulstone"};
        G.items["Soulstone_Z2_4"] = {type: "Soulstone"};
        G.items["FutureStone"] = {type: "Soulstone"};
        G.items["Gold"] = {type: "Currency"};
        G.items["Soulstone"] = {type: "Misc"}; // unused template has this misleading ID
        G.items["DemonicSoul"] = {type: "Misc"};
        for (id in ["Soulstone_Z1_1", "Soulstone_Z2_4", "FutureStone"]) {
            eq(SoulstoneMarkers.isCircle(circle([{item: id, count: 1}])), true, "classify by required item type");
            eq(SoulstoneMarkers.isCircle(circle([{item: id}])), true, "default count is supported");
        }
        eq(SoulstoneMarkers.isCircle(circle([{item: "Gold"}, {item: "FutureStone"}])), true, "scan all interaction costs");
        for (id in ["Gold", "Soulstone", "DemonicSoul", "Unknown"]) {
            eq(SoulstoneMarkers.isCircle(circle([{item: id}])), false, "unrelated costs do not mark a circle");
        }
        eq(SoulstoneMarkers.isCircle(null), false, "missing definition is optional");
        eq(SoulstoneMarkers.isCircle({id: "SoulstoneSummoningCircle"}), false, "name alone is not a match");
        eq(SoulstoneMarkers.isCircle({props: {dispenser: {targetUnit: "Demon_Z1_Claws_Soulstone"}}}), false,
            "spawning a demon without a soulstone cost is not a soulstone circle");
        eq(SoulstoneMarkers.isCircle({props: {shop: [{cost: [{item: "FutureStone"}]}]}}), false,
            "merchant inventory does not create a circle marker");
        eq(SoulstoneMarkers.isCircle(circle([])), false, "empty costs");
        eq(SoulstoneMarkers.isCircle(circle([null, {}])), false, "incomplete optional cost entries");
        G.itemReads = 0;
        SoulstoneMarkers.isCircle({props: {}});
        eq(G.itemReads, 0, "ordinary landmarks do not look up items");
        G.units["Demon_Z1_Claws_Soulstone"] = {name:"Belzebeat"};
        var named:Dynamic = circle([{item:"Soulstone_Z1_1"}]);
        named.props.dispenser = {targetUnit:"Demon_Z1_Claws_Soulstone"};
        eq(SoulstoneMarkers.name(named), "Belzebeat Soulstone", "name uses the summoned boss, not the circle text or internal ID");
        G.items["Soulstone_Z1_1"].name = "Belzebeat Soulstone";
        eq(SoulstoneMarkers.name(circle([{item:"Soulstone_Z1_1"}])), "Belzebeat Soulstone", "item name fallback for missing dispenser");
        eq(SoulstoneMarkers.name(null), "Soulstone", "missing definition has readable fallback");
        Sys.println('Soulstone marker tests passed ($checks checks)');
    }
}
