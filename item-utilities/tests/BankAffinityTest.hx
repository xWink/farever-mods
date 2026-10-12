import itemutilities.BankAffinityState;
import itemutilities.BankAffinities;
import itemutilities.BankAffinityWindow;
import haxe.Json;

enum TestBankTab { Bank(index:Int); }

class BankAffinityTest {
    static var checks = 0;
    static function eq(a:Dynamic, b:Dynamic, why:String):Void {
        checks++; if (a != b) throw why + ': expected $b, got $a';
    }
    static function main():Void {
        var state = new BankAffinityState();
        eq(state.set("account", "components", 1, true), true, "assign category");
        eq(state.set("account", "components", 2, true), false, "another tab cannot steal an affinity");
        eq(state.set("account", "components", 2, false), false, "another tab cannot clear an affinity");
        eq(state.owner("account", "components"), 1, "one destination per category");
        eq(state.set("account", "food", 1, true), true, "multiple affinities can share a tab");
        eq(state.set("other", "components", 2, true), true, "different accounts have independent banks");
        var saved = Json.stringify(state.saved());
        state.load(Json.parse(saved));
        eq(state.owner("account", "components"), 1, "assignments survive config round trip");
        eq(state.owner("other", "components"), 2, "account scope survives reload");
        eq(state.set("account", "components", 1, false), true, "owning tab can release an affinity");
        eq(state.set("account", "components", 2, true), true, "released affinity can move to another tab");
        state.load([null, {account:"",category:"components",tab:0}, {account:"account",category:"unknown",tab:0},
            {account:"account",category:"components",tab:-1}, {account:"account",category:"components",tab:0.5},
            {account:"account",category:"components",tab:1}, {account:"account",category:"components",tab:2}]);
        eq(state.saved().length, 1, "invalid and duplicate config records cannot create competing routes");
        eq(state.owner("account", "components"), 1, "first valid stored assignment wins");

        for (sample in [
            {types:["Weapon","Gear"], id:"weapons"}, {types:["Armor","Gear"], id:"armor"},
            {types:["GearTool","Gear"], id:"tools"}, {types:["GearFinger","Gear"], id:"accessories"},
            {types:["Food","Consumable","Usable"], id:"food"}, {types:["Recipe","Consumable","Usable"], id:"recipes"},
            {types:["AugmentDemon","Augment"], id:"demon"}, {types:["AugmentDemonSigil","Augment"], id:"demon"},
            {types:["AugmentBlacksmith","Augment"], id:"enchants"}, {types:["CraftingComponent"], id:"components"},
            {types:["UpgradeComponent"], id:"components"}, {types:["Soulstone"], id:"soulstones"},
            {types:["Bag"], id:"bags"}, {types:["CompletedPackage"], id:"packages"}, {types:["LoreBook"], id:"lore"},
            {types:["HealthPotion","Potion","Consumable","Usable"], id:"potions"},
            {types:["Elixir","Consumable","Usable"], id:"elixirs"},
            {types:["Scroll","Consumable","Usable"], id:"scrolls"},
            {types:["InfusionPattern","Consumable","Usable"], id:"patterns"},
            {types:["Mastery","Consumable","Usable"], id:"runes"},
            {types:["SkillPointBook","Consumable","Usable"], id:"skillbooks"},
            {types:["LootableContainer","Consumable","Usable"], id:"containers"},
            {types:["Mount","Collection","Consumable","Usable"], id:"mounts"},
            {types:["GearGlider","Collection","Consumable","Usable"], id:"gliders"},
            {types:["Emote","Collection","Consumable","Usable"], id:"emotes"},
            {types:["Collection","Consumable","Usable"], id:"collections"},
            {types:["Consumable","Usable"], id:"consumables"},
            {types:["StackableUsable","Usable"], id:"consumables"},
            {types:["CraftSlot"], id:"finishing"}, {types:["Currency"], id:"currency"},
            {types:["Prospecting"], id:"prospecting"}, {types:["Misc"], id:"misc"},
            {types:["UnknownFutureType"], id:"misc"}
        ]) eq(BankAffinityState.category(type -> sample.types.indexOf(type) >= 0), sample.id, "inherited types have one unambiguous category");

        var migrated = new BankAffinityState();
        migrated.load([{account:"account",category:"consumables",tab:1}, {account:"account",category:"misc",tab:0},
            {account:"other",category:"consumables",tab:2}, {account:"account",category:"mounts",tab:3,version:2}]);
        for (id in ["potions","elixirs","scrolls","recipes","patterns","runes","skillbooks","containers","gliders","emotes","collections"])
            eq(migrated.owner("account",id),1,"new category preserves its old consumables destination: " + id);
        for (id in ["currency","prospecting","lore","finishing"])
            eq(migrated.owner("account",id),0,"new category preserves its old miscellaneous destination: " + id);
        eq(migrated.owner("account","mounts"),3,"explicit assignment wins over migration");
        eq(migrated.owner("other","mounts"),2,"migration remains scoped to account");
        eq(migrated.set("account","containers",1,false),true,"can release migrated affinity");
        eq(migrated.set("account","gliders",1,false),true,"can release gliders from their old broad group");
        eq(migrated.set("account","gliders",4,true),true,"can assign gliders independently");
        migrated.load(Json.parse(Json.stringify(migrated.saved())));
        eq(migrated.owner("account","containers"),-1,"reload does not restore an unchecked migrated affinity");
        eq(migrated.owner("account","gliders"),4,"independent destination survives reload");
        eq(migrated.set("account","mounts",1,true),false,"specific categories retain cross-tab conflict protection");

        BankAffinities.state = state;
        var first:Dynamic = {full:false}, second:Dynamic = {full:true}, backpack:Dynamic = {};
        var player:Dynamic = {uid:"account"};
        var loadout:Dynamic = {owner:{player:player}, inventory:backpack, banks:{array:[first,second]}};
        var component:Dynamic = {types:["CraftingComponent"]}, food:Dynamic = {types:["Food","Consumable"]};
        eq(BankAffinities.destination(loadout,backpack,component,first),second,"deposit into a closed affinity tab");
        eq(BankAffinities.destination(loadout,backpack,component,second),second,"routing is idempotent for native hook reentry");
        eq(BankAffinities.destination(loadout,backpack,food,first),first,"unassigned items use the selected tab");
        eq(BankAffinities.destination(loadout,first,component,backpack),backpack,"withdrawals are unchanged");
        eq(BankAffinities.destination(loadout,first,component,second),second,"explicit bank-to-bank moves are unchanged");
        var recycler:Dynamic = {};
        eq(BankAffinities.destination(loadout,backpack,component,recycler),recycler,"other utility destinations are unchanged");
        eq(BankAffinities.destination(loadout,backpack,null,first),first,"empty source slot is safe");
        player.uid = "other";
        eq(BankAffinities.destination(loadout,backpack,component,first),first,"account switch cannot reuse another bank's affinity");
        player.uid = "account"; loadout.banks.array = [first];
        eq(BankAffinities.destination(loadout,backpack,component,first),null,"unavailable affinity tab never falls back to selected tab");
        loadout.banks.array = [first,second];
        state.set("account","mounts",1,true); state.set("account","consumables",0,true);
        var mount:Dynamic = {kind:"testMount",types:["Mount","Collection","Consumable","Usable"]};
        eq(BankAffinities.destination(loadout,backpack,mount,first),second,"mount's own affinity overrides broad consumable type");
        state.set("account","mounts",1,false);
        eq(BankAffinities.destination(loadout,backpack,mount,second),second,"unassigned mount uses open tab even when other consumables are assigned");

        var bank:Dynamic = {currentTab:Bank(1)}, dialog:Dynamic = {};
        BankAffinities.openedDialog(dialog); BankAffinities.update(true);
        eq(BankAffinityWindow.created,0,"ordinary rename/text dialogs do not get affinities");
        BankAffinities.beginTab(bank,{key:Bank(0)},true);
        BankAffinities.openedDialog(dialog); BankAffinities.endTab(); BankAffinities.update(true);
        eq(BankAffinityWindow.created,0,"switching to another tab does not open affinities");
        BankAffinities.beginTab(bank,{key:Bank(1)},true);
        BankAffinities.openedDialog(dialog); BankAffinities.endTab();
        eq(BankAffinityWindow.created,0,"panel waits until native dialog initialization completes");
        BankAffinities.update(true);
        eq(BankAffinityWindow.created,1,"clicking selected tab opens companion once");
        eq(BankAffinityWindow.lastDialog,dialog,"companion belongs to the actual native rename dialog");
        BankAffinities.update(false);
        eq(BankAffinityWindow.disposed,1,"disabling the mod closes the companion");
        BankAffinities.beginTab(bank,{key:Bank(1)},false);
        BankAffinities.openedDialog(dialog); BankAffinities.endTab(); BankAffinities.update(true);
        eq(BankAffinityWindow.created,1,"disabled tab clicks do not queue a companion");
        Sys.println('Bank affinities: $checks checks passed.');
    }
}
