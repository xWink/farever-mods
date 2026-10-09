import moresettings.NameplateWeapons;
import moresettings.SettingsData;
import moresettings.GameAccess as G;

@:access(moresettings.NameplateWeapons)
class NameplateWeaponsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, message:String):Void {
        checks++;
        if (actual != expected) throw message + ': expected $expected, got $actual';
    }
    static function main():Void {
        eq(SettingsData.defaults().showNameplateWeapons, true, "equipped weapon icons start enabled");
        var main = {inf: "sword"};
        var arsenal = {inf: "bow"};
        var pair = NameplateWeapons.pair(main, arsenal);
        eq(pair.length, 2, "both weapon columns exist");
        eq(pair[0], main, "weapon1 is the left icon");
        eq(pair[1], arsenal, "weapon2 is the right icon");
        eq(NameplateWeapons.shown(main), true, "an item with a definition is drawn");
        eq(NameplateWeapons.shown(null), false, "a null weapon is hidden");
        eq(NameplateWeapons.shown({}), false, "an item without a definition is hidden");
        eq(NameplateWeapons.colorForRarity("Rare"), 0x4aa3ff, "rare weapons get a blue plate");
        eq(NameplateWeapons.colorForRarity("Epic"), 0xb44cff, "epic weapons get a purple plate");
        eq(NameplateWeapons.colorForRarity("Legendary"), 0xffb020, "legendary weapons get a gold plate");
        eq(NameplateWeapons.colorForRarity("Common"), -1, "common weapons stay unmarked");
        eq(NameplateWeapons.colorForRarity("Uncommon"), -1, "uncommon weapons stay unmarked");
        var onlyArsenal = NameplateWeapons.pair(null, arsenal);
        eq(onlyArsenal[0], null, "a missing main weapon stays the left column");
        eq(onlyArsenal[1], arsenal, "the arsenal weapon stays the right column");
        var parent = {};
        var hover = NameplateWeapons.createHover(parent, main);
        eq(hover.args[2], parent, "weapon hover belongs to the nameplate icon root");
        eq(hover.args[3], null, "weapon hover uses the native default shape");
        eq(Reflect.isFunction(hover.onOver), true, "weapon hover installs its tooltip callback");
        eq(Reflect.isFunction(hover.onOut), true, "weapon hover installs its tooltip cleanup");
        var ui:Dynamic = {root: {}, currentTip: null};
        G.data = {current: ui};
        hover.onOver(null);
        var firstTip = ui.currentTip;
        eq(firstTip != null, true, "hovering creates the native item tooltip");
        eq(firstTip.content.definition, main.inf, "tooltip receives the native item definition");
        eq(firstTip.content.item, main, "tooltip retains the actual equipped item");
        eq(firstTip.anchor, hover, "the game positions the tooltip at its weapon icon");
        hover.onOut(null);
        eq(ui.currentTip, null, "leaving the weapon removes its tooltip");
        eq(G.removedTips, 1, "cleanup uses the native UI tooltip owner");
        hover.onOver(null);
        var arsenalHover = NameplateWeapons.createHover(parent, arsenal);
        arsenalHover.onOver(null);
        var arsenalTip = ui.currentTip;
        hover.onOut(null);
        eq(ui.currentTip, arsenalTip, "a delayed exit from the other weapon preserves the new tooltip");
        var foreignTip = {parent: ui.root};
        ui.currentTip = foreignTip;
        arsenalHover.onOut(null);
        eq(ui.currentTip, foreignTip, "weapon cleanup preserves another UI's tooltip");
        eq(arsenalTip.parent, null, "a replaced weapon tooltip is still disposed");
        G.data.current = null;
        hover.onOver(null);
        eq(NameplateWeapons.activeTip, null, "a missing UI cannot retain a weapon tooltip");
        Sys.println('Nameplate weapon tests passed ($checks checks)');
    }
}
