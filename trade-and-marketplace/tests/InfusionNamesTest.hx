import trade.*;
class InfusionNamesTest {
    static var checks=0;
    static function check(ok:Bool,message:String):Void {checks++;if(!ok)throw message;}
    public static function main():Void {
        GameAccess.skills={byId:{get:function(id:String):Dynamic return switch(id){
            case "Infusion_Manfish_DPS": {texts:{name:"Overwhelming Tides"}};
            case "Infusion_Ref": {texts:{name:"::ref_skill::",refs:{ref:"Infusion_Manfish_DPS"}}};
            case "Infusion_Loop": {texts:{refs:{ref:"Infusion_Loop"}}};
            default:null;
        }}};
        check(TradeInventory.skillName("Infusion_Manfish_DPS")=="Overwhelming Tides","Infusions use native skill display names");
        check(TradeInventory.skillName("Infusion_Ref")=="Overwhelming Tides","Infusion name references resolve");
        check(TradeInventory.skillName("Infusion_Loop")=="Infusion_Loop","Cyclic references are bounded");
        GameAccess.items={byId:{get:function(id:String):Dynamic return {texts:{name:"Infusion: ::ref_skill::"},props:{ref:{skill:"Infusion_Manfish_DPS"}}}}};
        check(TradeInventory.itemName("InfusionPattern_Manfish_DPS")=="Infusion: Overwhelming Tides","Pattern item names resolve their referenced infusion");
        var named:Dynamic={__uid:"x",kind:"Sword",inf:{},infusion:"Infusion_Manfish_DPS",getName:()->"Sword"};
        check(TradeInventory.describe(named,1).detail.indexOf("Infusion: Overwhelming Tides")>=0,"New exports contain infusion display names");
        var definitions:Map<String,Dynamic>=[
            "Critter_Goat_Demon"=>{texts:{name:"[Goat_Demon]"},props:{ref:{unit:"Goat_Demon"}}},
            "Critter_DemonDog_Blue"=>{texts:{name:"[DemonDog_Blue]"},props:{ref:{unit:"DemonDog_Blue"}}},
            "Token"=>{texts:{name:"Collect ::ref_unit::"},props:{ref:{unit:"Goat_Demon"}}},
            "Named"=>{texts:{name:"Custom collectible"},props:{ref:{unit:"Goat_Demon"}}}
        ];
        var units:Map<String,Dynamic>=["Goat_Demon"=>{texts:{name:"Demonic Raminiature"}},"DemonDog_Blue"=>{texts:{name:"Demonic dog"}}];
        GameAccess.items={byId:{get:function(id:String):Dynamic return definitions[id]}};
        GameAccess.units={byId:{get:function(id:String):Dynamic return units[id]}};
        check(TradeInventory.itemName("Critter_Goat_Demon")=="Demonic Raminiature","Collectible item names resolve native unit references");
        check(TradeInventory.itemName("Critter_DemonDog_Blue")=="Demonic dog","Resolution applies to other referenced collectibles");
        check(TradeInventory.itemName("Token")=="Collect Demonic Raminiature","Reference substitution preserves surrounding text");
        check(TradeInventory.itemName("Named")=="Custom collectible","Explicit item names are preserved");
        var pet:Dynamic={__uid:"pet",kind:"Critter_Goat_Demon",inf:{},getName:()->"[Goat_Demon]"};
        check(TradeInventory.describe(pet,1).name=="Demonic Raminiature","Inventory and trade descriptions resolve the same names");
        units["Goat_Demon"].texts.name="Raminiature démoniaque";
        check(TradeInventory.itemName("Critter_Goat_Demon")=="Raminiature démoniaque","Use the current language's unit name");
        units.remove("Goat_Demon");
        check(TradeInventory.itemName("Critter_Goat_Demon")=="[Goat_Demon]","Missing references preserve the source name");
        GameAccess.units=null;GameAccess.items=null;GameAccess.skills=null;
        Sys.println("Infusion name checks passed: "+checks);
    }
}
