package marketplace;
import trade.GameAccess as G;
import trade.TradeInventory;

/** Same inherited taxonomy as the marketplace catalog, resolved from local game data. */
class MarketCategory {
    static var categories:Map<String,String>=["CraftingComponent"=>"Components","UpgradeComponent"=>"Components","CraftSlot"=>"Components","AugmentBlacksmith"=>"Components","AugmentJeweller"=>"Components","AugmentOutfitter"=>"Components","Gear"=>"Equipment","Recipe"=>"Collections","InfusionPattern"=>"Collections","Collection"=>"Collections","LootableContainer"=>"Containers","Bag"=>"Containers","Package"=>"Containers","CompletedPackage"=>"Containers","Consumable"=>"Consumables","AugmentEnchantFeet"=>"Consumables","AugmentEnchantHands"=>"Consumables","AugmentEnchantWeapon"=>"Consumables","AugmentDemon"=>"Consumables","AugmentDemonSigil"=>"Consumables"];
    static var subcategories:Map<String,String>=["CraftingComponent"=>"Crafting materials","UpgradeComponent"=>"Upgrade materials","CraftSlot"=>"Finishing materials","AugmentBlacksmith"=>"Finishing materials","AugmentJeweller"=>"Finishing materials","AugmentOutfitter"=>"Finishing materials","Weapon"=>"Weapons","Armor"=>"Armour","GearTool"=>"","Gear"=>"Accessories","Food"=>"Food","Potion"=>"Potions","Elixir"=>"Elixirs","Scroll"=>"Scrolls","AugmentEnchantFeet"=>"Enchantments","AugmentEnchantHands"=>"Enchantments","AugmentEnchantWeapon"=>"Enchantments","AugmentDemon"=>"Demon enchantments","AugmentDemonSigil"=>"Demon enchantments","SkillPointBook"=>"Skill point books","Consumable"=>"Other consumables","Recipe"=>"Recipes","InfusionPattern"=>"Infusion patterns","Mount"=>"Mounts","GearGlider"=>"Gliders","Emote"=>"Emotes","Collection"=>"Other collectibles","LootableContainer"=>"Containers","Bag"=>"Bags","Package"=>"Packages","CompletedPackage"=>"Packages","Currency"=>"Currency","Soulstone"=>"Soulstones"];
    public static function item(kind:String):Dynamic {
        var type=G.text(G.field(TradeInventory.definition(kind),"type"));
        var category:Null<String>=null,subcategory:Null<String>=type=="Consumable"&&StringTools.startsWith(kind,"ScrollOf")?"Scrolls":null;
        var seen=new Map<String,Bool>();
        var types=G.field(G.current("Data","itemType"),"byId");
        while(type!=""&&!seen.exists(type)) {
            seen[type]=true;
            if(category==null)category=categories[type];
            if(subcategory==null)subcategory=subcategories[type];
            type=G.text(G.field(G.call("haxe.ds.StringMap","get",types,[type]),"inherit"));
        }
        return {category:category==null?"Miscellaneous":category,subcategory:subcategory==null?"Other":subcategory};
    }
}
