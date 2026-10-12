package itemutilities;

/** Local preferences, scoped to account because bank tabs are account-wide. */
class BankAffinityState {
    public static final CATEGORIES = [
        {id:"weapons", label:"Weapons"}, {id:"armor", label:"Armour"},
        {id:"accessories", label:"Accessories"}, {id:"tools", label:"Tools"},
        {id:"food", label:"Food"}, {id:"consumables", label:"Consumables"},
        {id:"demon", label:"Demon enchantments"}, {id:"enchants", label:"Enchantments"},
        {id:"components", label:"Components"}, {id:"soulstones", label:"Soulstones"},
        {id:"bags", label:"Bags"}, {id:"packages", label:"Packages"},
        {id:"misc", label:"Miscellaneous"}
    ];
    var records:Array<{account:String, category:String, tab:Int}> = [];
    public function new() {}
    public function load(values:Array<Dynamic>):Void {
        records = [];
        if (values == null) return;
        for (value in values) {
            if (value == null) continue;
            var account:Dynamic = Reflect.field(value, "account");
            var category:Dynamic = Reflect.field(value, "category");
            var tab:Dynamic = Reflect.field(value, "tab");
            if (Std.isOfType(account, String) && account != "" && Std.isOfType(category, String)
                && validCategory(category) && Std.isOfType(tab, Int) && tab >= 0 && owner(account, category) < 0)
                records.push({account:account, category:category, tab:tab});
        }
    }
    public function saved():Array<Dynamic> return [for (r in records) {account:r.account, category:r.category, tab:r.tab}];
    public function hasAccount(account:String):Bool {
        for (r in records) if (r.account == account) return true;
        return false;
    }
    public function owner(account:String, category:String):Int {
        for (r in records) if (r.account == account && r.category == category) return r.tab;
        return -1;
    }
    public function set(account:String, category:String, tab:Int, checked:Bool):Bool {
        if (account == null || account == "" || tab < 0 || !validCategory(category)) return false;
        var existing = owner(account, category);
        if (existing >= 0 && existing != tab) return false;
        if ((existing == tab) == checked) return false;
        records = records.filter(r -> r.account != account || r.category != category);
        if (checked) records.push({account:account, category:category, tab:tab});
        return true;
    }
    static function validCategory(id:String):Bool {
        for (category in CATEGORIES) if (category.id == id) return true;
        return false;
    }
    /** Disjoint categories despite Farever's inherited item types. */
    public static function category(isType:String->Bool):String {
        if (isType("Weapon")) return "weapons";
        if (isType("Armor")) return "armor";
        if (isType("GearTool")) return "tools";
        if (isType("Gear")) return "accessories";
        if (isType("Food")) return "food";
        if (isType("AugmentDemon") || isType("AugmentDemonSigil")) return "demon";
        if (isType("Augment")) return "enchants";
        if (isType("CraftingComponent") || isType("UpgradeComponent")) return "components";
        if (isType("Soulstone")) return "soulstones";
        if (isType("Bag")) return "bags";
        if (isType("Package") || isType("CompletedPackage")) return "packages";
        if (isType("Consumable") || isType("Usable")) return "consumables";
        return "misc";
    }
}
