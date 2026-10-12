package itemutilities;

private typedef BankAffinityCategory = {
    var id:String;
    var label:String;
    var types:Array<String>;
    // Before the expanded list, these items used this broad affinity.
    var ?legacyParent:String;
}

/** Local preferences, scoped to account because bank tabs are account-wide. */
class BankAffinityState {
    // Specific inherited types must precede their broad fallback: Mount and
    // GearGlider inherit Collection -> Consumable -> Usable, for example.
    public static final CATEGORIES:Array<BankAffinityCategory> = [
        {id:"weapons", label:"Weapons", types:["Weapon"]},
        {id:"armor", label:"Armour", types:["Armor"]},
        {id:"tools", label:"Tools", types:["GearTool"]},
        {id:"accessories", label:"Accessories", types:["Gear"]},
        {id:"food", label:"Food", types:["Food"]},
        {id:"potions", label:"Potions", types:["Potion"], legacyParent:"consumables"},
        {id:"elixirs", label:"Elixirs", types:["Elixir"], legacyParent:"consumables"},
        {id:"scrolls", label:"Scrolls", types:["Scroll"], legacyParent:"consumables"},
        {id:"recipes", label:"Recipes", types:["Recipe"], legacyParent:"consumables"},
        {id:"patterns", label:"Infusion patterns", types:["InfusionPattern"], legacyParent:"consumables"},
        {id:"runes", label:"Runes", types:["Mastery"], legacyParent:"consumables"},
        {id:"skillbooks", label:"Skill point books", types:["SkillPointBook"], legacyParent:"consumables"},
        {id:"containers", label:"Containers", types:["LootableContainer"], legacyParent:"consumables"},
        {id:"mounts", label:"Mounts", types:["Mount"], legacyParent:"consumables"},
        {id:"gliders", label:"Gliders", types:["GearGlider"], legacyParent:"consumables"},
        {id:"emotes", label:"Emotes", types:["Emote"], legacyParent:"consumables"},
        {id:"collections", label:"Other collectibles", types:["Collection"], legacyParent:"consumables"},
        {id:"consumables", label:"Other consumables", types:["Consumable", "Usable"]},
        {id:"demon", label:"Demon enchantments", types:["AugmentDemon", "AugmentDemonSigil"]},
        {id:"enchants", label:"Other enchantments", types:["Augment"]},
        {id:"components", label:"Components", types:["CraftingComponent", "UpgradeComponent"]},
        {id:"finishing", label:"Finishing materials", types:["CraftSlot"], legacyParent:"misc"},
        {id:"soulstones", label:"Soulstones", types:["Soulstone"]},
        {id:"bags", label:"Bags", types:["Bag"]},
        {id:"packages", label:"Packages", types:["Package", "CompletedPackage"]},
        {id:"currency", label:"Currency", types:["Currency"], legacyParent:"misc"},
        {id:"prospecting", label:"Prospecting", types:["Prospecting"], legacyParent:"misc"},
        {id:"lore", label:"Lore books", types:["LoreBook"], legacyParent:"misc"},
        {id:"misc", label:"Miscellaneous", types:[]}
    ];
    var records:Array<{account:String, category:String, tab:Int}> = [];
    public function new() {}
    public function load(values:Array<Dynamic>):Void {
        records = [];
        if (values == null) return;
        var legacy:Array<{account:String, category:String, tab:Int}> = [];
        for (value in values) {
            if (value == null) continue;
            var account:Dynamic = Reflect.field(value, "account");
            var category:Dynamic = Reflect.field(value, "category");
            var tab:Dynamic = Reflect.field(value, "tab");
            if (Std.isOfType(account, String) && account != "" && Std.isOfType(category, String)
                && validCategory(category) && Std.isOfType(tab, Int) && tab >= 0 && owner(account, category) < 0) {
                var record = {account:account, category:category, tab:tab};
                records.push(record);
                if (Reflect.field(value, "version") == null) legacy.push(record);
            }
        }
        // Preserve existing deposit destinations once when splitting the old
        // groups. Explicit assignments win; versioned saves never re-add an
        // affinity that the user later unchecked or moved to another tab.
        for (record in legacy) for (category in CATEGORIES)
            if (category.legacyParent == record.category && owner(record.account, category.id) < 0)
                records.push({account:record.account, category:category.id, tab:record.tab});
    }
    public function saved():Array<Dynamic> return [for (r in records) {account:r.account, category:r.category, tab:r.tab, version:2}];
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
        for (category in CATEGORIES) for (type in category.types)
            if (isType(type)) return category.id;
        return "misc";
    }
}
