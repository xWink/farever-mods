package itemutilities;

import itemutilities.InspectAccess as G;
import itemutilities.InspectUi as Ui;

/** Add shortcuts only to the inventory-slot split dialog, preserving native confirmation. */
class StackFractions {
    public static function amount(stackSize:Int, divisor:Int, min:Int, max:Int):Int
        return Std.int(Math.max(min, Math.min(max, Math.round(stackSize / divisor))));

    public static function attach(window:Dynamic, enabled:Void->Bool):Void {
        if (!enabled()) return;
        var anchor = G.field(window, "anchor");
        if (anchor == null) return;
        var args = Type.enumParameters(anchor);
        var slot = args.length == 1 ? args[0] : null;
        if (!G.isA(slot, "ui.win.InventorySlot")) return;
        var size = G.integer(G.field(slot, "count"));
        // The game's split action passes [1, stack.count - 1]. Other quantity
        // dialogs (buying, selling, etc.) must retain their own UI unchanged.
        if (size < 2 || G.integer(G.field(window, "min")) != 1 || G.integer(G.field(window, "max")) != size - 1) return;
        var spinner = G.field(window, "spinner");
        var parent = G.field(spinner, "parent");
        if (parent == null) return;
        var row = G.field(Ui.node("flow", G.field(parent, "dom"), [], "itemUtilitiesSplitFractions", "horizontal"), "obj");
        Ui.padding(row, 0);
        Ui.style(row, "hspacing", 8);
        G.call("h2d.Flow", "set_horizontalSpacing", row, [8]);
        // Spinner is the first content control above the existing confirmation buttons.
        G.call("h2d.Flow", "addChildAt", parent, [row, 0]);
        addButton(row, window, spinner, size, 4, enabled);
        G.call("h2d.Flow", "addChildAt", row, [spinner, 1]);
        addButton(row, window, spinner, size, 2, enabled);
    }

    static function addButton(row:Dynamic, window:Dynamic, spinner:Dynamic, size:Int, divisor:Int, enabled:Void->Bool):Void {
        var button = G.field(Ui.node("button", G.field(row, "dom"), ['1/$divisor'], 'itemUtilitiesSplit$divisor'), "obj");
        Ui.size(button, 48, 34);
        Ui.padding(button, 0);
        G.call("ui.UIElement", "set_onClick", button, [() -> {
            if (!enabled() || G.field(window, "removed") == true || G.field(window, "parent") == null) return;
            G.call("ui.comp.Spinner", "set_value", spinner,
                [amount(size, divisor, G.integer(G.field(spinner, "min")), G.integer(G.field(spinner, "max")))]);
        }]);
    }
}
