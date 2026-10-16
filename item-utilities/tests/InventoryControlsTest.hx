import itemutilities.DepositItems;
import itemutilities.StackFractions;
import itemutilities.InspectAccess as G;

private enum TestAnchor { Element(value:Dynamic); Position(x:Int, y:Int); }

class InventoryControlsTest {
    static var checks = 0;
    static function eq(actual:Dynamic, expected:Dynamic, label:String):Void {
        checks++; if (actual != expected) throw label + ": " + actual + " != " + expected;
    }
    static function category(mode:Int, types:Array<String>):Bool return DepositItems.matches(mode, types.contains);
    static function main():Void {
        for (kind in ["AugmentDemon", "AugmentDemonSigil", "Soulstone"])
            eq(category(4, [kind]), true, "Demonic items include " + kind);
        for (kind in ["Weapon", "Armor", "Gear", "GearTool"])
            eq(category(5, [kind]), true, "Equipment includes " + kind);
        for (kind in ["Mount", "GearGlider", "Recipe", "InfusionPattern", "Emote", "Collection"]) {
            eq(category(3, [kind, "Consumable"]), true, "Collectible includes " + kind);
            eq(category(2, [kind, "Consumable"]), false, "Collectibles not in food/consumable");
        }
        eq(category(5, ["GearGlider", "Gear"]), false, "Gliders go to collectibles instead of equipment");
        for (kind in ["Food", "Consumable"]) eq(category(2, [kind]), true, "Merged food/consumables");
        eq(category(2, ["Soulstone", "Consumable"]), false, "Soulstones use demonic button");
        eq(category(0, ["CraftingComponent"]), true, "Crafting button unchanged");
        eq(category(1, ["Other"]), true, "Deposit all unchanged");
        for (size in 2...102) for (divisor in [2,4])
            eq(StackFractions.amount(size, divisor, 1, size-1), Std.int(Math.max(1, Math.min(size-1, Math.round(size/divisor)))), "Rounded legal fraction");
        eq(StackFractions.amount(7,2,1,6), 4, "Half of odd stack rounds up");
        eq(StackFractions.amount(6,4,1,5), 2, "Quarter rounds half upward");
        var root=G.object("root",null), content=G.object("flow",root);
        var spinner=G.object("spinner",content); spinner.min=1; spinner.max=6; spinner.value=1;
        var confirm=G.object("confirm",content);
        var slot:Dynamic={type:"ui.win.InventorySlot",count:7};
        var window:Dynamic={anchor:Element(slot),min:1,max:6,spinner:spinner,parent:root,removed:false};
        var enabled=true;
        StackFractions.attach(window,()->enabled);
        eq(content.children.length,2,"One spinner row above existing confirmation");
        var row=content.children[0];
        eq(content.children[1],confirm,"Native confirmation preserved");
        eq(row.layout,"horizontal","Fraction shortcuts share spinner row");
        eq(row.children.length,3,"Quarter, spinner, half");
        eq(row.children[0].text,"1/4","Quarter on left");
        eq(row.children[1],spinner,"Native spinner retained");
        eq(row.children[2].text,"1/2","Half on right");
        row.children[2].onClick(); eq(spinner.value,4,"Half uses full stack, not split maximum");
        row.children[0].onClick(); eq(spinner.value,2,"Quarter updates spinner");
        enabled=false; row.children[2].onClick(); eq(spinner.value,2,"Disabled mod ignores old callbacks");
        enabled=true; window.removed=true; row.children[2].onClick(); eq(spinner.value,2,"Closed dialog ignores old callbacks");
        var otherContent=G.object("flow",root), otherSpinner=G.object("spinner",otherContent);
        for (anchor in [Element({type:"ui.ShopSlot",count:7}),Position(1,2),Element(slot)]) {
            StackFractions.attach({anchor:anchor,min:1,max:7,spinner:otherSpinner,parent:root},()->true);
            eq(otherContent.children.length,1,"Other quantity dialogs unchanged");
        }
        Sys.println('Inventory controls: $checks checks passed.');
    }
}
