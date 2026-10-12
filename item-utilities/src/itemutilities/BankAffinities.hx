package itemutilities;

import itemutilities.InspectAccess as G;

/** Bank-only routing and the native rename dialog's companion panel. */
class BankAffinities {
    public static var state = new BankAffinityState();
    static var editingBank:Dynamic;
    static var pending:{bank:Dynamic, dialog:Dynamic};
    static var panel:BankAffinityWindow;
    static var categories:Map<String, String> = [];
    public static function beginTab(bank:Dynamic, tab:Dynamic, enabled:Bool):Void {
        editingBank = enabled && Type.enumEq(G.field(bank, "currentTab"), G.field(tab, "key")) ? bank : null;
    }
    public static function endTab():Void editingBank = null;
    public static function openedDialog(dialog:Dynamic):Void {
        if (editingBank != null && dialog != null) pending = {bank:editingBank, dialog:dialog};
    }
    public static function update(enabled:Bool):Void {
        editingBank = null;
        if (!enabled) { dispose(); return; }
        try {
            if (pending != null) {
                var next = pending; pending = null;
                if (panel != null) panel.dispose();
                panel = new BankAffinityWindow(next.bank, next.dialog, state, ItemUtilitiesMod.saveBankAffinities);
            }
            if (panel != null && !panel.update()) { panel.dispose(); panel = null; }
        } catch (error:Dynamic) {
            dispose();
            trace("[Item Utilities] Bank affinities: " + error);
        }
    }
    public static function dispose():Void {
        pending = null; editingBank = null;
        if (panel != null) { var old = panel; panel = null; old.dispose(); }
    }
    public static function account(loadout:Dynamic):String {
        // UID is the persistent account identity also used by Social/Inspect.
        return G.text(G.field(G.field(G.field(loadout, "owner"), "player"), "uid"));
    }
    public static function destination(loadout:Dynamic, source:Dynamic, item:Dynamic, requested:Dynamic):Dynamic {
        if (loadout == null || item == null || source != G.field(loadout, "inventory")) return requested;
        var banks = G.array(G.field(loadout, "banks"), true);
        if (requested == null || banks.indexOf(requested) < 0) return requested;
        var uid = account(loadout);
        if (uid == "" || !state.hasAccount(uid)) return requested;
        // Native action-availability checks run repeatedly for visible slots.
        // Category depends on immutable item kind, not stats, count or affixes.
        var kind = G.text(G.field(item, "kind"));
        var category = kind == "" ? null : categories.get(kind);
        if (category == null) {
            category = BankAffinityState.category(type -> G.call("st.Item", "isType", item, [type]) == true);
            if (kind != "") categories[kind] = category;
        }
        var tab = state.owner(uid, category);
        if (tab < 0) return requested;
        // An unavailable assigned tab must never silently redirect elsewhere.
        return tab < banks.length ? banks[tab] : null;
    }
}
