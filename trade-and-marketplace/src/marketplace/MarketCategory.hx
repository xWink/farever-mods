package marketplace;
import trade.GameAccess as G;
import trade.TradeInventory;

/** Same inherited taxonomy as the marketplace catalog, resolved from local game data. */
class MarketCategory {
    // Keep the server taxonomy value while using the clearer label throughout the UI.
    public static function label(value:String):String return switch(value) {
        case "Collections":"Collectibles";case "Weapon":"Weapons";
        case "Armor":"Armors";case "Accessory":"Accessories";default:value;
    };
    static var categories:Map<String,String>=["CraftingComponent"=>"Components","UpgradeComponent"=>"Components","CraftSlot"=>"Components","AugmentBlacksmith"=>"Components","AugmentJeweller"=>"Components","AugmentOutfitter"=>"Components","Weapon"=>"Weapon","Armor"=>"Armor","GearTool"=>"Miscellaneous","Gear"=>"Accessory","Recipe"=>"Collections","InfusionPattern"=>"Collections","Collection"=>"Collections","LootableContainer"=>"Containers","Bag"=>"Containers","Package"=>"Containers","CompletedPackage"=>"Containers","Consumable"=>"Consumables","AugmentEnchantFeet"=>"Consumables","AugmentEnchantHands"=>"Consumables","AugmentEnchantWeapon"=>"Consumables","AugmentDemon"=>"Consumables","AugmentDemonSigil"=>"Consumables"];
    static var subcategoryByType:Map<String,String>=["CraftingComponent"=>"Crafting materials","UpgradeComponent"=>"Upgrade materials","CraftSlot"=>"Finishing materials","AugmentBlacksmith"=>"Finishing materials","AugmentJeweller"=>"Finishing materials","AugmentOutfitter"=>"Finishing materials","Sword"=>"Sword","Mace"=>"Mace","Axe"=>"Axe","DualSwords"=>"Dual Swords","DualMaces"=>"Dual Maces","DualAxes"=>"Dual Axes","Daggers"=>"Daggers","Fists"=>"Fists","GreatSword"=>"Two-handed Sword","GreatAxe"=>"Two-handed Axe","CaptureNet"=>"Net","GreatMace"=>"Two-handed Mace","Spear"=>"Spear","Crescent"=>"Crescent","Staff"=>"Staff","Bow"=>"Bow","Book"=>"Spellbook","Halos"=>"Halos","Scepter"=>"Scepter","Thrown"=>"Thrown","Shield"=>"Shield","Relic"=>"Relic","Weapon"=>"Other weapons","Head"=>"Head","Shoulders"=>"Shoulders","Chest"=>"Chest","Hands"=>"Hands","Waist"=>"Waist","Legs"=>"Legs","Feet"=>"Feet","Back"=>"Back","Armor"=>"Other armor","GearNeck"=>"Neck","GearFinger"=>"Ring","GearTrinket"=>"Trinket","Gear"=>"Other accessories","GearTool"=>"Tools","Food"=>"Food","Potion"=>"Potions","Elixir"=>"Elixirs","Scroll"=>"Scrolls","AugmentEnchantFeet"=>"Enchantments","AugmentEnchantHands"=>"Enchantments","AugmentEnchantWeapon"=>"Enchantments","AugmentDemon"=>"Demon enchantments","AugmentDemonSigil"=>"Demon enchantments","SkillPointBook"=>"Skill point books","Consumable"=>"Other consumables","Recipe"=>"Recipes","InfusionPattern"=>"Infusion patterns","Mount"=>"Mounts","GearGlider"=>"Gliders","Emote"=>"Emotes","Collection"=>"Other collectibles","LootableContainer"=>"Containers","Bag"=>"Bags","Package"=>"Packages","CompletedPackage"=>"Packages","Currency"=>"Currency","Soulstone"=>"Soulstones"];
    public static function supportsClasses(category:String):Bool return category==""||category=="Weapon"||category=="Armor";

    /** Server listing classes use canonical labels; native item aptitudes
        reference Fighter/Assassin/Wizard/Cleric. Ignore stat aptitudes. */
    public static function classLabels(values:Dynamic):Array<String> {
        var found:Map<String,Bool>=[];
        try {
            for(entry in G.array(values)) {
                var raw:Dynamic=entry;
            if(!Std.isOfType(raw,String)) {
                var ref=G.field(raw,"ref");
                if(ref!=null)raw=ref;
                if(!Std.isOfType(raw,String))raw=G.field(raw,"id");
            }
            var name=switch(G.text(raw)) {
                case "Fighter","Warrior":"Warrior";
                case "Assassin","Rogue":"Rogue";
                case "Wizard","Mage":"Mage";
                case "Cleric","Priest":"Priest";
                default:"";
            };
                if(name!="")found[name]=true;
            }
        } catch(_:Dynamic) {}
        return [for(name in ["Warrior","Rogue","Mage","Priest"]) if(found.exists(name)) name];
    }
    public static function subcategories(category:String):Array<String> return switch(category) {
        case "Weapon":["Sword", "Mace", "Axe", "Dual Swords", "Dual Maces", "Dual Axes", "Daggers", "Fists", "Two-handed Sword", "Two-handed Axe", "Net", "Two-handed Mace", "Spear", "Crescent", "Staff", "Bow", "Spellbook", "Halos", "Scepter", "Thrown", "Shield", "Relic", "Other weapons"];
        case "Armor":["Head", "Shoulders", "Chest", "Hands", "Waist", "Legs", "Feet", "Back", "Other armor"];
        case "Accessory":["Neck", "Ring", "Trinket", "Other accessories"];
        case "Components":["Crafting materials","Upgrade materials","Finishing materials"];
        case "Consumables":["Food","Potions","Elixirs","Scrolls","Enchantments","Demon enchantments","Skill point books","Other consumables"];
        case "Collections":["Recipes","Infusion patterns","Mounts","Gliders","Emotes","Other collectibles"];
        case "Containers":["Containers","Bags","Packages"];
        case "Miscellaneous":["Tools","Soulstones","Other"];default:[];
    };
    public static function item(kind:String):Dynamic {
        var definition=TradeInventory.definition(kind);
        var type=G.text(G.field(definition,"type"));
        var category:Null<String>=null,subcategory:Null<String>=type=="Consumable"&&StringTools.startsWith(kind,"ScrollOf")?"Scrolls":null;
        var seen=new Map<String,Bool>();
        var types=G.field(G.current("Data","itemType"),"byId");
        while(type!=""&&!seen.exists(type)) {
            seen[type]=true;
            if(category==null)category=categories[type];
            if(subcategory==null)subcategory=subcategoryByType[type];
            type=G.text(G.field(G.call("haxe.ds.StringMap","get",types,[type]),"inherit"));
        }
        var resolved=category==null?"Miscellaneous":category;
        var classes=(resolved=="Weapon"||resolved=="Armor")
            ?classLabels(G.field(definition,"aptitudes")):[];
        return {category:resolved,subcategory:subcategory==null?"Other":subcategory,classes:classes};
    }
}
