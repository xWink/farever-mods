import itemutilities.InspectTooltips as Tips;
import itemutilities.InspectAccess as G;

class InspectTooltipsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, why:String):Void {
        checks++;
        if (actual != expected) throw '$why: expected $expected, got $actual';
    }
    static function gear(infusion:String):Dynamic
        return {type: "st.item.Gear", inf: {}, infusion: infusion, infusionBonusStat: "Power", flags: {value: 2}};

    static function main():Void {
        var weapon = gear("Bee");
        var other = gear("Bee");
        var equipment:Dynamic = {slots: {Slot_Weapon2: weapon, Slot_Weapon1: other}, content: [
            {item: weapon}, {item: other}, null, {item: gear("Bee")}, {item: gear("Bee")},
            {item: gear("Crimson")}, {item: {type: "st.Item", infusion: "Bee"}}
        ]};
        // Remote progress and infusion caches are intentionally absent.
        var hero:Dynamic = {removed: false, loadout: {equipment: equipment}};
        var nativeFactors:Map<String, Float> = ["Slot_Weapon1" => 1.0, "Slot_Weapon2" => 0.4];
        Tips.clear();
        G.viewerItem = gear("Crimson");
        G.build = tip -> {
            eq(Tips.equippedSlot(weapon), "Slot_Weapon2", "native calculation sees inspected arsenal slot");
            eq(nativeFactors.get(Tips.equippedSlot(weapon)) * 100, 40.0, "native slot metadata supplies 40 percent");
            eq(tip.realItem, weapon, "tooltip retains inspected item's rolled stats and infusion flags");
            eq(tip.realItem.flags.value, 2, "replicated infusion bonus eligibility is preserved");
            eq(Tips.equippedSlot(other), null, "unrelated equipment query is not redirected");
            eq(Tips.infusionRank(tip.infusionDetails), 2, "set highlighting uses inspected gear");
            eq(G.lastStacks, 4, "only matching equipped gear contributes to native rank calculation");
            var ordinary:Dynamic = {realItem: other, parent: null};
            Tips.begin(ordinary);
            eq(Tips.equippedSlot(weapon), null, "nested unrelated tooltip has no inspect scope");
            eq(Tips.infusionRank({parent: ordinary, inf: {id: "Bee"}}), null, "ordinary set highlighting stays native");
            Tips.end();
            eq(Tips.equippedSlot(weapon), "Slot_Weapon2", "nested tooltip restores outer inspect scope");
        };
        var root:Dynamic = Tips.create(hero, weapon, "Slot_Weapon2");
        eq(root.comparisonIt, G.viewerItem, "native comparison panel keeps the viewer's equipment");
        eq(Tips.equippedSlot(weapon), null, "equipment queries return to normal after creation");
        var tip:Dynamic = root.currentItm;
        eq(Tips.infusionRank(tip.infusionDetails), 2, "later infusion detail rebuild retains inspected context");
        equipment.content.push({item: gear("Bee")}); equipment.content.push({item: gear("Bee")});
        eq(Tips.infusionRank(tip.infusionDetails), 3, "set ranks follow inspected equipment changes");
        Tips.begin(tip);
        eq(Tips.equippedSlot(weapon), "Slot_Weapon2", "native tooltip rebuild restores arsenal context");
        Tips.end();
        eq(Tips.equippedSlot(weapon), null, "rebuild does not leak equipment context");

        G.build = tip -> eq(nativeFactors.get(Tips.equippedSlot(other)), 1.0, "main hand retains full native stats");
        Tips.create(hero, other, "Slot_Weapon1");
        var creates = G.creates;
        eq(Tips.create(hero, weapon, "Slot_Weapon1"), null, "stale item-slot pairing cannot show a tooltip");
        hero.removed = true;
        eq(Tips.create(hero, weapon, "Slot_Weapon2"), null, "departed player cannot show a stale tooltip");
        eq(G.creates, creates, "unavailable items do not construct tooltips");
        hero.removed = false;
        G.fail = true;
        var failed = false;
        try Tips.create(hero, weapon, "Slot_Weapon2") catch (_:Dynamic) failed = true;
        eq(failed, true, "native failure propagates");
        eq(Tips.equippedSlot(weapon), null, "failed native init restores scope even without a postfix");
        G.fail = false;
        Tips.forget(tip);
        eq(Tips.infusionRank(tip.infusionDetails), null, "removed tooltips release their context");
        Tips.clear();
        eq(Tips.equippedSlot(weapon), null, "closing inspect clears capture scope");
        Sys.println('Inspect tooltips: $checks checks passed.');
    }
}
